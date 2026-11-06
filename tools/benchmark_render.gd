extends SceneTree
# A real window is required: headless throughput is not rendering performance.
# -- --uncapped --arena --seconds=6 --out=/tmp/frame.png
var scene: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Use a real display: a headless run cannot measure graphics FPS.")
  quit(1)
  return
 var duration := 6.0
 var arena := false
 var screenshot := ""
 for arg in OS.get_cmdline_user_args():
  if arg == "--uncapped": Engine.max_fps = 0
  elif arg == "--arena": arena = true
  elif arg.begins_with("--seconds="): duration = clampf(arg.trim_prefix("--seconds=").to_float(),2,60)
  elif arg.begins_with("--out="): screenshot = arg.trim_prefix("--out=")
 scene = load("res://scenes/combat_arena.tscn" if arena else "res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 await create_timer(2).timeout
 var samples: Array[float] = []
 var draw_calls := 0.0
 var started := Time.get_ticks_usec()
 var previous := started
 while Time.get_ticks_usec()-started < duration*1000000:
  await process_frame
  var now := Time.get_ticks_usec()
  samples.append(float(now-previous)/1000)
  draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
  previous = now
 var elapsed := float(Time.get_ticks_usec()-started)/1000000
 samples.sort()
 print("RENDER_BENCHMARK ",JSON.stringify({"generator":scene.world.generator_version,"world_width":scene.world.world_width,"world_depth":scene.world.world_depth,"static_memory_mib":snappedf(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576,0.1),"scene":"arena" if arena else "world","renderer":RenderingServer.get_video_adapter_name(),"window":str(DisplayServer.window_get_size()),"cap":Engine.max_fps,"physics_hz":Engine.physics_ticks_per_second,"fps":snappedf(samples.size()/elapsed,0.1),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*0.95)],"draw_calls_average":snappedf(draw_calls/samples.size(),0.1)}))
 if screenshot != "":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(screenshot)
 scene.queue_free()
 await process_frame
 quit()
