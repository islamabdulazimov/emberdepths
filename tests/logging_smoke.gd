extends SceneTree
const Items = preload("res://data/items.gd")
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")

func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.set_physics_process(false)
 main.items.set_physics_process(false)
 main.player.set_physics_process(false)
 var world = main.world
 var tree: Dictionary = world.trees[0]
 var root_cell: Vector2i = tree.cell
 for x in range(root_cell.x-2,root_cell.x+4):
  for y in range(root_cell.y-3,root_cell.y): world.apply_edit(Vector2i(x,y),-1)
  world.apply_edit(Vector2i(x,root_cell.y),0)
 world.solid.update_internals()
 var at := Vector2(root_cell.x*16+8,root_cell.y*16-10)
 var player = main.player
 player.position = at + Vector2(-24,0)
 var cell := root_cell + Vector2i.UP
 var bag = main.items.local_inventory()
 bag.add("stone",4)
 bag.add("dirt",2)
 check_result(main.items.craft(1,"stone_axe").begins_with("Создано") and bag.item_at(0) == "stone_axe", "First axe crafts without requiring unavailable wood")
 check_result(bag.count_item("stone") == 0 and bag.count_item("dirt") == 0 and Items.stack_limit("stone_axe") == 1, "Axe craft consumes exact materials and axes do not stack")
 check_result(world.tree_at(cell) == 0 and world.tree_at(root_cell) == -1 and world.tree_at(cell+Vector2i.RIGHT*2) == -1, "Only active trunk cells select a tree, not soil or leaves")
 check_result(main.items.primary_status(player,cell,0) == "Можно рубить дерево" and main.items.primary_duration(player,cell,0) == 1.6, "Axe has clear action feedback and configured hold duration")
 check_result(not main.items.chop_tree(player,cell,9) and world.trees[0].active, "Empty slot cannot harvest a tree")
 check_result(not main.items.use_primary(player,root_cell,0) and world.block_at(root_cell) == 0, "Axe cannot dig the soil under the trunk")
 player.position.x -= 120
 check_result(not main.items.chop_tree(player,cell,0), "Out-of-reach logging is rejected")
 player.position = at + Vector2(-24,0)
 var wall := cell + Vector2i.LEFT
 player.position = at + Vector2(-40,0)
 world.apply_edit(wall,2)
 world.solid.update_internals()
 await physics_frame
 await physics_frame
 check_result(not main.items.chop_tree(player,cell,0) and main.items.primary_status(player,cell,0) == "Ствол за преградой", "Logging through solid obstacles is rejected")
 world.apply_edit(wall,-1)
 player.position = at + Vector2(-24,0)
 world.solid.update_internals()
 await physics_frame
 await physics_frame
 player.dead = true
 check_result(not main.items.chop_tree(player,cell,0), "Dead player cannot harvest")
 player.dead = false
 main.items.animate_chop(player,cell,0)
 check_result(player.swing_tool and player.swing_remaining > 0 and main.items.attack_profiles.is_empty(), "Axe has an animation without creating melee damage")
 check_result(not player.resources.snapshot().has("stamina"), "Resource gathering has no stamina resource")
 var expected := int(tree.height)
 check_result(main.items.chop_tree(player,cell,0) and not world.trees[0].active, "Logging changes authoritative persistent tree state")
 check_result(main.items.drops.size() == 1 and main.items.drops.values()[0].item_id == "wood" and main.items.drops.values()[0].count == expected, "One tree drops wood matching its height")
 check_result(not main.items.chop_tree(player,cell,0) and main.items.drops.size() == 1, "Second simultaneous completion cannot duplicate wood")
 check_result(world.forest.falling.size() == 1 and world.block_at(root_cell) == 0, "Visual fall is separate from intact supporting soil")
 world.forest._process(1.1)
 check_result(world.forest.falling.is_empty(), "Falling artwork expires without reviving the tree")
 player.position = at
 main.items._physics_process(0.21)
 check_result(bag.count_item("wood") == expected and main.items.drops.is_empty(), "Felled wood uses ordinary automatic pickup")
 check_result(main.items.craft(1,"wood_block").begins_with("Создано") and bag.count_item("wood") == expected-2 and bag.count_item("wood_block") == 4, "Wood converts atomically into four buildable planks")
 var slot := 2
 check_result(bag.item_at(slot) == "wood_block", "Planks fit into the existing hotbar")
 var inside: Vector2i = world.cell_at(player.position)
 check_result(not main.items.place_selected(player,inside,slot) and bag.count_item("wood_block") == 4, "Planks cannot be placed inside a character or consumed on rejection")
 var build := root_cell + Vector2i(2,-1)
 check_result(main.items.place_selected(player,build,slot) and world.block_at(build) == 4 and world.solid.get_cell_source_id(build) == 2 and bag.count_item("wood_block") == 3, "Planks build as a distinct solid tile with exact inventory consumption")
 check_result(main.items.use_primary(player,build,9) and main.items.drops.values()[0].item_id == "wood_block", "Mining placed planks returns the same building item")
 main.items.set_drop(int(main.items.drops.keys()[0]),{})
 check_result(main.items.place_selected(player,build,slot), "Mined plank space remains buildable")
 world.solid.update_internals()
 player.position = world.cell_center(build) + Vector2(0,-70)
 player.velocity = Vector2.ZERO
 player.submit_command(0,false)
 player.set_physics_process(true)
 for i in range(80): await physics_frame
 player.set_physics_process(false)
 check_result(player.is_on_floor() and absf(player.position.y + 10 - build.y * 16) < 0.2, "Player physically lands on the new wooden tile")
 main.saves.save_path = "user://tests/logging.json"
 check_result(main.saves.save_now(), "Logging loot tools and plank edits save successfully")
 world.trees[0].active = true
 world.apply_edit(build,-1)
 bag.load_data([])
 check_result(main.saves.load_now() and not world.trees[0].active and world.block_at(build) == 4, "Reload preserves the felled tree and built plank block")
 check_result(main.items.local_inventory().count_item("wood") == expected-2 and main.items.local_inventory().count_item("stone_axe") == 1 and main.items.local_inventory().count_item("wood_block") == 2, "Reload restores exact wood axe and remaining planks")
 check_result(world.forest.falling.is_empty(), "Load never replays or restores expired fall animation")
 main.inventory_ui.toggle()
 check_result(main.inventory_ui.recipe_buttons.size() == 19 and main.inventory_ui.recipe_buttons.wood_block.get_parent().get_parent() is ScrollContainer, "All existing recipes and five equipment recipes are accessible through a scrollable crafting list")
 print("Logging failures: ",failures)
 quit(1 if failures else 0)
