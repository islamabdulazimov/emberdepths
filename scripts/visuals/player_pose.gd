extends RefCounted
# Visual feet stay planted during the support half of each stride.
static func foot(phase: float, side: float, weight: float) -> Vector2:
 var t := fposmod(phase/TAU,1.0)
 var x := lerpf(5,-5,t/0.55) if t < 0.55 else lerpf(-5,5,smoothstep(0.55,1,t))
 var lift := 0.0 if t < 0.55 else sin((t-0.55)/0.45*PI)*5
 return Vector2(side*2+x*weight,10-lift*weight)

static func sample(clock: float, speed: float, vertical_speed: float, grounded: bool, landing: float) -> Dictionary:
 var weight := smoothstep(0,85,absf(speed))
 var step := sin(clock)
 var p := {"offset":Vector2(0,-absf(cos(clock))*weight*0.7),"scale":Vector2(1+landing*0.09,1-landing*0.12),"lean":speed/115.0*0.055,
  "front_foot":foot(clock,1,weight),"back_foot":foot(clock+PI,-1,weight),
  "front_hand":Vector2(6-step*weight*3,1+cos(clock)*weight),"back_hand":Vector2(-5+step*weight*3,0),
  "head":Vector2(-step*weight*0.35,cos(clock*0.5)*0.25),"cloth":sin(clock-0.7)*weight*2.5+sin(clock*0.65)*0.6}
 if not grounded:
  p.offset = Vector2.ZERO
  p.scale = Vector2(0.98,1.02)
  p.cloth = 2.5 if vertical_speed < 0 else -2.0
  var fall := smoothstep(-70,120,vertical_speed)
  p.front_foot = Vector2(5,4).lerp(Vector2(4,10),fall)
  p.back_foot = Vector2(-4,8).lerp(Vector2(-5,6),fall)
  p.front_hand = Vector2(7,-6).lerp(Vector2(9,-9),fall)
  p.back_hand = Vector2(-7,-4).lerp(Vector2(-8,-8),fall)
 elif weight < 0.1:
  p.offset.y = sin(clock*0.55)*0.35
 return p
