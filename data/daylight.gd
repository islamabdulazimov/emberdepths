extends RefCounted
const Rules = preload("res://data/combat_rules.gd")

# All sky and surface lighting sample the existing saved, host-owned world clock.
static func sample(world_time: float) -> Dictionary:
 var phase := fposmod(world_time, Rules.CYCLE_SECONDS)
 var night := smoothstep(Rules.DAY_SECONDS - 15, Rules.DAY_SECONDS + 5, phase) * (1.0 - smoothstep(Rules.CYCLE_SECONDS - 15, Rules.CYCLE_SECONDS, phase))
 var sunset := smoothstep(Rules.DAY_SECONDS - 35, Rules.DAY_SECONDS - 10, phase) * (1.0 - smoothstep(Rules.DAY_SECONDS, Rules.DAY_SECONDS + 15, phase))
 var dawn := smoothstep(Rules.CYCLE_SECONDS - 15, Rules.CYCLE_SECONDS, phase) if phase > Rules.DAY_SECONDS else 1.0 - smoothstep(0.0, 20.0, phase)
 var warmth := maxf(sunset, dawn)
 return {"phase": phase, "night": night,
  "top": Color("789da6").lerp(Color("131e32"), night).lerp(Color("9a788b"), warmth * 0.5),
  "horizon": Color("c8cdb8").lerp(Color("34445f"), night).lerp(Color("e7a87b"), warmth * 0.85),
  "ambient": Color("eef1e4").lerp(Color("39455e"), night).lerp(Color("f1d5b6"), warmth * 0.18),
  "sun_progress": clampf(phase / Rules.DAY_SECONDS, 0, 1),
  "sun_alpha": (1.0 - smoothstep(Rules.DAY_SECONDS - 2, Rules.DAY_SECONDS, phase)) * smoothstep(0, 2, phase),
  "moon_progress": clampf((phase - Rules.DAY_SECONDS) / Rules.NIGHT_SECONDS, 0, 1),
  "moon_alpha": smoothstep(Rules.DAY_SECONDS, Rules.DAY_SECONDS + 3, phase) * (1.0 - smoothstep(Rules.CYCLE_SECONDS - 3, Rules.CYCLE_SECONDS, phase)),
  "stars": smoothstep(0.0, 1.0, night)}

static func orbit(progress: float, size: Vector2) -> Vector2:
 return Vector2(lerpf(size.x * 0.07, size.x * 0.93, progress), size.y * (0.72 - sin(progress * PI) * 0.33))
