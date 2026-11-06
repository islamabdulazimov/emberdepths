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
 draw_texture_rect_region(art.texture("res://assets/avatar/hair_%s_rear.png"%a.hair),Rect2(-32,-41,64,64),src,preload("res://data/appearance.gd").HAIR_COLORS[a.hair_color])
 draw_texture_rect_region(art.texture("res://assets/avatar/body_%s_%s_%d_%s.png"%[a.gender,a.build,a.skin,"plain" if bare else "coat"]),Rect2(-32,-41,64,64),src)
 draw_texture_rect_region(art.texture("res://assets/avatar/hair_%s_front.png"%a.hair),Rect2(-32,-41,64,64),src,preload("res://data/appearance.gd").HAIR_COLORS[a.hair_color])
 for part in ["legs","body","head"]:
  if equipment.get(part,"")!="":draw_texture_rect_region(art.texture("res://assets/avatar/armor_%s_%s_%s.png"%[a.gender,a.build,part]),Rect2(-32,-41,64,64),src)
 draw_texture_rect_region(art.texture("res://assets/avatar/arm_%s_%s_%d_%s.png"%[a.gender,a.build,a.skin,"plain" if bare else "coat"]),Rect2(-16,-25,36,40),Rect2(int(src.position.x/64)*36,13*40,36,40))
 draw_set_transform_matrix(Transform2D.IDENTITY)
