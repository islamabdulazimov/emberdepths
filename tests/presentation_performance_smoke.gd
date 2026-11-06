extends SceneTree
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
 main.combat.spawning_enabled = false
 main.player.get_node("Camera2D").enabled = false
 var camera := Camera2D.new()
 camera.position = main.world.spawn_position()
 camera.zoom = Vector2(2,2)
 main.add_child(camera)
 camera.make_current()
 await process_frame
 await physics_frame
 var detail = main.world.detail
 detail._process(0)
 var count: int = detail.rebuilds
 for i in range(240): detail._process(1.0/240)
 check_result(detail.rebuilds == count,"Stationary terrain reuses retained edges for 240 frames")
 var cell := Vector2i(96,22)
 var edge := Rect2(Vector2(cell)*16,Vector2(16,1))
 var had_top := false
 for mark in detail.edges.rectangles: had_top = had_top or mark[0] == edge
 check_result(had_top,"Visible terrain cache contains the surface edge")
 main.world.apply_edit(cell,-1)
 check_result(detail.dirty,"Mining invalidates presentation at the authoritative mutation boundary")
 detail._process(0)
 var removed := true
 for mark in detail.edges.rectangles: removed = removed and mark[0] != edge
 check_result(removed and detail.rebuilds == count+1,"Mining removes the old rim on the next render update")
 main.world.apply_edit(cell,0)
 detail._process(0)
 var restored := false
 for mark in detail.edges.rectangles: restored = restored or mark[0] == edge
 check_result(restored,"Building restores the rim without stale cached geometry")
 camera.position.x += 160
 camera.force_update_scroll()
 detail._process(0)
 check_result(detail.rebuilds > count+2,"Moving the camera rebuilds newly visible terrain")
 main.world.generate()
 check_result(detail.dirty,"Regeneration invalidates retained presentation even with unchanged seed")
 check_result(Engine.max_fps == 240 and Engine.physics_ticks_per_second == 60,"240 FPS presentation keeps the original 60 Hz simulation")
 check_result(main.player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON,"Host movement uses render interpolation between physical steps")
 check_result(main.inventory_ui.slot_styles.size() == 2,"Inventory shares two styles instead of allocating a style for every slot refresh")
 var texture = preload("res://assets/canopy.png")
 check_result(texture.get_size() == Vector2(256,156),"Original foliage atlas contains twelve crown variations")
 var fighter = main.player.fighter
 fighter.begin("roll",Vector2.RIGHT,0.44)
 var time: float = main.combat.world_time
 var resource_state: Dictionary = main.player.resources.snapshot()
 for i in range(240):
  detail._process(1.0/240)
  main.sky._process(1.0/240)
 check_result(fighter.elapsed == 0 and main.combat.world_time == time and main.player.resources.snapshot() == resource_state,"Environmental render updates cannot advance combat, shared time or stamina")
 main.queue_free()
 await process_frame
 print("Presentation performance failures: ",failures)
 quit(1 if failures else 0)
