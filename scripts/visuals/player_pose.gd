extends RefCounted
static func smoother(t: float) -> float:
 t = clampf(t,0,1)
 return t*t*t*(t*(t*6-15)+10)

# Support moves evenly backwards, the returning foot clears the floor with a
# zero-velocity lift at both ends. Hermite tangents join the next planted stride.
static func foot(phase: float, side: float, weight: float) -> Vector2:
 var t := fposmod(phase/TAU,1.0)
 var x := lerpf(6,-6,t/0.55)
 var lift := 0.0
 if t >= 0.55:
  var u := (t-0.55)/0.45
  var tangent := -12.0*0.45/0.55
  x = (2*u*u*u-3*u*u+1)*-6+(u*u*u-2*u*u+u)*tangent+(-2*u*u*u+3*u*u)*6+(u*u*u-u*u)*tangent
  lift = pow(sin(u*PI),2)*5
 return Vector2(side*2+x*weight,10-lift*weight)

static func sample(clock: float, speed: float, vertical_speed: float, grounded: bool, landing: float, idle_clock: float = -1) -> Dictionary:
 if idle_clock < 0: idle_clock = clock
 var weight := smoothstep(0,85,absf(speed))
 var step := sin(clock)
 var breath := sin(idle_clock*2.1)
 var p := {"offset":Vector2(0,-pow(sin(clock),2)*weight*0.8+breath*(1-weight)*0.35),"scale":Vector2(1+landing*0.09,1-landing*0.12),"lean":speed/115.0*0.055,
  "front_foot":foot(clock,1,weight),"back_foot":foot(clock+PI,-1,weight),
  "front_hand":Vector2(6-step*weight*3,1+cos(clock)*weight+breath*0.3),"back_hand":Vector2(-5+step*weight*3,breath*0.25),
  "head":Vector2(-step*weight*0.35,-breath*0.3),"cloth":sin(clock-0.7)*weight*2.5+sin(idle_clock*1.3)*0.6}
 if grounded:
  p.front_foot.y -= p.offset.y/p.scale.y
  p.back_foot.y -= p.offset.y/p.scale.y
 if not grounded:
  p.offset = Vector2.ZERO
  p.scale = Vector2(0.98,1.02)
  p.cloth = 2.5 if vertical_speed < 0 else -2.0
  var fall := smoother(inverse_lerp(-70,120,vertical_speed))
  p.front_foot = Vector2(5,4).lerp(Vector2(4,10),fall)
  p.back_foot = Vector2(-4,8).lerp(Vector2(-5,6),fall)
  p.front_hand = Vector2(7,-6).lerp(Vector2(9,-9),fall)
  p.back_hand = Vector2(-7,-4).lerp(Vector2(-8,-8),fall)
 return p
