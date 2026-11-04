extends RefCounted
# Bounded secondary motion. Uses small substeps so low frame rates remain stable.
var value := 0.0
var velocity := 0.0
func advance(target: float, delta: float) -> float:
 var remaining := clampf(delta,0,0.15)
 target = clampf(target,-5,5)
 while remaining > 0.00001:
  var step := minf(remaining,1.0/120.0)
  velocity += ((target-value)*95-velocity*15)*step
  value += velocity*step
  value = clampf(value,-6,6)
  remaining -= step
 return value
