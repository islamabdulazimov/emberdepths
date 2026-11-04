extends SceneTree
# Slow-motion artwork review only; never loads or writes a playable world.
var output_dir := "user://action-review"
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="): output_dir = arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute(output_dir)
 root.size = Vector2i(1280,720)
 root.content_scale_size = Vector2i(960,540)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 RenderingServer.set_default_clear_color(Color("18252e"))
 var stage := Node2D.new()
 root.add_child(stage)
 var titles := ["Клинок · завершение удара","Кирка · отдача","Топор · взмах","Строительство · жест","Бальзам · поднять / опустить","Разворот · инерция ткани"]
 var players: Array = []
 for i in range(6):
  var col := i%3
  var row := i/3
  var label := Label.new()
  label.text = titles[i]
  label.position = Vector2(16+col*320,18+row*260)
  label.add_theme_font_size_override("font_size",15)
  label.add_theme_color_override("font_color",Color("e1dec2"))
  stage.add_child(label)
  var floor_line := ColorRect.new()
  floor_line.position = Vector2(col*320+15,220+row*260)
  floor_line.size = Vector2(290,1)
  floor_line.color = Color("455d68")
  stage.add_child(floor_line)
  var player = load("res://scenes/player.tscn").instantiate()
  player.get_node("Camera2D").enabled = false
  stage.add_child(player)
  player.set_process(false)
  player.set_physics_process(false)
  player.position = Vector2(160+col*320,180+row*260)
  player.scale = Vector2(4,4)
  players.append(player)
 for frame in range(144):
  var time := frame/60.0
  var phase := fposmod(time,1.2)
  var active := phase >= 0.15 and phase < 0.75
  var t := clampf((phase-0.15)/0.6,0,1)
  for i in range(6):
   var p = players[i]
   p.swing_remaining = 0
   p.work_remaining = 0
   p.medicine_progress = 0.5 if i == 4 and active else 0.0
   if i == 5:
    p.facing = -1 if phase > 0.6 else 1
    p.velocity = Vector2(p.facing*65,0)
   p._process(1.0/60.0)
   if i in [0,2] and active:
    p.swing_direction = Vector2.RIGHT.rotated(-0.25)
    p.swing_unarmed = false
    p.swing_tool = i == 2
    p.swing_remaining = 0.24*(1-t)
   elif i in [1,3] and active:
    p.work_direction = Vector2.RIGHT.rotated(0.2)
    p.work_kind = "pick" if i == 1 else "build"
    p.work_remaining = 0.30*(1-t)
   p.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  if frame%4 == 0: root.get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % (frame/4)))
 print("ACTION_GALLERY_OK · ",output_dir)
 quit()
