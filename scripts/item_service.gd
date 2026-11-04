extends Node2D
signal terrain_changed(cell: Vector2i, block_id: int)
signal decoration_changed(kind: String, cell: Vector2i, value: int)
signal attack_started(id: int, direction: Vector2)
signal inventory_changed(id: int)
signal drop_changed(id: int, data: Dictionary)
const Recipes = preload("res://data/recipes.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Items = preload("res://data/items.gd")
const Drop = preload("res://scripts/drop.gd")
const PICKUP_RADIUS := 27.0
var inventories: Dictionary = {}
var drops: Dictionary = {}
var next_drop_id := 1
var attack_ready_at: Dictionary = {}
var attack_profiles: Dictionary = {}
var main: Node2D

func _ready() -> void:
 main = get_parent()

func inventory_for(id: int) -> RefCounted:
 if not inventories.has(id):
  inventories[id] = Inventory.new()
 return inventories[id]

func local_inventory() -> RefCounted:
 var id := int(str(main.player.name)) if is_instance_valid(main.player) else 1
 return inventory_for(id)

func try_edit(body: CharacterBody2D, cell: Vector2i, block_id: int, bodies: Array, slot: int = -1) -> bool:
 if body.dead:
  return false
 var id := int(str(body.name))
 var inventory = inventory_for(id)
 var previous: int = main.world.block_at(cell)
 if block_id != -1 and (slot < 0 or slot >= Inventory.HOTBAR_COUNT or inventory.block_in_slot(slot) != block_id):
  return false
 if block_id != -1 and (main.world.torches.has(cell) or main.combat.chest_at(cell) != -1):
  return false
 if not main.world.request_edit(body, cell, block_id, bodies):
  return false
 if block_id == -1:
  var item_id: String = main.world.Blocks.DEFINITIONS[previous].drop_item
  spawn_drop(item_id, 1, main.world.cell_center(cell))
 else:
  inventory.take_one(slot)
  inventory_changed.emit(id)
 terrain_changed.emit(cell, block_id)
 _check_torch_support()
 return true

func spawn_drop(item_id: String, amount: int, at: Vector2) -> int:
 var id := next_drop_id
 next_drop_id += 1
 set_drop(id, {"item": item_id, "count": amount, "position": at})
 drop_changed.emit(id, drop_data(id))
 return id

func set_drop(id: int, data: Dictionary) -> void:
 if data.is_empty():
  if drops.has(id):
   remove_child(drops[id])
   drops[id].queue_free()
   drops.erase(id)
  return
 if not drops.has(id):
  var drop = CharacterBody2D.new()
  drop.set_script(Drop)
  drop.item_id = data.item
  drop.count = data.count
  add_child(drop)
  drops[id] = drop
 drops[id].count = data.count
 drops[id].position = data.position
 drops[id].velocity = data.get("velocity", Vector2.ZERO)
 drops[id].age = data.get("age", 0.0)
 next_drop_id = maxi(next_drop_id, id + 1)

func drop_data(id: int) -> Dictionary:
 var drop = drops[id]
 return {"item": drop.item_id, "count": drop.count, "position": drop.position, "velocity": drop.velocity, "age": drop.age}

func snapshot() -> Dictionary:
 var result: Dictionary = {}
 for id in drops:
  result[id] = drop_data(id)
 return result

func load_drops(data: Dictionary) -> void:
 for id in drops.keys():
  set_drop(id, {})
 for id in data:
  set_drop(id, data[id])

func transfer(id: int, source: int, destination: int) -> bool:
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead:
  return false
 var inventory = inventory_for(id)
 if not inventory.transfer(source, destination):
  return false
 inventory_changed.emit(id)
 return true

func retire_player(id: int, at: Vector2) -> void:
 if not inventories.has(id):
  return
 for slot in inventories[id].slots:
  if slot.count > 0:
   spawn_drop(slot.item, slot.count, at)
 inventories.erase(id)

func _physics_process(delta: float) -> void:
 if not is_instance_valid(main.network) or main.network.stopping:
  return
 if main.network.active and (not main.network.connected or not multiplayer.is_server()):
  return
 for id in drops.keys():
  var drop = drops[id]
  drop.age += delta
  drop.velocity.y = minf(drop.velocity.y + 500.0 * delta, 350.0)
  drop.move_and_slide()
  # Finite world: retain items rather than letting them fall beyond the border.
  drop.position.x = clampf(drop.position.x, 4.0, main.world.world_width * 16.0 - 4.0)
  if drop.position.y > main.world.world_depth * 16 + 32:
   drop.position = main.world.spawn_position()
   drop.velocity = Vector2.ZERO
  if drop.age < 0.2:
   continue
  var candidates: Array = main.get_node("Players").get_children()
  candidates.sort_custom(func(a, b): return a.position.distance_squared_to(drop.position) < b.position.distance_squared_to(drop.position))
  for body in candidates:
   if body.dead:
    continue
   if (body.position + Vector2(0, -4)).distance_to(drop.position) > PICKUP_RADIUS:
    continue
   var player_id := int(str(body.name))
   var inventory = inventory_for(player_id)
   var remainder: int = inventory.add(drop.item_id, drop.count)
   if remainder == drop.count:
    continue
   inventory_changed.emit(player_id)
   if remainder == 0:
    set_drop(id, {})
    drop_changed.emit(id, {})
    break
   drop.count = remainder
   drop_changed.emit(id, drop_data(id))


func selected_definition(body: CharacterBody2D, slot: int) -> Dictionary:
 var item_id: String = inventory_for(int(str(body.name))).item_at(slot)
 return Items.DEFINITIONS.get(item_id, {})

func primary_status(body: CharacterBody2D, cell: Vector2i, slot: int) -> String:
 var kind: String = selected_definition(body, slot).get("kind", "")
 if body.dead:
  return "Вы погибли"
 if kind == "weapon":
  return "Недостаточно выносливости" if body.resources.stamina < float(selected_definition(body, slot).stamina_cost) else "ЛКМ — удар клинком"
 if main.combat.chest_at(cell) != -1:
  if not main.world.in_reach(body, cell):
   return "Сундук слишком далеко"
  var chest_id: int = main.combat.chest_at(cell)
  return "Можно разбить сундук" if main.combat.line_clear(body.position + Vector2(0, -5), main.combat.chests[chest_id].position) else "Сундук за преградой"
 if kind == "" and main.combat.enemy_at(cell) != -1:
  if body.resources.stamina < main.combat.Rules.PUNCH_STAMINA_COST: return "Недостаточно выносливости"
  var enemy = main.combat.entities[main.combat.enemy_at(cell)]
  return "Можно ударить кулаком" if body.position.distance_to(enemy.position) <= 29 else "Враг слишком далеко"
 if kind == "wall":
  return main.world.decoration_status(body, cell, "wall", false)
 if main.world.torches.has(cell):
  return main.world.decoration_status(body, cell, "torch", false)
 return main.world.interaction_status(body, cell, false, main.get_node("Players").get_children())

func primary_duration(body: CharacterBody2D, cell: Vector2i, slot: int) -> float:
 var definition := selected_definition(body, slot)
 if main.combat.chest_at(cell) != -1:
  return 0.6
 if definition.is_empty() and main.combat.enemy_at(cell) != -1:
  return 0.01
 if definition.get("kind", "") == "wall":
  return 0.25
 if main.world.torches.has(cell) and definition.get("kind", "") != "wall":
  return 0.15
 var block_id: int = main.world.block_at(cell)
 if block_id == -1:
  return 1.0
 return float(main.world.Blocks.DEFINITIONS[block_id].mine_time) * float(definition.get("mine_factor", 1.0))

func placement_status(body: CharacterBody2D, cell: Vector2i, slot: int) -> String:
 var definition := selected_definition(body, slot)
 var kind: String = definition.get("kind", "")
 if kind in ["wall", "torch"]:
  return main.world.decoration_status(body, cell, kind, true)
 if body.dead:
  return "Вы погибли"
 if kind == "solid":
  if main.combat.chest_at(cell) != -1:
   return "Здесь сундук вещей"
  if main.world.torches.has(cell):
   return "Сначала сними факел"
  return main.world.interaction_status(body, cell, true, main.get_node("Players").get_children())
 return "Этот слот не для строительства"

func use_primary(body: CharacterBody2D, cell: Vector2i, slot: int) -> bool:
 if body.dead:
  return false
 var definition := selected_definition(body, slot)
 var kind: String = definition.get("kind", "")
 if kind == "weapon":
  return swing(body, slot, main.world.cell_center(cell) - body.position)
 if main.combat.chest_at(cell) != -1:
  return main.combat.break_chest(body, cell)
 if kind == "" and main.combat.enemy_at(cell) != -1:
  return punch(body, main.world.cell_center(cell) - body.position)
 if kind != "wall" and main.world.torches.has(cell):
  kind = "torch"
 if kind == "wall" or (kind == "torch" and main.world.torches.has(cell)):
  var expected := "Можно снять стену" if kind == "wall" else "Можно снять факел"
  if primary_status(body, cell, slot) != expected:
   return false
  var item_id := "torch"
  if kind == "wall":
   item_id = "dirt_wall" if main.world.wall_at(cell) == 1 else "stone_wall"
  main.world.apply_decoration(kind, cell, -1)
  decoration_changed.emit(kind, cell, -1)
  spawn_drop(item_id, 1, main.world.cell_center(cell))
  _check_torch_support()
  return true
 return try_edit(body, cell, -1, main.get_node("Players").get_children())

func place_selected(body: CharacterBody2D, cell: Vector2i, slot: int) -> bool:
 if body.dead or slot < 0 or slot >= Inventory.HOTBAR_COUNT:
  return false
 var definition := selected_definition(body, slot)
 var kind: String = definition.get("kind", "")
 if kind == "solid":
  return try_edit(body, cell, definition.block, main.get_node("Players").get_children(), slot)
 if kind not in ["wall", "torch"]:
  return false
 var expected := "Можно поставить стену" if kind == "wall" else "Можно поставить факел"
 if placement_status(body, cell, slot) != expected:
  return false
 var value: int = int(definition.wall) if kind == "wall" else 1
 main.world.apply_decoration(kind, cell, value)
 decoration_changed.emit(kind, cell, value)
 var id := int(str(body.name))
 inventory_for(id).take_one(slot)
 inventory_changed.emit(id)
 return true

func _check_torch_support() -> void:
 for cell in main.world.torches.keys():
  if not main.world.has_support(cell):
   main.world.apply_decoration("torch", cell, -1)
   decoration_changed.emit("torch", cell, -1)
   spawn_drop("torch", 1, main.world.cell_center(cell))

func craft(id: int, recipe_id: String) -> String:
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead:
  return "Нельзя создавать предметы после смерти"
 var inventory = inventory_for(id)
 var status: String = inventory.craft_preview(recipe_id).status
 if status != "Можно создать":
  return status
 if not inventory.craft(recipe_id):
  return "Создать не удалось"
 inventory_changed.emit(id)
 var recipe: Dictionary = Recipes.DEFINITIONS[recipe_id]
 return "Создано: %s ×%d" % [Items.DEFINITIONS[recipe.output].name, recipe.count]

func swing(body: CharacterBody2D, slot: int, direction: Vector2) -> bool:
 var definition := selected_definition(body, slot)
 if not main.combat.authoritative() or body.dead or definition.get("kind", "") != "weapon":
  return false
 var id := int(str(body.name))
 var now := Time.get_ticks_msec()
 if now < int(attack_ready_at.get(id, 0)):
  return false
 if not body.resources.spend_stamina(float(definition.stamina_cost)):
  return false
 main.combat.player_changed.emit(id, main.combat.player_data(body))
 attack_ready_at[id] = now + roundi(float(definition.swing_time) * 1000.0)
 var aim := direction.normalized() if direction.length_squared() > 0.1 else Vector2(body.facing, 0)
 attack_profiles[id] = {"damage": definition.damage, "poise": definition.poise_damage, "reach": definition.reach, "unarmed": false}
 body.play_swing(aim)
 attack_started.emit(id, aim)
 return true


func punch(body: CharacterBody2D, direction: Vector2) -> bool:
 if not main.combat.authoritative() or body.dead:
  return false
 var id := int(str(body.name))
 var now := Time.get_ticks_msec()
 if now < int(attack_ready_at.get(id, 0)):
  return false
 if not body.resources.spend_stamina(main.combat.Rules.PUNCH_STAMINA_COST):
  return false
 main.combat.player_changed.emit(id, main.combat.player_data(body))
 attack_ready_at[id] = now + 550
 attack_profiles[id] = {"damage": main.combat.Rules.PUNCH_DAMAGE, "poise": main.combat.Rules.PUNCH_POISE_DAMAGE, "reach": 22.0, "unarmed": true}
 var aim := direction.normalized() if direction.length_squared() > 0.1 else Vector2(body.facing, 0)
 body.play_swing(aim, true)
 attack_started.emit(id, aim)
 return true
