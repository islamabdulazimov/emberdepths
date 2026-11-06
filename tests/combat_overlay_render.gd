extends SceneTree
var failures:=0
func check(ok: bool,label: String) -> void:
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func capture(actor:Node,debug:bool) -> Image:
 preload("res://data/presentation.gd").combat_debug=debug;actor.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func red_pixels(image:Image) -> int:
 var count:=0
 for y in range(image.get_height()):
  for x in range(image.get_width()):
   var c:=image.get_pixel(x,y)
   if c.r>0.65 and c.g<0.5 and c.b<0.5:count+=1
 return count
func run() -> void:
 root.size=Vector2i(640,480);root.content_scale_size=root.size
 RenderingServer.set_default_clear_color(Color("18252e"))
 check(not preload("res://data/presentation.gd").combat_debug,"combat debug off by default")
 var boss=load("res://scenes/andrew.tscn").instantiate();boss.definition=preload("res://data/bosses.gd").ANDREW
 root.add_child(boss);boss.set_process(false);boss.set_physics_process(false);boss.position=Vector2(320,300);boss.locked_target=boss.position
 for phase in ["uppercut_windup","spin_windup"]:
  boss.phase=phase
  var normal:Image=await capture(boss,false);var debug:Image=await capture(boss,true)
  check(normal.get_data()!=debug.get_data(),phase+" zone only in developer mode")
 boss.phase="super_flight";boss.indicator_active=true
 var normal:Image=await capture(boss,false);var debug:Image=await capture(boss,true)
 check(red_pixels(normal)>100 and normal.get_data()==debug.get_data(),"red landing indicator survives with identical geometry")
 boss.indicator_active=false;boss.phase="super_impact"
 check(red_pixels(await capture(boss,false))>100,"impact warning retained")
 boss.queue_free();await process_frame;quit(1 if failures else 0)
