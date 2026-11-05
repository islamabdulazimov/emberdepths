extends RefCounted
# Stable two-link bend in artwork coordinates. No bones/nodes or physics changes.
static func joint(start: Vector2, end: Vector2, upper: float, lower: float, bend: float = 1) -> Vector2:
 var axis := end-start
 var distance := axis.length()
 if distance < 0.001: return start+Vector2(upper,0)
 var length_scale := maxf(1,distance/(upper+lower-0.001))
 upper *= length_scale
 lower *= length_scale
 var along := clampf((distance*distance+upper*upper-lower*lower)/(2*distance),0,upper)
 var height := sqrt(maxf(0,upper*upper-along*along))
 return start+axis/distance*along+Vector2(axis.y,-axis.x)/distance*height*bend
