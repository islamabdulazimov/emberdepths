extends SceneTree
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ", message)
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
 main.saves.save_path = "user://tests/load_position.json"
 # An excavated room away from spawn, not an artificial position in solid soil.
 for x in range(98, 106):
  for y in range(35, 41):
   main.world.apply_edit(Vector2i(x, y), -1)
 main.world.solid.update_internals()
 main.player.position = Vector2(1624, 646)
 for i in range(90): await physics_frame
 main.player.set_physics_process(false)
 var saved: Vector2 = main.player.position
 check_result(saved.distance_to(main.world.spawn_position()) > 200 and main.world.character_fits(saved), "Saved character is on physical cave floor far from spawn")
 check_result(main.saves.save_now() and main.saves.status.contains("(101, 40)"), "Save feedback shows saved coordinates")
 main.player.position = main.world.spawn_position()
 check_result(main.saves.load_now() and main.player.position == saved, "Load returns to saved cave position instead of spawn")
 var camera: Camera2D = main.player.get_node("Camera2D")
 check_result(camera.get_screen_center_position().distance_to(saved + camera.position) < 1, "Camera centers on restored player immediately without showing spawn first")
 check_result(main.saves.status.contains("(101, 40)") and not main.saves.status.contains("безопасная"), "Load feedback confirms exact restored location")
 # A truly blocked position must still use the safety path and explain it.
 var state: Dictionary = main.saves.capture()
 state.world.blocks[main.world.cell_at(saved)] = 2
 check_result(main.saves.restore(state) == "" and main.player.position != saved and main.saves.restore_notice.contains("точка занята блоком"), "Actual obstruction relocates safely and reports why")
 print("Load position failures: ", failures)
 quit(1 if failures else 0)
