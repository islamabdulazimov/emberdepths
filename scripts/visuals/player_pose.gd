extends RefCounted
# Artwork is expressed in local pixels; the physical body never squashes.
static func sample(clock: float, speed: float, vertical_speed: float, grounded: bool, landing: float) -> Dictionary:
 var weight := clampf(absf(speed) / 115.0, 0.0, 1.0)
 var step := sin(clock)
 var p := {"offset": Vector2(0, -absf(step) * weight), "scale": Vector2(1 + landing * 0.12, 1 - landing * 0.14), "lean": speed / 115.0 * 0.07,
  "front_foot": Vector2(3 + step * weight * 4, 10 - maxf(0, step) * weight * 3), "back_foot": Vector2(-3 - step * weight * 4, 10 - maxf(0, -step) * weight * 3),
  "front_hand": Vector2(6 - step * weight * 3, 1), "back_hand": Vector2(-6 + step * weight * 3, 0)}
 if not grounded:
  p.offset = Vector2.ZERO
  p.scale = Vector2(0.97,1.03)
  if vertical_speed < -20:
   p.front_foot = Vector2(5,5)
   p.back_foot = Vector2(-4,8)
   p.front_hand = Vector2(8,-7)
   p.back_hand = Vector2(-7,-5)
  else:
   p.front_foot = Vector2(5,9)
   p.back_foot = Vector2(-5,7)
   p.front_hand = Vector2(9,-10)
   p.back_hand = Vector2(-8,-9)
 elif weight < 0.1:
  p.offset.y = sin(clock * 0.55) * 0.35
 return p
