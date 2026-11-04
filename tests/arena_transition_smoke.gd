extends SceneTree
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
 for i in range(4): await process_frame
func run() -> void:
 if not OS.get_cmdline_user_args().has("--profile=arena_transition"):
  push_error("Use run_save_restart.py; this fixture requires its isolated test profile")
  quit(1)
  return
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 main.set_physics_process(false)
 main.combat.set_physics_process(false)
 main.items.set_physics_process(false)
 main.player.set_physics_process(false)
 main.player.position = Vector2(1544,342)
 main.items.local_inventory().add("stone",7)
 main.world.apply_edit(Vector2i(97,21),2)
 check_result(main.saves.save_now(),"Normal world can save before a practice visit")
 var path: String = main.saves.save_path
 var identity: String = main.saves.profile_id
 var digest := FileAccess.get_file_as_string(path).sha256_text()
 var button: Button
 for child in main.get_node("HUD").get_children():
  if child is Button and child.text == "Проверка боя": button = child
 if button == null:
  check_result(false,"Practice entry button exists")
  quit(1)
  return
 button.pressed.emit()
 await settle()
 var arena = current_scene
 check_result(arena != null and arena.has_meta("combat_test") and not arena.saves.owns_lock,"Actual menu entry opens isolated arena and releases normal profile lock")
 if arena == null or not arena.has_meta("combat_test"):
  quit(1)
  return
 arena.items.local_inventory().add("dirt",99)
 arena.world.apply_edit(Vector2i(94,25),4)
 check_result(not arena.saves.save_now() and FileAccess.get_file_as_string(path).sha256_text() == digest,"Playing and refusing a practice save leave original save bytes untouched")
 arena.leave_arena()
 await settle()
 var restored = current_scene
 check_result(restored != null and not restored.has_meta("combat_test") and restored.saves.status.begins_with("Мир загружен") and restored.items.local_inventory().count_item("stone") == 7 and restored.items.local_inventory().count_item("dirt") == 0 and restored.world.block_at(Vector2i(97,21)) == 2,"Returning loads original world and inventory without importing arena loot")
 check_result(restored.saves.profile_id == identity and restored.saves.owns_lock and FileAccess.get_file_as_string(path).sha256_text() == digest,"Returning reacquires the same profile without changing its saved world")
 print("Arena transition failures: ",failures)
 quit(1 if failures else 0)
