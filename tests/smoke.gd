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
 # Isolate edits at the flat spawn area, independent of movement tests.
 player.position = Vector2(1544, 342)
 player.velocity = Vector2.ZERO
 player.submit_command(0.0, false)
 var bodies: Array = [player]
 var support := Vector2i(96, 22)
 var side := Vector2i(97, 22)
 var inside := Vector2i(96, 21)
 check_result(not world.request_edit(player, inside, 1, bodies), "Cannot build inside player")
 check_result(not world.request_edit(player, support, 1, bodies), "Cannot replace occupied solid")
 check_result(not world.request_edit(player, Vector2i(0, 22), -1, bodies), "Cannot mine beyond reach")
 check_result(not world.request_edit(player, Vector2i(-1, 22), 1, bodies), "Cannot edit outside world")
 check_result(not world.request_edit(player, side, 999, bodies), "Reject unknown block ID")
 check_result(world.request_edit(player, side, -1, bodies), "Mine reachable solid")
 check_result(world.block_at(side) == -1 and world.walls.get_cell_source_id(side) != -1, "Mining removes only solid layer")
 check_result(world.changes[side] == -1, "Mined air recorded by coordinates")
 check_result(world.request_edit(player, side, 2, bodies), "Place selected stone in empty cell")
 check_result(world.block_at(side) == 2 and world.changes[side] == 2, "Placement records stable block ID")
 var unsupported := Vector2i(96, 18)
 check_result(not world.request_edit(player, unsupported, 1, bodies), "Cannot place unsupported floating block")
 check_result(world.request_edit(player, support, -1, bodies), "Mine supporting ground")
 for i in range(30):
  await physics_frame
 check_result(player.position.y > 350.0 and player.is_on_floor(), "Updated collision allows falling into mined hole and landing")
 print("Smoke failures: ", failures)
 quit(1 if failures else 0)
