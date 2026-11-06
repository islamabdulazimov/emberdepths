extends Node2D
# Cosmetic echo only. The encounter and collider end immediately as before.
var age:=0.0
var facing:=1
func _process(delta: float) -> void:
 age+=delta;modulate.a=1-smoothstep(0.35,0.85,age)
 if age>=0.85:queue_free()
 else:queue_redraw()
func _draw() -> void:
 draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
 draw_texture_rect_region(preload("res://assets/recast/andrew.png"),Rect2(-64,-112,128,128),Rect2(clampi(int(age/0.85*12),0,11)*128,15*128,128,128))
 draw_set_transform_matrix(Transform2D.IDENTITY)
func _draw_arm(a: Vector2,b: Vector2,c: Vector2,color: Color) -> void:preload("res://scripts/visuals/andrew_rig.gd").arm(self,a,b,c,color)
func _draw_leg(a: Vector2,c: Vector2,color: Color) -> void:
 var b:=a.lerp(c,0.5)+Vector2(4,-1)
 draw_line(a,b,color,8);draw_line(b,c,color,8)
 preload("res://scripts/visuals/andrew_rig.gd").cap(self,b,4,color)
 draw_rect(Rect2(c-Vector2(4,3),Vector2(10,3)),Color("293b46"))
