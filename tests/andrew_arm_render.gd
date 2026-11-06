extends SceneTree
const Pose = preload("res://scripts/visuals/andrew_pose.gd")
class ArmView extends Node2D:
 var shoulder := Vector2.ZERO
 var elbow := Vector2.ZERO
 var hand := Vector2.ZERO
 func _draw() -> void:
  preload("res://scripts/visuals/andrew_rig.gd").arm(self,shoulder,elbow,hand,Color("d6b197"))
func _initialize() -> void: call_deferred("run")
func foreground(img: Image, p: Vector2i) -> bool:
 if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height(): return false
 var c := img.get_pixelv(p)
 return not (c.r > 0.9 and c.b > 0.9 and c.g < 0.1)
func near_pixel(img: Image, p: Vector2) -> Vector2i:
 var at := Vector2i(p.round())
 for radius in range(3):
  for y in range(-radius,radius+1):
   for x in range(-radius,radius+1):
    if foreground(img,at+Vector2i(x,y)): return at+Vector2i(x,y)
 return Vector2i(-1,-1)
func connected(img: Image, start: Vector2i, goal: Vector2i) -> bool:
 if start.x < 0 or goal.x < 0: return false
 var visited := {start:true}
 var todo: Array[Vector2i] = [start]
 var index := 0
 while index < todo.size():
  var at := todo[index]
  index += 1
  if at == goal: return true
  for offset in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i.LEFT,Vector2i.RIGHT,Vector2i(-1,1),Vector2i.DOWN,Vector2i(1,1)]:
   var next: Vector2i = at+offset
   if not visited.has(next) and foreground(img,next):
    visited[next] = true
    todo.append(next)
 return false
func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("This check requires a real render window")
  quit(1)
  return
 root.size = Vector2i(640,480)
 root.content_scale_size = root.size
 RenderingServer.set_default_clear_color(Color.MAGENTA)
 var view := ArmView.new()
 view.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
 root.add_child(view)
 await process_frame
 await process_frame
 var checked := 0
 var failures := 0
 for phase in ["intro","chase","uppercut_windup","uppercut_active","uppercut_recovery","spin_windup","spin_active","spin_recovery","backflip","super_windup","super_flight","super_impact","super_recovery","stunned"]:
  for t in [0.0,0.25,0.5,0.75,1.0]:
   var p := Pose.sample(phase,t,1,1.3,48)
   for facing in [-1,1]:
    var rotation := Transform2D(float(p.rotation)*facing,Vector2.ZERO)
    var pivot := Vector2(0,-28)
    rotation.origin = pivot-rotation*pivot
    var local := Transform2D(float(p.lean)*facing,Vector2(p.scale)*Vector2(facing*(0.16+0.84*absf(p.turn)),1),0,p.offset)*rotation
    view.transform = Transform2D(0,Vector2(2,2),0,Vector2(320,300))*local
    for side in [-1,1]:
     view.shoulder = Vector2(side*17,-43)
     view.elbow = p.back_elbow if side < 0 else p.front_elbow
     view.hand = p.back_hand if side < 0 else p.front_hand
     view.queue_redraw()
     await process_frame
     await RenderingServer.frame_post_draw
     var img := root.get_texture().get_image()
     var a := near_pixel(img,view.transform*view.shoulder)
     var b := near_pixel(img,view.transform*view.elbow)
     var c := near_pixel(img,view.transform*view.hand)
     if not connected(img,a,b) or not connected(img,b,c):
      img.save_png("/tmp/andrew-arm-failure-%d.png" % failures)
      failures += 1
      push_error("Disconnected arm pixels: %s t=%s facing=%s side=%s" % [phase,t,facing,side])
     checked += 1
 print("ANDREW_ARM_RENDER samples=",checked," failures=",failures)
 quit(1 if failures else 0)
