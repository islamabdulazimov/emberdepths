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
 # Avoid real mouse driving or mutating terrain in this scripted scenario.
 main.interaction.set_process(false)
 if role == "host":
  check_result(main.network.host_game() == OK, "Host opens ENet server")
 else:
  main.network.join_game("127.0.0.1")
 var start := Time.get_ticks_msec()
 var saw_disconnect := false
 var saw_four := false
 var saw_mined := false
 var saw_built := false
 var saw_move := false
 var mined_once := false
 var late_snapshot := false
 var initial_x := 0.0
 var cell := Vector2i(96, 23)
 while Time.get_ticks_msec() - start < (4500 if role == "client2" else (5000 if role == "late" else 8500)):
  await process_frame
  if not main.network.active:
   continue
  if not main.network.connected:
   continue
  if main.get_node("Players").get_child_count() == 4:
   saw_four = true
  if saw_four and main.get_node("Players").get_child_count() == 3:
   saw_disconnect = true
  if role == "late" and not late_snapshot:
   late_snapshot = true
   check_result(main.world.block_at(cell) == 2 and main.world.changes.get(cell) == 2, "Late join receives existing edits")
  if role == "client1":
   if initial_x == 0.0:
    initial_x = main.player.position.x
   if main.player.position.x > initial_x + 8.0:
    saw_move = true
   var elapsed := Time.get_ticks_msec() - start
   var mode := 0
   var axis := 1.0 if elapsed < 350 else 0.0
   if elapsed > 500 and not mined_once:
    mode = 1
   elif mined_once and not saw_built:
    mode = 2
   main.network.submit_local(axis, false, cell, mode, 2, 1.0 / 60.0)
  if main.world.changes.get(cell, 99) == -1:
   saw_mined = true
   mined_once = true
  if main.world.changes.get(cell, 99) == 2:
   saw_built = true
 if role == "rejected":
  check_result(not main.network.active, "Fifth player is rejected")
 elif role == "host":
  check_result(saw_four, "Host and three clients share session")
  check_result(saw_mined and saw_built, "Host validates remote mining and building")
  check_result(saw_disconnect, "Disconnected player removed on host")
 elif role == "late":
  check_result(late_snapshot, "Late client joins")
  check_result(saw_disconnect, "Disconnect replicated to remaining client")
 else:
  check_result(saw_four, "Client sees four players")
  check_result(saw_mined and saw_built, "Client receives ordered terrain edits")
  if role == "client1":
   check_result(saw_move, "Remote input moves server-controlled player")
 if role == "client2":
  main.network.stop()
  await create_timer(0.4).timeout
 print("NETWORK ", role, " failures: ", failures)
 quit(1 if failures else 0)
