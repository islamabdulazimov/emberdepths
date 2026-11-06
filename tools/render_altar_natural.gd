extends "res://tests/altar_render.gd"
# Actual natural terrain, no flattening or saved-world editing.
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.player.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.exploration.set_process(false);main.survival.set_physics_process(false);main.encounter.set_physics_process(false);main.fps_label.hide()
 main.world.configure_new("small");main.world.world_seed=72419;main.world.generate();main.npcs.sync()
 main.encounter.journal.apply({});main.encounter.ensure_altar()
 var at:Vector2=main.encounter.journal.altar
 main.player.position=main.world.safe_spawn_position(main.world.cell_at(at).x-3)
 main.player.appearance={"gender":"female","build":"normal","hair":"long_tail","hair_color":2,"skin":1}
 main.combat.world_time=100
 var camera:Camera2D=main.player.get_node("Camera2D");camera.limit_right=main.world.world_width*16;camera.limit_bottom=main.world.world_depth*16;camera.align();camera.reset_smoothing();camera.force_update_scroll()
 for i in range(6):await process_frame
 await shot("natural")
 check(at!=Vector2.ZERO,"natural review shows seeded surface altar")
 main.queue_free();await process_frame;quit(1 if failures else 0)
