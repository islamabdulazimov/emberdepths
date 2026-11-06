extends RefCounted
const TEXTURES := {
 "seamling":preload("res://assets/recast/mob_seamling.png"),"hollowbeak":preload("res://assets/recast/mob_hollowbeak.png"),"ashweaver":preload("res://assets/recast/mob_ashweaver.png"),"void_collector":preload("res://assets/recast/mob_void_collector.png"),"ashling":preload("res://assets/recast/mob_ashling.png"),"spirit":preload("res://assets/recast/mob_spirit.png")}
const COUNTS := [8,12,8,6,8,4,8,6]
static func draw_frame(canvas: Node2D,kind: String,row: int,frame: int,at: Vector2 = Vector2.ZERO,facing: int = 1,alpha: float = 1) -> void:
 canvas.draw_set_transform(at,0,Vector2(facing,1))
 canvas.draw_texture_rect_region(TEXTURES[kind],Rect2(-32,-54,64,64),Rect2(clampi(frame,0,COUNTS[row]-1)*64,row*64,64,64),Color(1,1,1,alpha))
 canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
static func draw_actor(canvas: Node2D) -> void:
 var row:=0;var frame:=int(canvas.clock*5)%8
 var d:Dictionary=preload("res://data/creatures.gd").DEFINITIONS.get(canvas.kind,preload("res://data/battle.gd").ASHLING)
 match canvas.attack_state:
  "windup":row=2;frame=int(canvas.motion_track.time/float(d.windup)*COUNTS[2])
  "active":row=3;frame=int(canvas.motion_track.time/float(d.active)*COUNTS[3])
  "stagger":row=7;frame=int(canvas.motion_track.time/1.0*COUNTS[7])
  "recovery":row=4;frame=int(canvas.motion_track.time/float(d.recovery)*COUNTS[4])
 if row==0 and (absf(canvas.visual_movement)>2 or canvas.kind in ["ashweaver","spirit"]):row=1;frame=int(canvas.visual_stride*12)%12
 if canvas.hurt_flash>0:row=5;frame=int((1-canvas.hurt_flash/0.16)*4)
 draw_frame(canvas,canvas.kind,row,frame,Vector2.ZERO,canvas.visual_facing)
 if canvas.kind=="hollowbeak" and canvas.attack_state=="active":
  var reach:float=canvas.attack_area().size.x
  var x:float=canvas.attack_facing*reach
  canvas.draw_line(Vector2(x,-19),Vector2(x+canvas.attack_facing*3,-11),Color("b5c5b9"),1)
  canvas.draw_line(Vector2(x+canvas.attack_facing*3,-11),Vector2(x,-3),Color("b5c5b9"),1)
 if preload("res://data/presentation.gd").combat_debug and canvas.attack_state in ["windup","active"]:
  var area:Rect2=canvas.attack_area();area.position-=canvas.position
  canvas.draw_rect(area,Color(1,0.6,0.2,0.15))
  canvas.draw_rect(area,Color("e1dec2"),false,1)
