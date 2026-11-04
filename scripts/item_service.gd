extends Node2D
signal inventory_changed(id: int)
signal drop_changed(id: int, data: Dictionary)
const Inventory = preload("res://scripts/inventory.gd")
const Items = preload("res://data/items.gd")
const Drop = preload("res://scripts/drop.gd")
const PICKUP_RADIUS := 27.0
var inventories: Dictionary = {}
var drops: Dictionary = {}
var next_drop_id := 1
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
 var id := int(str(body.name))
 var inventory = inventory_for(id)
 var previous: int = main.world.block_at(cell)
 if block_id != -1 and (slot < 0 or slot >= Inventory.HOTBAR_COUNT or inventory.block_in_slot(slot) != block_id):
  return false
 if not main.world.request_edit(body, cell, block_id, bodies):
  return false
 if block_id == -1:
  var item_id: String = main.world.Blocks.DEFINITIONS[previous].drop_item
  spawn_drop(item_id, 1, main.world.cell_center(cell))
 else:
  inventory.take_one(slot)
  inventory_changed.emit(id)
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
 next_drop_id = maxi(next_drop_id, id + 1)

func drop_data(id: int) -> Dictionary:
 var drop = drops[id]
 return {"item": drop.item_id, "count": drop.count, "position": drop.position}

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
