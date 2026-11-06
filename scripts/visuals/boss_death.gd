extends Node2D
# Cosmetic echo only. The encounter and collider end immediately as before.
var age:=0.0
var facing:=1
func _process(delta: float) -> void:
 age+=delta;modulate.a=1-smoothstep(0.35,0.85,age)
 if age>=0.85:queue_free()
 else:queue_redraw()
func _draw() -> void:
 var t:=smoothstep(0,0.45,age)
 var pose:Dictionary=preload("res://scripts/visuals/andrew_pose.gd").sample("stunned",age,0.85,0,0)
 pose.front_hand=Vector2(28,-12).lerp(Vector2(31,-4),t);pose.back_hand=Vector2(-26,-14).lerp(Vector2(-29,-3),t)
 pose.front_elbow=Vector2(26,-26).lerp(Vector2(31,-20),t);pose.back_elbow=Vector2(-25,-29).lerp(Vector2(-29,-22),t)
 pose.front_foot=Vector2(10,0).lerp(Vector2(22,0),t);pose.back_foot=Vector2(-10,0).lerp(Vector2(-18,0),t)
 draw_set_transform(Vector2.ZERO,0,Vector2(facing,lerpf(1,0.55,t)))
 preload("res://scripts/visuals/andrew_art.gd").draw_body(self,pose,"death",0,0)
 draw_set_transform_matrix(Transform2D.IDENTITY)
func _draw_arm(a: Vector2,b: Vector2,c: Vector2,color: Color) -> void:preload("res://scripts/visuals/andrew_rig.gd").arm(self,a,b,c,color)
func _draw_leg(a: Vector2,c: Vector2,color: Color) -> void:
 var b:=a.lerp(c,0.5)+Vector2(4,-1)
 draw_line(a,b,color,8);draw_line(b,c,color,8)
 preload("res://scripts/visuals/andrew_rig.gd").cap(self,b,4,color)
 draw_rect(Rect2(c-Vector2(4,3),Vector2(10,3)),Color("293b46"))
