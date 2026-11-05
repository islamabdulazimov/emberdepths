extends RefCounted
# Presentation only: never drives collisions, timers, hitboxes or network state.
static func sample(phase: String, elapsed: float, duration: float, clock: float, speed: float) -> Dictionary:
 var t := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
 var ease := t*t*t*(t*(t*6-15)+10)
 var walk := clampf(absf(speed) / 48.0, 0.0, 1.0) if phase == "chase" else 0.0
 var step := sin(clock)
 var weight_shift := sin(clock*2)*walk
 var p := {"offset": Vector2(0, -absf(step) * walk * 1.5 + sin(clock * 0.3) * 0.35), "scale": Vector2.ONE, "lean": step*walk*0.025, "rotation": 0.0, "turn": 1.0,
  "front_elbow": Vector2(25, -31), "front_hand": Vector2(24, -19), "back_elbow": Vector2(-25, -32), "back_hand": Vector2(-23, -20),
  "front_foot": Vector2(10 + step * walk * 7, -maxf(0, step) * walk * 4), "back_foot": Vector2(-10 - step * walk * 7, -maxf(0, -step) * walk * 4)}
 p.scale = Vector2(1+absf(weight_shift)*0.015,1-absf(weight_shift)*0.015)
 p.front_hand.x += step * walk * 6
 p.back_hand.x -= step * walk * 6
 match phase:
  "intro":
   var flex := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.8, 1.0, t))
   p.front_elbow = p.front_elbow.lerp(Vector2(32,-46), flex)
   p.back_elbow = p.back_elbow.lerp(Vector2(-32,-46), flex)
   p.front_hand = p.front_hand.lerp(Vector2(26,-63), flex)
   p.back_hand = p.back_hand.lerp(Vector2(-26,-63), flex)
   p.scale = Vector2(1 + flex * 0.035, 1 - flex * 0.015)
  "uppercut_windup":
   p.lean = -0.10 * ease
   p.offset = Vector2(-3 * ease, 4 * ease)
   p.front_elbow = Vector2(26,-32).lerp(Vector2(16,-25), ease)
   p.front_hand = Vector2(24,-19).lerp(Vector2(6,-27), ease)
   p.back_hand = Vector2(-19,-43)
  "uppercut_active":
   var strike := 1.0 - pow(1.0 - t, 3)
   p.lean = lerpf(-0.10, 0.12, strike)
   p.offset = Vector2(lerpf(-3, 4, strike), lerpf(4, -3, strike))
   p.front_elbow = Vector2(16,-25).lerp(Vector2(31,-49), strike)
   p.front_hand = Vector2(6,-27).lerp(Vector2(29,-75), strike)
   p.back_hand = Vector2(-18,-41)
  "uppercut_recovery":
   p.front_elbow = Vector2(31,-49).lerp(Vector2(25,-31), ease)
   p.front_hand = Vector2(29,-75).lerp(Vector2(24,-19), ease)
   p.offset = Vector2(4,-3).lerp(Vector2.ZERO, ease)
   p.lean = 0.12 * (1 - ease)+sin(t*PI*2)*exp(-t*4)*0.025
  "spin_windup":
   p.lean = -0.08 * ease
   p.front_hand = Vector2(24,-19).lerp(Vector2(-8,-44), ease)
   p.front_elbow = Vector2(25,-31).lerp(Vector2(19,-40), ease)
   p.back_hand = Vector2(-23,-20).lerp(Vector2(-34,-42), ease)
  "spin_active":
   # Turn around the vertical axis, rather than cartwheeling the entire body.
   p.turn = cos(t * TAU)
   var spread := smoothstep(0,0.2,t)
   p.front_elbow = Vector2(19,-40).lerp(Vector2(35,-41),spread)
   p.front_hand = Vector2(-8,-44).lerp(Vector2(53,-40),spread)
   p.back_elbow = Vector2(-25,-32).lerp(Vector2(-35,-41),spread)
   p.back_hand = Vector2(-34,-42).lerp(Vector2(-53,-40),spread)
  "spin_recovery":
   p.front_elbow = Vector2(35,-41).lerp(Vector2(25,-31), ease)
   p.front_hand = Vector2(53,-40).lerp(Vector2(24,-19), ease)
   p.back_elbow = Vector2(-35,-41).lerp(Vector2(-25,-32), ease)
   p.back_hand = Vector2(-53,-40).lerp(Vector2(-23,-20), ease)
  "backflip":
   p.rotation = -TAU * ease
   var tuck := sin(t * PI)
   p.front_hand = Vector2(24,-19).lerp(Vector2(14,-28),tuck)
   p.back_hand = Vector2(-23,-20).lerp(Vector2(-14,-28),tuck)
   p.front_foot.y -= tuck * 13
   p.back_foot.y -= tuck * 13
  "super_windup":
   p.scale = Vector2(1 + 0.08 * ease, 1 - 0.14 * ease)
   p.offset.x = sin(elapsed*25)*ease*ease*0.6
   p.front_elbow = Vector2(28,-38)
   p.back_elbow = Vector2(-28,-38)
   p.front_hand = Vector2(21,-51)
   p.back_hand = Vector2(-21,-51)
  "super_flight":
   var spread := smoothstep(0.3, 0.85, t)
   p.scale = Vector2(0.96,1.04)
   p.front_elbow = Vector2(24,-51)
   p.back_elbow = Vector2(-24,-51)
   p.front_hand = Vector2(15,-70).lerp(Vector2(27,-35), spread)
   p.back_hand = Vector2(-15,-70).lerp(Vector2(-27,-35), spread)
   p.front_foot.y = -10 * (1 - spread)
   p.back_foot.y = -10 * (1 - spread)
  "super_impact":
   p.scale = Vector2(1.12,0.82)
   p.front_hand = Vector2(27,-7)
   p.back_hand = Vector2(-27,-7)
  "super_recovery":
   var recover := smoothstep(0.0, 0.65, t)
   p.scale = Vector2(1.12,0.82).lerp(Vector2.ONE, recover)
   p.front_hand = Vector2(27,-7).lerp(Vector2(24,-19), recover)
   p.back_hand = Vector2(-27,-7).lerp(Vector2(-23,-20), recover)
  "stunned":
   p.lean = 0.13
   p.offset = Vector2(sin(elapsed * 16) * exp(-elapsed * 6) * 3, 3)
   p.front_hand = Vector2(28,-12)
   p.back_hand = Vector2(-26,-14)
 return p
