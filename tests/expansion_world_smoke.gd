extends SceneTree
const Schema = preload("res://scripts/save_schema.gd")
var failures := 0
var main: Node2D
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func fingerprint() -> int:
 var cells: Array = []
 for cell in main.world.solid.get_used_cells(): cells.append([cell,main.world.block_at(cell)])
 return hash(cells)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.combat.set_physics_process(false)
 main.interaction.set_process(false)
 main.items.set_physics_process(false)
 main.exploration.set_process(false)
 main.player.set_physics_process(false)
 main.encounter.enabled = false
 var legacy: Dictionary = main.saves.capture()
 check_result(legacy.generator == 1 and legacy.world.width == 192,"Legacy fixture keeps its original generator and dimensions")
 for seed_value in [72419,12,90551]:
  main.world.configure_expanded()
  main.world.world_seed = seed_value
  var start := Time.get_ticks_msec()
  main.world.generate()
  main.world.solid.update_internals()
  print("GENERATION_MS ",seed_value," ",Time.get_ticks_msec()-start)
  var original := fingerprint()
  main.world.generate()
  check_result(original == fingerprint(),"Seed %d reproduces tiles and all templates" % seed_value)
  check_result(main.world.world_width == 384 and main.world.world_depth == 160 and main.world.sites.size() == 4,"Seed %d contains expanded world, two dungeons and two settlements" % seed_value)
  var overlap := false
  for i in range(main.world.sites.size()):
   for j in range(i+1,main.world.sites.size()): overlap = overlap or main.world.sites[i].rect.grow(2).intersects(main.world.sites[j].rect)
   overlap = overlap or main.world.sites[i].rect.grow(2).has_point(main.world.cell_at(main.world.spawn_position()))
  check_result(not overlap,"Seed %d separates structures and safe spawn" % seed_value)
  check_result(main.world.character_fits(main.world.spawn_position()) and main.world.region_at(Vector2i(192,22)) == "surface" and main.world.region_at(Vector2i(192,60)) == "roots" and main.world.region_at(Vector2i(192,120)) == "deep","Three regions and clear safe arrival for seed %d" % seed_value)
  var start_x := 88+posmod(seed_value,3)
  var start_y: int = main.world.heights[start_x]
  var traversable := true
  for i in range((123-start_y)*2+1):
   var x := start_x+i
   var floor_y := start_y+i/2
   # At the archive junction the corridor meets one riser above the descent.
   # Require a supported standing point within one 16px step, not an exact y.
   var passable := false
   for dy in [-3,-2,-1,0,1,2,3]:
    if main.world.block_at(Vector2i(x,floor_y+dy)) >= 0 and main.world.character_fits(Vector2(x*16+8,(floor_y+dy)*16-10)): passable = true
   traversable = traversable and passable
  check_result(traversable,"Seed %d keeps full-height clearance along the descent and jumpable junctions" % seed_value)
  var entrances := true
  var guards_fit := true
  for site in main.world.sites:
   if site.kind != "settlement":
    var floor_y: int = site.rect.end.y-2
    var route_x := start_x+(floor_y-start_y)*2
    var portal: int = site.rect.end.x+18 if site.kind == "root_shelter" else site.rect.position.x+1
    for x in range(mini(route_x,portal),maxi(route_x,portal)+1):
     entrances = entrances and main.world.character_fits(Vector2(x*16+8,floor_y*16-10))
   for guard in site.guards:
    var c: Vector2i = guard[1]
    guards_fit = guards_fit and main.exploration.fits(guard[0],Vector2(c.x*16+8,(c.y+1)*16))
  check_result(entrances and guards_fit,"Seed %d has open entrances and unblocked guard positions" % seed_value)
  main.exploration.initialize_loot()
  check_result(main.storage.chests.size() == 10,"Seed %d creates ten supported shared containers" % seed_value)
  check_result(Schema.validate(main.saves.capture()) == "","Expanded save validates for seed %d" % seed_value)
 var malformed: Dictionary = main.saves.capture().duplicate(true)
 malformed.world.width = 32
 check_result(Schema.validate(malformed) != "","Generator2 rejects mismatched dimensions before regenerating prepared sites")
 var chest_cell: Vector2i = main.storage.chests.keys()[0]
 var before: Array = main.storage.chests[chest_cell].inventory.to_data()
 main.exploration.initialize_loot()
 check_result(main.storage.chests[chest_cell].inventory.to_data() == before,"Revisiting cannot roll or duplicate contents")
 main.storage.chests[chest_cell].inventory.load_data([])
 main.storage.chests[chest_cell].known_empty = true
 main.storage.chests[chest_cell].opened = true
 var removed_cell: Vector2i = main.storage.chests.keys()[1]
 main.storage.apply_object(removed_cell,{})
 var mined := Vector2i(180,80)
 main.world.apply_edit(mined,-1)
 var placed := Vector2i(180,79)
 main.world.apply_edit(placed,4)
 var saved: Dictionary = main.saves.capture()
 check_result(main.saves.restore(saved) == "","Expanded world restores without touching the user's save file")
 main.exploration.initialize_loot()
 check_result(main.storage.chests[chest_cell].inventory.count_item("wood") == 0 and main.storage.chests[chest_cell].opened and not main.storage.chests.has(removed_cell),"Empty opened chest and destroyed chest survive load without refilling")
 check_result(main.world.block_at(mined) == -1 and main.world.block_at(placed) == 4,"Mined and built tiles survive expanded-world regeneration")
 main.combat.spawn_entity("seamling",Vector2(1800,500))
 var mob = main.combat.entities.values()[0]
 mob.site_guard = true
 var live_save: Dictionary = main.saves.capture()
 check_result(Schema.validate(live_save) == "" and not live_save.combat.entities.values()[0].has("attack_target"),"New guard saves scaling and identity but excludes transient aim")
 check_result(main.saves.restore(legacy) == "" and main.world.generator_version == 1 and main.world.world_width == 192 and main.world.sites.is_empty(),"Legacy save restores original terrain and has no injected structures")
 main.queue_free()
 await process_frame
 print("Expansion world failures: ",failures)
 quit(1 if failures else 0)
