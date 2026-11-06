extends SceneTree
var output_dir := "user://expansion-review"
var main: Node2D
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
 main.player.reset_physics_interpolation()
 var camera: Camera2D = main.player.get_node("Camera2D")
 camera.align()
 camera.reset_smoothing()
 camera.reset_physics_interpolation()
 camera.force_update_scroll()
 main._process(0)
 main.interaction._process(0)
 await create_timer(0.15).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="): output_dir = arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute(output_dir)
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.fps_label.hide()
 main.set_physics_process(false)
 main.combat.set_physics_process(false)
 main.interaction.set_process(false)
 main.exploration.set_process(false)
 main.player.set_physics_process(false)
 main.encounter.enabled = false
 main.world.configure_expanded()
 main.world.generate()
 main.world.solid.update_internals()
 main.exploration.initialize_loot()
 main.select_local_player(1)
 main.combat.world_time = 80
 var village: Dictionary = main.world.sites[2]
 main.player.position = Vector2((village.rect.position.x+20)*16,village.rect.end.y*16-42)
 await capture("settlement")
 var root_site: Dictionary = main.world.sites[0]
 main.player.position = Vector2((root_site.rect.end.x-12)*16,(root_site.rect.end.y-2)*16-10)
 var at := Vector2((root_site.rect.end.x-4)*16+8,(root_site.rect.end.y-2)*16)
 main.combat.spawn_entity("seamling",at)
 await capture("root-shelter")
 var archive: Dictionary = main.world.sites[1]
 main.player.position = Vector2((archive.rect.end.x-16)*16,(archive.rect.end.y-2)*16-10)
 main.combat.spawn_entity("void_collector",Vector2((archive.rect.end.x-12)*16+8,(archive.rect.end.y-2)*16))
 main.combat.spawn_entity("hollowbeak",Vector2((archive.rect.position.x+22)*16+8,(archive.rect.end.y-2)*16))
 await capture("well-archive")
 for y in range(100,134):
  if main.world.block_at(Vector2i(220,y)) >= 0 and main.world.character_fits(Vector2(220*16+8,y*16-10)):
   main.player.position = Vector2(220*16+8,y*16-10)
   main.world.apply_decoration("torch",Vector2i(221,y-2),1)
   main.combat.spawn_entity("ashweaver",Vector2(223*16,y*16-12))
   break
 await capture("deep-chambers")
 print("EXPANSION_RENDER_OK · ",output_dir)
 main.queue_free()
 await process_frame
 quit()
