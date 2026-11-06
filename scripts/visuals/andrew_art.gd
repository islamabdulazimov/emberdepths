extends RefCounted
const Art = preload("res://scripts/visuals/art_direction.gd")
const Rig = preload("res://scripts/visuals/andrew_rig.gd")
const SKIN := Color("d6b197")
const SHADE := Color("a77e6e")
const DEEP := Color("785b57")
const LIGHT := Color("efd0af")
const HAIR := Color("49393b")
const INK := Color("302c34")

static func draw_body(canvas: Node2D, pose: Dictionary, _phase: String, hit: float, clock: float) -> void:
 var skin := SKIN.lerp(LIGHT,minf(0.7,hit*5))
 var rear := float(pose.turn) < 0
 # Back hair and rear arm precede the torso; the complete front arm follows it.
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12,-68),Vector2(-8,-74),Vector2(8,-73),Vector2(13,-67),Vector2(15,-42),Vector2(9,-45),Vector2(5,-39),Vector2(-4,-43),Vector2(-14,-40)]),INK)
 canvas._draw_arm(Vector2(-17,-43),pose.back_elbow,pose.back_hand,SHADE)
 canvas._draw_leg(Vector2(-10,-14),pose.back_foot,DEEP)
 canvas._draw_leg(Vector2(10,-14),pose.front_foot,skin)
 # Continuous chest, broad waist and rounded belly, rather than tiled armour.
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-19,-47),Vector2(-12,-53),Vector2(-7,-54),Vector2(8,-54),Vector2(17,-49),Vector2(22,-43),Vector2(20,-35),Vector2(24,-28),Vector2(25,-23),Vector2(22,-16),Vector2(13,-12),Vector2(-12,-12),Vector2(-22,-16),Vector2(-25,-23),Vector2(-23,-31),Vector2(-20,-36),Vector2(-23,-43)]),INK)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-19,-44),Vector2(-11,-51),Vector2(8,-51),Vector2(19,-44),Vector2(17,-35),Vector2(22,-28),Vector2(23,-22),Vector2(20,-17),Vector2(11,-14),Vector2(-11,-14),Vector2(-20,-18),Vector2(-23,-24),Vector2(-20,-33),Vector2(-18,-36)]),skin)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-18,-43),Vector2(-11,-49),Vector2(-3,-48),Vector2(-2,-39),Vector2(-8,-35),Vector2(-17,-36)]),LIGHT)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(1,-48),Vector2(11,-48),Vector2(18,-42),Vector2(15,-36),Vector2(6,-35),Vector2(1,-39)]),SKIN.lightened(0.07))
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-20,-32),Vector2(-13,-35),Vector2(-17,-28),Vector2(-17,-22),Vector2(-12,-17),Vector2(-20,-19),Vector2(-23,-25)]),SHADE)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(16,-33),Vector2(22,-27),Vector2(23,-22),Vector2(19,-18),Vector2(10,-15),Vector2(15,-22)]),SHADE)
 canvas.draw_line(Vector2(-16,-35),Vector2(-5,-33),DEEP,1)
 canvas.draw_line(Vector2(5,-33),Vector2(16,-35),DEEP,1)
 canvas.draw_line(Vector2(-1,-46),Vector2(0,-37),SHADE,1)
 canvas.draw_line(Vector2(-5,-19),Vector2(6,-19),SHADE,1)
 canvas.draw_rect(Rect2(0,-24,2,2),DEEP)
 if rear:
  canvas.draw_line(Vector2(0,-49),Vector2(0,-20),SHADE,2)
  canvas.draw_line(Vector2(-13,-43),Vector2(-3,-36),DEEP,2)
  canvas.draw_line(Vector2(13,-43),Vector2(3,-36),DEEP,2)
 # A worn belt and weighted cloth remain attached around the belly.
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-19,-17),Vector2(-9,-14),Vector2(10,-14),Vector2(20,-18),Vector2(18,-12),Vector2(9,-10),Vector2(-10,-10),Vector2(-18,-13)]),Art.COAL)
 canvas.draw_line(Vector2(-17,-14),Vector2(17,-14),Art.COPPER,2)
 canvas.draw_rect(Rect2(-3,-15,6,5),Art.COPPER)
 canvas.draw_rect(Rect2(-1,-14,2,3),Art.INK)
 var sway := sin(clock-0.6)*1.5
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-10,-11),Vector2(11,-11),Vector2(10+sway,-1),Vector2(5+sway,-3),Vector2(-2+sway,0),Vector2(-10,-3)]),Art.COAL)
 # Visible neck, long hair and an angular human jaw. No borrowed mask/symbol.
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-7,-59),Vector2(7,-59),Vector2(10,-49),Vector2(-10,-49)]),SHADE)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-11,-67),Vector2(-7,-73),Vector2(7,-73),Vector2(13,-67),Vector2(12,-56),Vector2(8,-51),Vector2(-6,-51),Vector2(-12,-56)]),INK)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8,-66),Vector2(-5,-70),Vector2(6,-70),Vector2(10,-66),Vector2(10,-56),Vector2(6,-53),Vector2(-5,-53),Vector2(-9,-57)]),skin)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8,-65),Vector2(-4,-68),Vector2(-3,-56),Vector2(1,-53),Vector2(-5,-53),Vector2(-9,-57)]),SHADE)
 if rear:
  canvas.draw_colored_polygon(PackedVector2Array([Vector2(-9,-69),Vector2(8,-70),Vector2(11,-64),Vector2(11,-44),Vector2(5,-47),Vector2(1,-43),Vector2(-8,-47),Vector2(-11,-59)]),HAIR)
 else:
  canvas.draw_colored_polygon(PackedVector2Array([Vector2(-10,-64),Vector2(-9,-70),Vector2(-5,-73),Vector2(7,-72),Vector2(11,-67),Vector2(7,-68),Vector2(2,-69),Vector2(-3,-67),Vector2(-5,-60),Vector2(-5,-47),Vector2(-11,-44)]),HAIR)
  canvas.draw_line(Vector2(-8,-66),Vector2(-8,-48),DEEP,2)
  canvas.draw_line(Vector2(10,-65),Vector2(12,-45),HAIR,3)
  canvas.draw_line(Vector2(-2,-64),Vector2(2,-65),DEEP,2)
  canvas.draw_line(Vector2(5,-65),Vector2(9,-64),DEEP,2)
  canvas.draw_rect(Rect2(0,-63,2,1),INK)
  canvas.draw_rect(Rect2(7,-63,2,1),INK)
  canvas.draw_line(Vector2(4,-62),Vector2(5,-59),LIGHT,2)
  canvas.draw_line(Vector2(0,-56),Vector2(7,-56),DEEP,1)
  canvas.draw_line(Vector2(0,-54),Vector2(7,-54),LIGHT,1)
 canvas._draw_arm(Vector2(17,-43),pose.front_elbow,pose.front_hand,skin)
