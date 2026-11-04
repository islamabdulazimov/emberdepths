extends RefCounted
const Art = preload("res://scripts/visuals/art_direction.gd")

static func draw_ashling(canvas: Node2D, clock: float, velocity: Vector2, flash: float, night: bool, facing_override: int = 0, anticipation: float = 0) -> void:
 var moving := smoothstep(0,30,absf(velocity.x))
 var stride := sin(clock*11)
 var airborne := absf(velocity.y) > 20
 var squash := Vector2(0.94,1.06) if airborne else Vector2(1+absf(stride)*moving*0.06,1-absf(stride)*moving*0.06)
 var facing := facing_override if facing_override != 0 else (-1 if velocity.x < -1 else 1)
 if not airborne: canvas.draw_rect(Rect2(-7,0,14,2),Color(0.07,0.10,0.13,0.3))
 canvas.draw_set_transform(Vector2(-facing*anticipation*1.5,-absf(stride)*moving),0,squash*Vector2(facing*(1+anticipation*0.1),1-anticipation*0.12))
 var color := Art.SLATE.lerp(Art.IVORY,minf(0.8,flash*5))
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8,0),Vector2(-9,-5),Vector2(-6,-12),Vector2(-3,-15),Vector2(3,-14),Vector2(7,-10),Vector2(9,-4),Vector2(7,0)]),Art.INK)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-7,-2),Vector2(-7,-7),Vector2(-3,-13),Vector2(2,-12),Vector2(6,-9),Vector2(7,-3),Vector2(3,-1)]),color)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-6,-8),Vector2(-3,-13),Vector2(-1,-12),Vector2(-3,-6),Vector2(-5,-4)]),Art.MIST.darkened(0.25))
 # Broken shell plates and a furnace slit, not a generic slime silhouette.
 canvas.draw_line(Vector2(-1,-12),Vector2(1,-8),Art.INK,2)
 canvas.draw_line(Vector2(1,-8),Vector2(-1,-3),Art.INK,2)
 var glow := Art.EMBER if night else Art.COPPER.lightened(0.18)
 canvas.draw_rect(Rect2(2,-9,5,1),glow)
 canvas.draw_rect(Rect2(3,-10,2,3),glow)
 canvas.draw_rect(Rect2(-1,-6,1,3),Art.COPPER)
 for i in range(3):
  var step := sin(clock*11+i*PI)
  var foot := Vector2(-6+i*5+step*moving*2,-maxf(0,step)*moving*2)
  canvas.draw_line(foot.round()-Vector2(0,2),foot.round()+Vector2(2,1),Art.INK,2)
 canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func draw_spirit(canvas: Node2D, clock: float, velocity: Vector2, flash: float) -> void:
 var drift := sin(clock*3)*1.3
 var facing := -1 if velocity.x < 0 else 1
 var sway := sin(clock*4+0.9)*2
 # Layered ribbons follow the head at different delays.
 for i in range(3):
  var color := Art.MIST
  color.a = 0.1+0.07*i
  var x := -velocity.x*0.025*(3-i)+sin(clock*4-i*0.7)*2
  canvas.draw_colored_polygon(PackedVector2Array([Vector2(-5+x,-9+drift),Vector2(4+x,-9+drift),Vector2(3+x+sway,3+i*3),Vector2(x+sway,1+i*3),Vector2(-3+x+sway,5+i*2)]),color)
 canvas.draw_set_transform(Vector2(0,drift),velocity.x*0.001,Vector2(facing,1))
 var color := Art.MIST.lerp(Art.IVORY,minf(1,flash*6))
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-7,-5),Vector2(-6,-12),Vector2(-2,-17),Vector2(3,-16),Vector2(7,-11),Vector2(6,-4),Vector2(3,1),Vector2(-1,-2),Vector2(-4,1)]),Art.SHADOW)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-5,-7),Vector2(-3,-14),Vector2(2,-15),Vector2(5,-11),Vector2(4,-5),Vector2(0,-2)]),color)
 canvas.draw_rect(Rect2(-1,-13,5,5),Art.IVORY)
 canvas.draw_rect(Rect2(0,-12,1,2),Art.INK)
 canvas.draw_rect(Rect2(3,-12,1,2),Art.INK)
 canvas.draw_line(Vector2(-2,-6),Vector2(2,-4),Art.COPPER,1)
 canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
