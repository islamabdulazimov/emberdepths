extends RefCounted
const Art = preload("res://scripts/visuals/art_direction.gd")

static func draw_body(canvas: Node2D, pose: Dictionary, phase: String, hit: float, clock: float) -> void:
 var stone := Art.SLATE.lerp(Art.IVORY,minf(0.8,hit*5))
 var glow := Art.EMBER
 var charge := smoothstep(0,1,sin(clock*0.7)*0.5+0.5)
 if phase.ends_with("windup"): glow = glow.lerp(Color("f4ddae"),charge)
 canvas._draw_arm(Vector2(-17,-43),pose.back_elbow,pose.back_hand,stone.darkened(0.2))
 # Long ash-brown hair keeps Andrew recognisable under the new half-mask.
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12,-67),Vector2(-8,-73),Vector2(7,-72),Vector2(13,-66),Vector2(14,-41),Vector2(9,-44),Vector2(5,-39),Vector2(-4,-44),Vector2(-13,-41)]),Art.INK)
 canvas.draw_line(Vector2(-10,-63),Vector2(-10,-43),Art.COAL,3)
 canvas.draw_line(Vector2(10,-63),Vector2(11,-44),Art.COAL,3)
 canvas._draw_leg(Vector2(-10,-14),pose.back_foot,Art.SHADOW)
 canvas._draw_leg(Vector2(10,-14),pose.front_foot,stone)
 # A furnace guardian: fractured shoulders, copper bindings, porcelain visor.
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-18,-47),Vector2(-11,-53),Vector2(9,-53),Vector2(20,-45),Vector2(17,-28),Vector2(12,-15),Vector2(-13,-15),Vector2(-19,-29)]),Art.INK)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-16,-44),Vector2(-10,-50),Vector2(8,-50),Vector2(17,-43),Vector2(13,-31),Vector2(10,-18),Vector2(-11,-18),Vector2(-15,-30)]),stone)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-15,-43),Vector2(-4,-46),Vector2(-1,-37),Vector2(-8,-33),Vector2(-15,-35)]),Art.MIST.darkened(0.15))
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(3,-45),Vector2(14,-42),Vector2(13,-35),Vector2(5,-33),Vector2(1,-37)]),Art.SHADOW)
 canvas.draw_line(Vector2(-15,-32),Vector2(-2,-29),Art.INK,2)
 canvas.draw_line(Vector2(12,-32),Vector2(3,-29),Art.INK,2)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-16,-33),Vector2(-21,-25),Vector2(-19,-18),Vector2(-11,-15),Vector2(12,-15),Vector2(20,-20),Vector2(21,-25),Vector2(15,-33)]),stone)
 canvas.draw_line(Vector2(-17,-24),Vector2(-12,-19),Art.SHADOW,2)
 # Broken diamond core repeats on the hero clasp and the effect rings.
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(0,-42),Vector2(5,-36),Vector2(0,-28),Vector2(-4,-36)]),Art.INK)
 canvas.draw_line(Vector2(0,-40),Vector2(3,-36),glow,2)
 canvas.draw_line(Vector2(2,-34),Vector2(0,-30),Art.COPPER,1)
 canvas.draw_rect(Rect2(-14,-18,28,5),Art.COPPER)
 canvas.draw_rect(Rect2(-13,-18,26,1),Art.EMBER)
 var sash := sin(clock-0.6)*2
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8,-13),Vector2(9,-13),Vector2(9+sash,-1),Vector2(4+sash,-4),Vector2(-2+sash,0),Vector2(-8,-4)]),Art.COAL)
 canvas.draw_line(Vector2(4,-12),Vector2(4+sash,-5),Art.COPPER,1)
 # Broad neck and inset masked head preserve the existing boss silhouette.
 canvas.draw_rect(Rect2(-9,-57,18,9),Art.INK)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12,-67),Vector2(-7,-72),Vector2(7,-72),Vector2(13,-66),Vector2(11,-54),Vector2(5,-50),Vector2(-8,-52)]),Art.INK)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-9,-66),Vector2(-5,-69),Vector2(6,-69),Vector2(10,-65),Vector2(8,-55),Vector2(3,-53),Vector2(-7,-55)]),Art.IVORY.darkened(0.08))
 canvas.draw_rect(Rect2(-9,-65,6,9),Art.COAL)
 canvas.draw_rect(Rect2(0,-59,7,4),Color("cda88d"))
 canvas.draw_rect(Rect2(1,-64,9,3),Art.INK)
 canvas.draw_rect(Rect2(3,-63,6,1),glow)
 canvas.draw_line(Vector2(0,-69),Vector2(-1,-61),Art.SHADOW,1)
 canvas.draw_line(Vector2(-1,-61),Vector2(3,-58),Art.SHADOW,1)
 canvas.draw_rect(Rect2(2,-55,5,2),Art.COPPER)
 for side in [-1,1]:
  var shoulder := Vector2(side*17,-44)
  canvas.draw_rect(Rect2(shoulder-Vector2(6,4),Vector2(12,6)),Art.COPPER)
  canvas.draw_rect(Rect2(shoulder-Vector2(5,4),Vector2(10,1)),Art.EMBER)
 canvas._draw_arm(Vector2(17,-43),pose.front_elbow,pose.front_hand,stone)
 for hand in [pose.back_hand,pose.front_hand]:
  canvas.draw_rect(Rect2(Vector2(hand).round()-Vector2(5,4),Vector2(10,8)),Art.INK)
  canvas.draw_rect(Rect2(Vector2(hand).round()-Vector2(4,3),Vector2(8,6)),Art.COPPER)
  canvas.draw_rect(Rect2(Vector2(hand).round()-Vector2(3,3),Vector2(6,2)),glow)
