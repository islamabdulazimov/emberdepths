extends RefCounted
# Blend only on state changes. Continuous cycles retain their amplitude and timing.
var tag := ""
var age := 1.0
var source: Dictionary = {}
var pose: Dictionary = {}
func sample(value: String, target: Dictionary, delta: float, seconds: float = 0.09) -> Dictionary:
 if pose.is_empty():
  tag = value
  pose = target.duplicate()
  return pose
 if value != tag:
  tag = value
  source = pose.duplicate()
  age = 0
 age = minf(seconds,age+maxf(0,delta))
 var t := age/maxf(seconds,0.001)
 var weight := t*t*t*(t*(t*6-15)+10)
 pose = target.duplicate()
 if weight < 1:
  for key in target:
   if not source.has(key): continue
   if target[key] is Vector2: pose[key] = Vector2(source[key]).lerp(target[key],weight)
   else: pose[key] = lerpf(float(source[key]),float(target[key]),weight)
 return pose
