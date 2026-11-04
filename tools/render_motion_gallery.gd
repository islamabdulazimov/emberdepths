extends SceneTree
class PreviewEncounter extends Node2D:
 func authoritative() -> bool: return true
var output_dir := "user://motion-review"
var actors: Array = []
var labels: Array = []
var players: Array = []
var fixture: Node2D
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="): output_dir = arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute(output_dir)
 root.size = Vector2i(1280,720)
 root.content_scale_size = Vector2i(960,540)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 RenderingServer.set_default_clear_color(Color("18252e"))
 fixture = PreviewEncounter.new()
 root.add_child(fixture)
 var titles := ["Andrew · вступление", "Апперкот", "Вертушка", "Отскок", "Прыжок и удар", "Оглушение", "Тяжёлый шаг", "Герой · шаг / взлёт / падение"]
 for i in range(8):
  var col := i % 4
  var row := i / 4
  var label := Label.new()
  label.add_theme_color_override("font_color",Color("e1dec2"))
  label.add_theme_font_size_override("font_size",15)
  label.text = titles[i]
  label.position = Vector2(14+col*240,18+row*250)
  fixture.add_child(label)
  labels.append(label)
  var floor_line := ColorRect.new()
  floor_line.color = Color("455d68")
  floor_line.position = Vector2(col*240+10,226+row*250)
  floor_line.size = Vector2(220,1)
  fixture.add_child(floor_line)
  if i == 7: continue
  var actor = load("res://scenes/andrew.tscn").instantiate()
  actor.definition = load("res://data/bosses.gd").ANDREW
  actor.state = load("res://scripts/boss_state.gd").new()
  actor.state.begin(actor.definition,1)
  actor.encounter = fixture
  actor.set_process(false)
  actor.set_physics_process(false)
  actor.scale = Vector2(2,2)
  actor.position = Vector2(col*240+120,row*250+226)
  fixture.add_child(actor)
  actor.set_process(false)
  actor.set_physics_process(false)
  actors.append(actor)
 for i in range(3):
  var p = load("res://scenes/player.tscn").instantiate()
  p.set_process(false)
  p.set_physics_process(false)
  p.get_node("Camera2D").enabled = false
  p.position = Vector2(760+i*65,450)
  p.scale = Vector2(3,3)
  fixture.add_child(p)
  p.set_process(false)
  p.set_physics_process(false)
  players.append(p)
 for frame in range(120):
  var time := frame / 60.0
  var phases: Array = [ ["intro",2.2], ["uppercut_windup",0.6], ["spin_windup",0.85], ["backflip",0.75], ["super_windup",1.25], ["stunned",2.0], ["chase",2.0] ]
  var local_times: Array = [time,time,time,fmod(time,0.75),time,time,time]
  if time >= 0.6:
   phases[1] = ["uppercut_active",0.16] if time < 0.76 else ["uppercut_recovery",0.8]
   local_times[1] = time-0.6 if time < 0.76 else time-0.76
  if time >= 0.85:
   phases[2] = ["spin_active",0.4] if time < 1.25 else ["spin_recovery",1.05]
   local_times[2] = time-0.85 if time < 1.25 else time-1.25
  if time >= 1.25:
   phases[4] = ["super_flight",0.9]
   local_times[4] = time-1.25
  for i in range(actors.size()):
   var a = actors[i]
   a.phase = phases[i][0]
   a.phase_duration = phases[i][1]
   a.phase_elapsed = local_times[i]
   a.velocity.x = 48 if i == 6 else 0
   a._process(1.0/60.0)
   labels[i].text = titles[i]
  for i in range(3):
   var p = players[i]
   p.velocity = Vector2(115,0) if i == 0 else Vector2(0,-200 if i == 1 else 200)
   p._process(1.0/60.0)
  await process_frame
  await RenderingServer.frame_post_draw
  if frame % 4 == 0:
   root.get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % (frame/4)))
 print("MOTION_GALLERY_OK · ",output_dir)
 quit()
