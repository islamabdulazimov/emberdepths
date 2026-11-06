extends RefCounted
const TEXTURE=preload("res://assets/recast/andrew.png")
static var rig:Dictionary=preload("res://assets/recast/andrew_rig.gd").DATA
static func draw_actor(body:Node2D) -> void:
 var row:int=rig.phases.find(body.phase)
 if row<0:row=1
 var t:float=body.motion_track.time/maxf(body.phase_duration,0.01)
 if body.phase=="chase":t=fposmod(body.visual_clock/TAU,1)
 if body.visual_hit>0 and body.phase=="chase":row=14;t=1-body.visual_hit/0.12
 var frame:=clampi(int(t*12),0,11)
 body.draw_set_transform(Vector2.ZERO,0,Vector2(body.visual_facing,1))
 body.draw_texture_rect_region(TEXTURE,Rect2(-64,-112,128,128),Rect2(frame*128,row*128,128,128),Color.WHITE.lerp(Color("ffe6b7"),minf(0.35,body.visual_hit*2)))
 body.draw_set_transform_matrix(Transform2D.IDENTITY)
