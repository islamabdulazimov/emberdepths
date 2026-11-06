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
 var before: Array = inventory.to_data()
 check_result(not inventory.craft("stone_pick") and inventory.to_data() == before, "Missing ingredients leave inventory unchanged")
 check_result(not inventory.craft("invented_recipe"), "Unknown recipe rejected")
 inventory.add("stone", 4)
 inventory.add("dirt", 2)
 check_result(inventory.craft("stone_pick") and inventory.count_item("stone_pick") == 1 and inventory.count_item("stone") == 0 and inventory.count_item("dirt") == 0, "Recipe consumes exact ingredients and produces tool")
 inventory.add("stone_pick", 1)
 check_result(inventory.slots[0].count == 1 and inventory.slots[1].count == 1, "Tools occupy separate nonstackable slots")
 for slot in inventory.slots:
  slot.item = "stone"
  slot.count = 99
 inventory.slots[0] = {"item": "dirt", "count": 99}
 before = inventory.to_data()
 check_result(not inventory.craft("stone_pick") and inventory.to_data() == before, "No space rolls back all crafting ingredients")
 inventory.slots[0].count = 2
 check_result(inventory.craft("stone_pick") and inventory.slots[0].item == "stone_pick", "Recipe may use slot freed by ingredient consumption")
 for slot in inventory.slots:
  slot.item = "dirt"
  slot.count = 99
 inventory.slots[0] = {"item": "torch", "count": 98}
 inventory.slots[1] = {"item": "emberstone", "count": 2}
 inventory.slots[2] = {"item": "stone", "count": 99}
 before = inventory.to_data()
 check_result(not inventory.craft("torch") and inventory.to_data() == before, "Multi-item output cannot partially craft into full bag")
 inventory.slots[1].count = 1
 check_result(inventory.craft("torch") and inventory.count_item("torch") == 101 and inventory.count_item("emberstone") == 0, "Batch output fills stack and freed slot atomically")
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 for i in range(90):
  await physics_frame
 var player = main.player
 player.set_physics_process(false)
 var service = main.items
 var world = main.world
 var bag = service.local_inventory()
 check_result(world.block_at(Vector2i(99, 25)) == 3 and world.solid.get_cell_source_id(Vector2i(99, 25)) == 1, "Fuel deposit exists near spawn with distinct tile source")
 bag.add("stone_pick", 1)
 var ground := Vector2i(97, 22)
 check_result(is_equal_approx(service.primary_duration(player, ground, 0) * 2.0, service.primary_duration(player, ground, 9)), "Selected pickaxe doubles mining speed")
 bag.add("stone_blade", 1)
 var previous: int = world.block_at(ground)
 check_result(service.use_primary(player, ground, 1) and player.swing_remaining > 0.0 and world.block_at(ground) == previous, "Weapon swings without mining targeted terrain")
 check_result(not service.use_primary(player, ground, 1), "Weapon cooldown rejects immediate repeated swing")
 main.combat.tick_fighter(player,0.5)
 bag.add("dirt_wall", 2)
 var cell := Vector2i(97, 21)
 check_result(service.place_selected(player, cell, 2) and world.wall_at(cell) == 1 and not world.walls.collision_enabled and world.block_at(cell) == -1, "Wall occupies separate noncolliding layer")
 check_result(not service.place_selected(player, cell, 2) and bag.slots[2].count == 1, "Duplicate wall does not consume item")
 check_result(not service.place_selected(player, Vector2i(0, 20), 2) and bag.slots[2].count == 1, "Distant wall placement rejected without cost")
 bag.add("torch", 2)
 check_result(service.place_selected(player, cell, 3) and world.torches.has(cell) and bag.slots[3].count == 1, "Torch placement consumes one and preserves wall")
 check_result(world.torches[cell].light.enabled and world.torches[cell].light.texture != null, "Torch creates enabled textured PointLight2D")
 check_result(not service.place_selected(player, cell, 3) and bag.slots[3].count == 1, "Duplicate torch costs no resources")
 bag.add("dirt", 2)
 check_result(not service.place_selected(player, cell, 4) and bag.slots[4].count == 2, "Solid cannot bury existing torch")
 check_result(service.try_edit(player, ground, -1, [player]) and world.torches.has(cell), "Background wall keeps torch supported after ground mining")
 check_result(service.use_primary(player, cell, 2) and world.wall_at(cell) == -1 and not world.torches.has(cell), "Removing final support detaches torch")
 var recovered_torches := 0
 for id in service.drops:
  if service.drops[id].item_id == "torch":
   recovered_torches += service.drops[id].count
 check_result(recovered_torches == 1, "Detached torch drops exactly once")
 var second_cell := Vector2i(98, 21)
 check_result(service.place_selected(player, second_cell, 3) and bag.item_at(3) == "", "Last torch can be placed from slot")
 check_result(service.use_primary(player, second_cell, 3) and not world.torches.has(second_cell), "Empty selected slot can recover last placed torch")
 var second = load("res://scripts/world.gd").new()
 root.add_child(second)
 for edited in world.wall_changes:
  second.apply_decoration("wall", edited, world.wall_changes[edited])
 check_result(second.wall_at(cell) == -1, "Background changes replay from journal")
 second.queue_free()
 main.inventory_ui.toggle()
 check_result(main.inventory_ui.crafting.visible and main.inventory_ui.recipe_buttons.size() == 17, "Inventory exposes existing recipes plus wooden gear and roll ability")
 # Surface/depth contrast is local to camera, not a day/night system.
 player.position.y = (world.heights[96] + 20) * 16
 main._process(0.0)
 check_result(main.ambient.color.r < 0.2, "Deep underground receives dark ambient lighting")
 print("Crafting failures: ", failures)
 quit(1 if failures else 0)
