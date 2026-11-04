extends SceneTree
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
 var mode := OS.get_cmdline_user_args()[0]
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.set_physics_process(false)
 main.items.set_physics_process(false)
 main.player.set_physics_process(false)
 if mode in ["write", "close_write"]:
  main.world.trees[0].height = 7
  main.world.trees[0].form = 1
  main.world.trees[0].seed = 10343
  main.world.apply_edit(main.world.trees[0].cell, -1)
  main.world.apply_edit(Vector2i(96, 22), -1)
  main.world.apply_edit(Vector2i(97, 21), 2)
  main.world.apply_edit(Vector2i(99, 21), 4)
  main.world.apply_decoration("wall", Vector2i(98, 21), 1)
  main.world.apply_decoration("torch", Vector2i(98, 21), 1)
  main.items.local_inventory().add("stone", 12)
  main.items.local_inventory().add("stone_pick", 1)
  main.items.local_inventory().add("stone_axe", 1)
  main.items.local_inventory().add("wood", 6)
  main.items.local_inventory().add("wood_block", 3)
  main.player.health = 81
  main.player.unclothed = true
  main.interaction.selected_slot = 1
  main.combat.world_time = 190.0
  var anchor := Vector2(1600, 384)
  var spirit: int = main.combat.spawn_entity("spirit", anchor + Vector2(10, -10), anchor)
  main.combat.entities[spirit].health = 1
  var contents = load("res://scripts/inventory.gd").new()
  contents.add("stone_blade", 1)
  main.combat.set_chest(7, {"owner": 1, "profile": main.saves.profile_id, "position": Vector2(1512, 342), "contents": contents.to_data()})
  if mode == "close_write":
   main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
   check_result(FileAccess.file_exists(main.saves.save_path) and main.closing, "Window close notification saves before requesting exit")
  else:
   main.saves.elapsed = 29.9
   main.saves._process(0.2)
   check_result(FileAccess.file_exists(main.saves.save_path) and main.saves.status.begins_with("Сохранено"), "Autosave interval writes complete world to physical file")
 else:
  check_result(main.saves.status.begins_with("Мир загружен"), "Second process automatically loads saved world at startup")
  check_result(main.world.block_at(Vector2i(96, 22)) == -1 and main.world.block_at(Vector2i(97, 21)) == 2, "Real restart preserves mined and placed blocks")
  check_result(main.world.wall_at(Vector2i(98, 21)) == 1 and main.world.torches.has(Vector2i(98, 21)), "Real restart preserves walls and torches")
  check_result(main.items.local_inventory().count_item("stone") == 12 and main.items.local_inventory().count_item("stone_pick") == 1 and main.interaction.selected_slot == 1, "Real restart restores inventory and hotbar selection")
  check_result(main.items.local_inventory().count_item("stone_axe") == 1 and main.items.local_inventory().count_item("wood") == 6 and main.items.local_inventory().count_item("wood_block") == 3 and main.world.block_at(Vector2i(99,21)) == 4 and main.world.solid.get_cell_source_id(Vector2i(99,21)) == 2, "Real restart preserves forestry items and distinct wooden tiles")
  check_result(main.player.health == 81 and main.player.unclothed and main.player.position == Vector2(1544, 328), "Real restart restores player health appearance and position")
  check_result(main.combat.world_time == 190 and main.combat.is_night(), "Real restart resumes night without resetting day")
  var tree: Dictionary = main.world.trees[0]
  check_result(not tree.active and tree.height == 7 and tree.form == 1 and tree.seed == 10343 and main.world.block_at(tree.cell) == -1, "Real restart preserves exact tree variant and removed support state")
  check_result(main.combat.entities.values()[0].health == 1 and main.combat.entities.values()[0].anchor == Vector2(1600, 384), "Real restart preserves wounded spirit and anchor")
  check_result(main.combat.chests[7].contents[0].item == "stone_blade", "Real restart retains equipment inside death chest")
 print("Restart ", mode, " failures: ", failures)
 quit(1 if failures else 0)
