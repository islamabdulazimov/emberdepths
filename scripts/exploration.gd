extends Node
const Regions = preload("res://data/world_regions.gd")
const Sites = preload("res://data/exploration_sites.gd")
const Creatures = preload("res://data/creatures.gd")
var main: Node2D
var clock := 0.0
func _ready() -> void: main = get_parent()
func _process(delta: float) -> void:
 clock += delta
 if clock < 0.5: return
 clock = fmod(clock,0.5)
 if not is_instance_valid(main.network) or not main.combat.authoritative() or main.world.generator_version != 2: return
 if main.network.stopping or (main.network.active and not main.network.connected): return
 initialize_loot()
 activate_guards()
func initialize_loot() -> void:
 if not main.combat.authoritative() or main.world.generator_version != 2: return
 for site in main.world.sites:
  if main.world.site_progress.has(site.id): continue
  main.world.site_progress[site.id] = {"initialized":true,"guards":0}
  var lamps: Array = [Vector2i(site.rect.position.x+7,site.rect.end.y-4)]
  if site.kind != "settlement":
   lamps.append(Vector2i(site.rect.end.x-10,site.rect.position.y+site.rect.size.y/2-3))
   lamps.append(Vector2i(site.rect.end.x-10,site.rect.end.y-4))
  for cell in lamps:
   if main.world.block_at(cell) == -1: main.world.apply_decoration("torch",cell,1)
  for i in range(site.chests.size()):
   var anchor: Vector2i = site.chests[i]
   if main.storage.chests.has(anchor): continue
   var supported := true
   for part in main.storage.Rules.chest_cells(anchor):
    if main.world.block_at(part) != -1 or main.world.block_at(part+Vector2i.DOWN) == -1: supported = false
   if not supported: continue
   main.storage.apply_object(anchor,{"empty":true,"opened":false})
   var inventory = main.storage.chests[anchor].inventory
   var rng := RandomNumberGenerator.new()
   rng.seed = main.world.world_seed+int(site.id.hash())+i*977
   var table: Dictionary = Sites.MAIN_LOOT if i == site.chests.size()-1 else Sites.ORDINARY_LOOT
   table = table.duplicate()
   table.merge(Sites.COMMON_LOOT)
   for item in table:
    var limits: Vector2i = table[item]
    inventory.add(item,limits.x if limits.x == limits.y else rng.randi_range(limits.x,limits.y))
   main.storage.refresh(anchor)
func alive_players() -> Array:
 var alive: Array = []
 for player in main.get_node("Players").get_children():
  if not player.dead: alive.append(player)
 return alive
func fits(kind: String, at: Vector2) -> bool:
 var size: Vector2 = Creatures.DEFINITIONS[kind].size if Creatures.DEFINITIONS.has(kind) else Vector2(14,12)
 var area := Rect2(at+Vector2(-size.x/2,-size.y),size)
 var first: Vector2i = main.world.cell_at(area.position)
 var last: Vector2i = main.world.cell_at(area.end-Vector2(0.01,0.01))
 for y in range(first.y,last.y+1):
  for x in range(first.x,last.x+1):
   var cell := Vector2i(x,y)
   if x < 1 or x >= main.world.world_width-1 or y < 0 or y >= main.world.world_depth-1: return false
   if main.world.block_at(cell) != -1: return false
   var door = main.world.door_at(cell)
   if door != null and not door.opened: return false
   if main.storage.at_cell(cell) != null: return false
 if main.world.block_at(main.world.cell_at(at+Vector2(0,1))) == -1: return false
 return not main.world.area_occupied(area,main.combat.entities.values())
func spawn_safe(kind: String, at: Vector2, players: Array, minimum: float = 112.0) -> bool:
 if Regions.safe(main.world,at) or main.combat_zone.blocks_edit(main.world.cell_at(at)) or not fits(kind,at): return false
 for player in players:
  if player.position.distance_to(at) < minimum: return false
 return true
func activate_guards() -> void:
 if not main.combat.authoritative() or main.world.generator_version != 2: return
 var players := alive_players()
 if players.is_empty(): return
 for site in main.world.sites:
  var progress: Dictionary = main.world.site_progress.get(site.id,{})
  if progress.is_empty(): continue
  for i in range(site.guards.size()):
   if int(progress.guards)&(1<<i): continue
   if main.combat.entities.size() >= Regions.MAX_ENEMIES: return
   var entry: Array = site.guards[i]
   var cell: Vector2i = entry[1]
   var at := Vector2(cell.x*16+8,(cell.y+1)*16)
   var nearby := false
   for player in players:
    if player.position.distance_to(at) < 520: nearby = true
   if not nearby or not spawn_safe(entry[0],at,players): continue
   var id: int = main.combat.spawn_entity(entry[0],at)
   main.combat.entities[id].site_guard = true
   progress.guards = int(progress.guards)|(1<<i)
   main.combat.entity_changed.emit(id,main.combat.entity_data(id))
func try_spawn(players: Array) -> bool:
 if players.is_empty() or not main.combat.authoritative(): return false
 if main.combat.entities.size() >= Regions.MAX_ENEMIES: return false
 var player = players[main.combat.spawn_sequence%players.size()]
 var origin: Vector2i = main.world.cell_at(player.position)
 for attempt in range(36):
  var sign_value := 1 if (attempt+main.combat.spawn_sequence)%2 == 0 else -1
  var x := origin.x+sign_value*(11+posmod(attempt*7+main.world.world_seed,12))
  if x < 2 or x >= main.world.world_width-2: continue
  var desired := origin.y+posmod(attempt*13,17)-8
  if main.world.region_at(origin) == "surface": desired = main.world.heights[x]-1
  for y in range(maxi(2,desired-4),mini(main.world.world_depth-2,desired+9)):
   var cell := Vector2i(x,y)
   if main.world.block_at(cell) != -1 or main.world.block_at(cell+Vector2i.DOWN) < 0: continue
   var region: String = main.world.region_at(cell)
   var kind := "ashweaver" if region == "deep" else ("seamling" if region == "roots" else ("seamling" if main.combat.is_night() else "ashling"))
   if region == "roots" and attempt%3 == 0: kind = "hollowbeak"
   var at := Vector2(x*16+8,(y+1)*16)
   if spawn_safe(kind,at,players,160):
    main.combat.spawn_sequence += 1
    main.combat.spawn_entity(kind,at)
    return true
 return false
