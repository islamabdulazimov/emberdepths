extends SceneTree
# 60 FPS presentation review. No world, profile or network is created.
class ReviewPlayer extends "res://scripts/player.gd":
 var review_grounded := true
 func presentation_grounded() -> bool: return review_grounded
class PreviewEncounter extends Node2D:
 func authoritative() -> bool: return true
var output_dir := "user://fluid-review"
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="): output_dir = arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute(output_dir)
 root.size = Vector2i(1280,720)
 root.content_scale_size = Vector2i(960,540)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 RenderingServer.set_default_clear_color(Color("18252e"))
 var stage := PreviewEncounter.new()
 root.add_child(stage)
 var actors := Node2D.new()
 stage.add_child(actors)
 var players: Array = []
 var titles := ["Шаг · остановка · разворот","Взлёт · падение · приземление","Клинок · замах / удар / выход","Перекат · вход / вращение / выход","Парирование · стойка / возврат","Andrew · подготовка / апперкот"]
 for i in range(6):
  var col := i%3
  var row := i/3
  var title := Label.new()
  title.position = Vector2(14+col*320,18+row*260)
  title.text = titles[i]
  title.add_theme_font_size_override("font_size",13)
  title.add_theme_color_override("font_color",Color("e1dec2"))
  stage.add_child(title)
  var line := Line2D.new()
  line.points = PackedVector2Array([Vector2(15+col*320,221+row*260),Vector2(305+col*320,221+row*260)])
  line.width = 1
  line.default_color = Color("455d68")
  stage.add_child(line)
  if i == 5: continue
  var p = load("res://scenes/player.tscn").instantiate()
  p.set_script(ReviewPlayer)
  p.get_node("Camera2D").enabled = false
  actors.add_child(p)
  p.set_physics_process(false)
  p.set_process(false)
  p.scale = Vector2(4,4)
  p.position = Vector2(160+col*320,181+row*260)
  players.append(p)
 var boss = load("res://scenes/andrew.tscn").instantiate()
 boss.definition = load("res://data/bosses.gd").ANDREW
 boss.state = load("res://scripts/boss_state.gd").new()
 boss.state.begin(boss.definition,1)
 boss.encounter = stage
 actors.add_child(boss)
 boss.set_physics_process(false)
 boss.set_process(false)
 boss.position = Vector2(800,481)
 boss.scale = Vector2(2.5,2.5)
 for frame in range(240):
  var time := frame/60.0
  var loop := fposmod(time,2.0)
  for i in range(5):
   var p = players[i]
   p.velocity = Vector2.ZERO
   p.review_grounded = true
   if i == 0:
    p.velocity.x = 100 if loop < 0.8 else (-100 if loop > 1.2 else 0)
    if absf(p.velocity.x) > 1: p.facing = int(signf(p.velocity.x))
   elif i == 1:
    var flight := clampf((loop-0.25)/0.85,0,1)
    p.review_grounded = loop < 0.25 or loop >= 1.1
    p.velocity.y = lerpf(-290,290,flight) if not p.review_grounded else 0
    p.position.y = 181-sin(flight*PI)*45
   elif i in [2,3,4]:
    var action := "attack" if i == 2 else ("roll" if i == 3 else "parry")
    var duration := 0.47 if i == 2 else (0.44 if i == 3 else 0.58)
    if loop >= 0.3 and loop < 0.3+duration:
     if p.fighter.mode != action: p.fighter.begin(action,Vector2.RIGHT,duration)
     p.fighter.elapsed = loop-0.3
     p.swing_direction = Vector2.RIGHT
    else: p.fighter.reset()
   p._process(1.0/60)
  var phase := "uppercut_windup" if loop < 0.6 else ("uppercut_active" if loop < 0.76 else "uppercut_recovery")
  boss.phase = phase
  boss.phase_elapsed = loop if loop < 0.6 else (loop-0.6 if loop < 0.76 else minf(0.8,loop-0.76))
  boss.phase_duration = 0.6 if loop < 0.6 else (0.16 if loop < 0.76 else 0.8)
  boss._process(1.0/60)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % frame))
 print("FLUID_REVIEW_OK · ",output_dir)
 quit()
