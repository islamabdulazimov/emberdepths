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
 var role := OS.get_cmdline_user_args()[0]
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 if role == "hold":
  main.items.local_inventory().add("stone", 17)
  check_result(main.saves.save_now(), "Owner process writes original slot")
  print("LOCK_READY")
  await create_timer(10).timeout
 elif role == "probe":
  var before := FileAccess.get_file_as_string(main.saves.save_path).sha256_text()
  check_result(main.saves.identity_error.contains("уже открыт") and not main.saves.owns_lock, "Independent second process cannot own live profile lock")
  check_result(not main.saves.save_now() and main.network.host_game() != OK, "Locked second process cannot write or host conflicting character")
  check_result(FileAccess.get_file_as_string(main.saves.save_path).sha256_text() == before, "Second process leaves original save bytes unchanged")
 else:
  check_result(main.saves.identity_error == "" and main.saves.owns_lock, "Stale profile lock is recovered after owner process crash")
  check_result(main.saves.status.begins_with("Мир загружен") and main.items.local_inventory().count_item("stone") == 17, "Crash recovery loads intact original inventory")
 print("Profile lock ", role, " failures: ", failures)
 quit(1 if failures else 0)
