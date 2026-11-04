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
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 var player = main.player
 var world = main.world
 for i in range(90):
  await physics_frame
 check_result(player.is_on_floor(), "Player lands on solid terrain")
 var start: Vector2 = player.position
 player.submit_command(1.0, false)
 for i in range(30):
  await physics_frame
 player.submit_command(0.0, false)
 check_result(player.position.x > start.x + 30.0, "Movement advances player")
 for i in range(30):
  await physics_frame
 var floor_y: float = player.position.y
 player.submit_command(0.0, true)
 for i in range(10):
  await physics_frame
 check_result(player.position.y < floor_y - 15.0, "Jump rises above floor")
 for i in range(90):
  await physics_frame
 check_result(player.is_on_floor(), "Jump lands without falling through tiles")
 check_result(not world.walls.collision_enabled, "Background walls have no collision")
 var cells: Array = world.solid.get_used_cells()
 var second = load("res://scripts/world.gd").new()
 root.add_child(second)
 check_result(cells == second.solid.get_used_cells(), "Same seed reproduces terrain and caves")
 second.queue_free()
 print("Smoke failures: ", failures)
 quit(1 if failures else 0)
