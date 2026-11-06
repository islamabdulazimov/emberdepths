extends SceneTree
const Atlas=preload("res://scripts/visuals/actor_atlas.gd")
var out:="/tmp/recast-gallery"
var stage:Node2D
class ReviewStage extends Node2D:
 func authoritative() -> bool:return true
func _initialize() -> void:call_deferred("run")
func label(at:Vector2,value:String) -> void:
 var node:=Label.new();node.position=at;node.text=value;node.theme=preload("res://scripts/visuals/art_direction.gd").theme();node.add_theme_font_size_override("font_size",12);stage.add_child(node)
func shot(name:String) -> void:
 await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+name+".png")
func reset_stage() -> void:
 if is_instance_valid(stage):stage.queue_free();await process_frame
 stage=ReviewStage.new();root.add_child(stage)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,720)
 RenderingServer.set_default_clear_color(Color("172630"))
 await reset_stage()
 var actors:=Node2D.new();stage.add_child(actors)
 var index:=0
 for gender in ["male","female"]:
  for hair in ["short","long"]:
   for skin in range(5):
    var pos:=Vector2(55+(index%5)*190,108+(index/5)*130)
    label(Vector2(pos.x-42,pos.y-98),"%s · %s · %d"%[gender,hair,skin+1])
    for geared in [false,true]:
     var p=load("res://scenes/player.tscn").instantiate();actors.add_child(p);p.set_physics_process(false);p.set_process(false);p.get_node("Camera2D").enabled=false;p.appearance={"gender":gender,"hair":hair,"skin":skin};p.position=pos+Vector2(72 if geared else 0,0);p.scale=Vector2(2,2);p.visual_grounded=true
     if geared:p.equipment={"weapon":"wood_sword","shield":"wood_shield","head":"wood_helm","body":"wood_armor","legs":"wood_legs"}
    index+=1
 await shot("appearance-matrix")
 await reset_stage()
 var enemies:Array=[]
 for i in range(6):
  var e=CharacterBody2D.new();e.set_script(load("res://scripts/enemy.gd"));e.kind=Atlas.TEXTURES.keys()[i];stage.add_child(e);e.set_physics_process(false);e.set_process(false);e.position=Vector2(145+i%3*315,213+i/3*245);e.scale=Vector2(3,3);enemies.append(e);label(e.position+Vector2(-100,-182),e.kind)
 var effects:=Node2D.new();effects.set_script(load("res://scripts/visuals/effects.gd"));stage.add_child(effects);effects.scale=Vector2(3,3);effects.set_process(false)
 DirAccess.make_dir_recursive_absolute(out+"/mobs")
 for frame in range(240):
  var time:=frame/60.0;var row:=mini(7,int(time/0.5));var progress:=fposmod(time,0.5)/0.5
  if frame==180:
   for e in enemies:effects.creature_death(e.kind,e.position/3,1)
  effects._process(1.0/60)
  for e in enemies:
   e.visible=row!=6
   e.attack_state=["chase","chase","windup","active","recovery","chase","chase","stagger"][row]
   e.velocity=Vector2(50 if row==1 else 0,0);e.hurt_flash=0.16*(1-progress) if row==5 else 0
   var cfg:Dictionary=load("res://data/creatures.gd").DEFINITIONS.get(e.kind,load("res://data/battle.gd").ASHLING)
   e.attack_elapsed=progress*(cfg.windup if row==2 else cfg.active if row==3 else cfg.recovery if row==4 else 1)
   e._process(1.0/60)
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"/mobs/%04d.png"%frame)
  if frame==20:root.get_texture().get_image().save_png(out+"/mob-gallery.png")
 # A real Boss node for each phase. Presentation is sampled; gameplay is stopped.
 var phases:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/recast/andrew_rig.json")).phases
 for page in range(2):
  await reset_stage()
  var bosses:Array=[]
  for i in range(8):
   var b=load("res://scenes/andrew.tscn").instantiate();b.definition=load("res://data/bosses.gd").ANDREW;b.state=load("res://scripts/boss_state.gd").new();b.state.begin(b.definition,1);b.encounter=stage;stage.add_child(b);b.set_process(false);b.set_physics_process(false);b.position=Vector2(120+i%4*240,220+i/4*255);b.scale=Vector2(2,2);b.phase=phases[page*8+i];b.phase_duration=1;b.indicator_active=false;bosses.append(b);label(Vector2(i%4*240+6,15+i/4*255),b.phase)
  DirAccess.make_dir_recursive_absolute(out+"/boss-%d"%page)
  for frame in range(120):
   for b in bosses:
    b.phase_elapsed=frame/119.0;b.motion_track.time=b.phase_elapsed;b.visual_clock=frame/119.0*TAU;b.queue_redraw()
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/boss-%d/%04d.png"%[page,frame])
   if frame==65:root.get_texture().get_image().save_png(out+"/andrew-%d.png"%page)
 print("RECAST_GALLERY_OK")
 stage.queue_free();await process_frame;quit()
