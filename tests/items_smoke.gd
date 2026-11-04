extends SceneTree
const Inventory = preload("res://scripts/inventory.gd")
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok:
  print("PASS: ", message)
 else:
  failures += 1
  push_error(message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var inventory = Inventory.new()
 check_result(inventory.add("dirt", 104) == 0 and inventory.slots[0].count == 99 and inventory.slots[1].count == 5, "Stacks overflow into next slot")
 check_result(inventory.transfer(0, 1) and inventory.slots[1].count == 99 and inventory.slots[0].count == 5, "Merge respects stack cap and retains remainder")
 inventory.add("stone", 2)
 check_result(inventory.transfer(0, 2) and inventory.slots[0].item == "stone" and inventory.slots[2].item == "dirt", "Different stacks swap without loss")
 check_result(not inventory.transfer(-1, 0) and not inventory.transfer(0, 30), "Invalid transfers rejected")
 var restored = Inventory.new()
 restored.load_data(inventory.to_data())
 check_result(restored.to_data() == inventory.to_data(), "Inventory snapshot round trip")
 for slot in inventory.slots:
  slot.item = "dirt"
  slot.count = 99
 check_result(inventory.add("stone", 4) == 4, "Full inventory returns unaccepted count")
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 var player = main.player
 var service = main.items
 var world = main.world
 var bag = service.local_inventory()
 var bodies: Array = [player]
 for i in range(90):
  await physics_frame
 check_result(not service.try_edit(player, Vector2i(97, 21), 1, bodies, 0), "Empty inventory cannot build")
 check_result(service.try_edit(player, Vector2i(96, 22), -1, bodies), "Mining creates physical dropped item")
 check_result(service.drops.size() == 1, "One block produces exactly one drop")
 for i in range(90):
  await physics_frame
 check_result(service.drops.is_empty() and bag.slots[0].item == "turf" and bag.slots[0].count == 1, "Fallen player picks up mined turf once")
 check_result(service.try_edit(player, Vector2i(97, 21), 0, bodies, 0) and bag.slots[0].count == 0, "Successful placement consumes exactly one item")
 check_result(not service.try_edit(player, Vector2i(98, 21), 0, bodies, 0), "Depleted slot cannot build again")
 bag.add("dirt", 2)
 check_result(not service.try_edit(player, Vector2i(96, 22), 1, bodies, 0) and bag.slots[0].count == 2, "Rejected placement never consumes inventory")
 for slot in bag.slots:
  slot.item = "dirt"
  slot.count = 99
 var drop_id: int = service.spawn_drop("stone", 4, player.position + Vector2(0, -8))
 for i in range(25):
  await physics_frame
 check_result(service.drops.has(drop_id) and service.drops[drop_id].count == 4, "Full bag leaves drop in world")
 bag.slots[0] = {"item": "stone", "count": 98}
 for i in range(5):
  await physics_frame
 check_result(bag.slots[0].count == 99 and service.drops[drop_id].count == 3, "Partial pickup retains exact world remainder")
 bag.slots[1] = {"item": "", "count": 0}
 for i in range(5):
  await physics_frame
 check_result(not service.drops.has(drop_id) and bag.slots[1].item == "stone" and bag.slots[1].count == 3, "Freeing slot collects remaining drop")
 main.inventory_ui.toggle()
 check_result(main.inventory_ui.opened and not main.interaction.can_use_mouse(), "Open inventory blocks world mouse actions")
 main.inventory_ui._click_slot(1)
 main.inventory_ui._click_slot(10)
 check_result(bag.slots[10].item == "stone" and bag.slots[10].count == 3, "Inventory UI transfers stack between selected slots")
 main.inventory_ui.toggle()
 var key := InputEventKey.new()
 key.pressed = true
 key.physical_keycode = KEY_0
 main.interaction._unhandled_key_input(key)
 var wheel := InputEventMouseButton.new()
 wheel.pressed = true
 wheel.button_index = MOUSE_BUTTON_WHEEL_UP
 main.interaction._unhandled_input(wheel)
 check_result(main.interaction.selected_slot == 8, "Key zero selects tenth slot and wheel changes selection")
 print("Item failures: ", failures)
 quit(1 if failures else 0)
