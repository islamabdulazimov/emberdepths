extends Node2D
var appearance:Dictionary={}
var equipment:Dictionary={}
var facing:=1
var bare:=false
var age:=0.0
func _process(delta:float) -> void:
 age+=delta;modulate.a=1-smoothstep(0.35,0.65,age)
 if age>=0.65:queue_free()
 else:queue_redraw()
func _draw() -> void:
 var a:Dictionary=preload("res://data/appearance.gd").clean(appearance)
 var src:=Rect2(clampi(int(age/0.5*24),0,23)*64,13*64,64,64)
 draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
 var art=preload("res://scripts/visuals/hero_sprite.gd")
 draw_texture_rect_region(art.texture("res://assets/recast/hero_%s_%s_%d_%s.png"%[a.gender,a.hair,a.skin,"bare" if bare else "coat"]),Rect2(-32,-41,64,64),src)
 for part in ["legs","body","head"]:
  if equipment.get(part,"")!="":draw_texture_rect_region(art.texture("res://assets/recast/armor_%s.png"%part),Rect2(-32,-41,64,64),src)
 draw_set_transform_matrix(Transform2D.IDENTITY)
