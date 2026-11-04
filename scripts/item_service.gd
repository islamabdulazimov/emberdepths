extends Node2D
signal terrain_changed(cell: Vector2i, block_id: int)
signal decoration_changed(kind: String, cell: Vector2i, value: int)
signal door_changed(anchor: Vector2i, value: int)
signal attack_started(id: int, direction: Vector2)
signal chop_started(id: int, direction: Vector2)
signal tree_felled(index: int, direction: int)
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
var tool_ready_at: Dictionary = {}
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
 _check_door_support()
 main.storage.check_support()
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
 if kind == "consumable":
  if body.health >= body.resources.max_health: return "Здоровье полное"
  if body.medicine_cooldown > 0: return "Бальзам: ожидание %.1f с" % body.medicine_cooldown
  if body.swing_remaining > 0: return "Дождись завершения удара"
  return "Можно применить бальзам · удерживай ЛКМ"
 if kind == "axe":
  if main.world.tree_at(cell) == -1: return "Наведи топор на ствол дерева"
  if not main.world.in_reach(body,cell): return "Дерево слишком далеко"
  if main.world.block_at(cell) != -1 or not main.combat.line_clear(body.position + Vector2(0,-5),main.world.cell_center(cell)):
   return "Ствол за преградой"
  return "Можно рубить дерево"
 if kind != "wall" and main.world.door_at(cell) != null:
  var door = main.world.door_at(cell)
  var excluded: Array[RID] = [door.get_rid()]
  if not main.world.in_reach(body,cell): return "Дверь слишком далеко"
  if not main.combat.line_clear(body.position+Vector2(0,-5),main.world.cell_center(cell),excluded): return "Дверь за преградой"
  return "Можно снять дверь"
 if main.combat.chest_at(cell) != -1:
  if not main.world.in_reach(body, cell):
   return "Сундук слишком далеко"
  var chest_id: int = main.combat.chest_at(cell)
  return "Можно разбить сундук" if main.combat.line_clear(body.position + Vector2(0, -5), main.combat.chests[chest_id].position) else "Сундук за преградой"
 if kind != "wall" and main.storage.at_cell(cell) != null: return main.storage.removal_status(body,cell)
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
 if definition.get("kind", "") == "axe": return float(definition.chop_time)
 if definition.get("kind", "") == "consumable": return float(definition.use_time)
 if main.world.door_at(cell) != null and definition.get("kind","") != "wall":
  return main.world.Structures.DOOR_REMOVE_TIME * float(definition.get("mine_factor",1.0))
 if main.combat.chest_at(cell) != -1:
  return 0.6
 if main.storage.at_cell(cell) != null and definition.get("kind","") != "wall":
  return main.world.Structures.CHEST_REMOVE_TIME * float(definition.get("mine_factor",1.0))
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
 if kind == "storage": return main.storage.placement_status(body,cell)
 if kind == "door":
  if body.dead: return "Вы погибли"
  var status: String = main.world.door_placement_status(body,cell,solid_bodies())
  if status != "Можно поставить дверь": return status
  for occupied in main.world.Structures.door_cells(cell):
   if main.combat.chest_at(occupied) != -1: return "В проёме сундук вещей"
  if not main.combat.line_clear(body.position+Vector2(0,-5),main.world.cell_center(cell)): return "Дверь за преградой"
  return status
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
 if kind == "consumable": return finish_medicine(body,slot)
 if kind == "axe": return chop_tree(body, cell, slot)
 if kind != "wall" and main.world.door_at(cell) != null:
  return remove_door(body,cell,slot)
 if main.combat.chest_at(cell) != -1:
  return main.combat.break_chest(body, cell)
 if kind != "wall" and main.storage.at_cell(cell) != null: return main.storage.remove_empty(body,cell)
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
   item_id = main.world.Blocks.WALLS[main.world.wall_at(cell)].item
  main.world.apply_decoration(kind, cell, -1)
  decoration_changed.emit(kind, cell, -1)
  spawn_drop(item_id, 1, main.world.cell_center(cell))
  _check_torch_support()
  return true
 return try_edit(body, cell, -1, main.get_node("Players").get_children())

func cancel_medicine(body: CharacterBody2D, interrupted: bool = false, notify: bool = true) -> void:
 if not main.combat.authoritative(): return
 var was_active: bool = body.medicine_slot != -1 or body.medicine_progress > 0
 if interrupted and was_active:
  body.medicine_cooldown = maxf(body.medicine_cooldown, float(selected_definition(body,body.medicine_slot).get("interrupt_delay",0.6)))
 body.medicine_progress = 0
 body.medicine_slot = -1
 if was_active and notify: main.combat.player_changed.emit(int(str(body.name)),main.combat.player_data(body))

# Both solo input and host commands use this path. Clients never supply delta.
func medicine_step(body: CharacterBody2D, slot: int, delta: float) -> bool:
 if not main.combat.authoritative(): return false
 if slot < 0 or slot >= Inventory.HOTBAR_COUNT or selected_definition(body,slot).get("kind","") != "consumable" or not primary_status(body,Vector2i.ZERO,slot).begins_with("Можно применить"):
  cancel_medicine(body)
  return false
 var fresh: bool = body.medicine_slot != slot
 if fresh:
  cancel_medicine(body,false,false)
  body.medicine_slot = slot
 body.medicine_latch = slot
 body.medicine_progress = minf(1,body.medicine_progress + maxf(delta,0) / float(selected_definition(body,slot).use_time))
 if body.medicine_progress >= 1.0 - 0.000001: return finish_medicine(body,slot)
 if fresh or body.resource_sync <= 0:
  body.resource_sync = 0.1
  main.combat.player_changed.emit(int(str(body.name)),main.combat.player_data(body))
 return false

func finish_medicine(body: CharacterBody2D, slot: int) -> bool:
 if not main.combat.authoritative() or slot < 0 or slot >= Inventory.HOTBAR_COUNT or body.medicine_slot != slot or body.medicine_progress < 1.0 - 0.000001: return false
 var definition := selected_definition(body,slot)
 if definition.get("kind","") != "consumable" or not primary_status(body,Vector2i.ZERO,slot).begins_with("Можно применить"):
  cancel_medicine(body)
  return false
 var id := int(str(body.name))
 if not inventory_for(id).take_one(slot):
  cancel_medicine(body)
  return false
 cancel_medicine(body,false,false)
 body.medicine_cooldown = float(definition.cooldown)
 main.combat.heal_player(id,int(definition.heal))
 inventory_changed.emit(id)
 return true

func animate_chop(body: CharacterBody2D, cell: Vector2i, slot: int) -> void:
 if not main.combat.authoritative() or primary_status(body,cell,slot) != "Можно рубить дерево": return
 var id := int(str(body.name))
 var now := Time.get_ticks_msec()
 if now < int(tool_ready_at.get(id,0)): return
 tool_ready_at[id] = now + 420
 var direction: Vector2 = (main.world.cell_center(cell) - body.position).normalized()
 body.play_tool_swing(direction)
 chop_started.emit(id,direction)

func chop_tree(body: CharacterBody2D, cell: Vector2i, slot: int) -> bool:
 if not main.combat.authoritative() or primary_status(body,cell,slot) != "Можно рубить дерево": return false
 var index: int = main.world.tree_at(cell)
 var tree: Dictionary = main.world.trees[index]
 var at := Vector2(tree.cell.x * 16 + 8,tree.cell.y * 16 - 10)
 var direction := 1 if body.position.x < at.x else -1
 if not main.world.fell_tree(index,direction): return false
 tree_felled.emit(index,direction)
 spawn_drop("wood",int(tree.height),at)
 return true

func place_selected(body: CharacterBody2D, cell: Vector2i, slot: int) -> bool:
 if body.dead or slot < 0 or slot >= Inventory.HOTBAR_COUNT:
  return false
 var definition := selected_definition(body, slot)
 var kind: String = definition.get("kind", "")
 if kind == "storage": return main.storage.place(body,cell,slot)
 if kind == "door":
  if not main.combat.authoritative() or placement_status(body,cell,slot) != "Можно поставить дверь": return false
  main.world.apply_door(cell,0)
  inventory_for(int(str(body.name))).take_one(slot)
  inventory_changed.emit(int(str(body.name)))
  door_changed.emit(cell,0)
  return true
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

func solid_bodies() -> Array:
 var result: Array = main.get_node("Players").get_children()
 for enemy in main.combat.entities.values():
  if enemy.kind != "spirit": result.append(enemy)
 if is_instance_valid(main.encounter.actor): result.append(main.encounter.actor)
 return result

func door_toggle_status(body: CharacterBody2D, cell: Vector2i, slot: int) -> String:
 if body.dead: return "Вы погибли"
 if slot < 0 or slot >= Inventory.HOTBAR_COUNT or not selected_definition(body,slot).is_empty(): return "Выбери пустой слот для двери"
 var door = main.world.door_at(cell)
 if door == null: return "Здесь нет двери"
 var excluded: Array[RID] = [door.get_rid()]
 if not main.world.in_reach(body,cell): return "Дверь слишком далеко"
 if not main.combat.line_clear(body.position+Vector2(0,-5),main.world.cell_center(cell),excluded): return "Дверь за преградой"
 if door.opened:
  if main.world.area_occupied(main.world.door_area(door.anchor),solid_bodies()): return "В проёме персонаж или противник"
  for occupied in main.world.Structures.door_cells(door.anchor):
   if main.combat.chest_at(occupied) != -1: return "В проёме сундук вещей"
 return "Можно закрыть дверь" if door.opened else "Можно открыть дверь"

func toggle_door(body: CharacterBody2D, cell: Vector2i, slot: int) -> bool:
 if not main.combat.authoritative() or not door_toggle_status(body,cell,slot).begins_with("Можно"): return false
 var door = main.world.door_at(cell)
 var now := Time.get_ticks_msec()
 if now < door.ready_at: return false
 door.ready_at = now + roundi(main.world.Structures.DOOR_TOGGLE_DELAY*1000)
 cancel_medicine(body)
 var value := 0 if door.opened else 1
 main.world.apply_door(door.anchor,value)
 door_changed.emit(door.anchor,value)
 return true

func remove_door(body: CharacterBody2D, cell: Vector2i, slot: int) -> bool:
 if not main.combat.authoritative() or primary_status(body,cell,slot) != "Можно снять дверь": return false
 var anchor: Vector2i = main.world.door_at(cell).anchor
 main.world.apply_door(anchor,-1)
 door_changed.emit(anchor,-1)
 spawn_drop("wood_door",1,main.world.cell_center(anchor))
 return true

func _check_door_support() -> void:
 if not main.combat.authoritative(): return
 for anchor in main.world.doors.keys():
  if main.world.block_at(anchor+Vector2i.DOWN) == -1:
   main.world.apply_door(anchor,-1)
   door_changed.emit(anchor,-1)
   spawn_drop("wood_door",1,main.world.cell_center(anchor))

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
