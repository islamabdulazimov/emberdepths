extends RefCounted
# Render-only clock. Forecast at most one simulation step; never changes an action.
var tag := ""
var observed := -1.0
var time := 0.0
func advance(value: String, elapsed: float, delta: float, duration: float) -> float:
 var step := 1.0/float(Engine.physics_ticks_per_second)
 if tag != value or elapsed < observed-0.0001:
  tag = value
  time = elapsed
 else:
  time = maxf(time,elapsed)
 time = minf(time+maxf(0,delta),elapsed+step)
 observed = elapsed
 return clampf(time,0,maxf(0,duration))
