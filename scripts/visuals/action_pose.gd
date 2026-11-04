extends RefCounted
const Art = preload("res://scripts/visuals/art_direction.gd")

# One complete gesture, with identical neutral endpoints. This never owns a timer.
static func sample(kind: String, progress: float, aim: Vector2, rest_hand: Vector2) -> Dictionary:
 var t := clampf(progress,0,1)
 var presence := smoothstep(0,0.18,t)*(1-smoothstep(0.65,1,t))
 var stroke := Art.stroke(t)
 var angle := aim.angle()+lerpf(-1.05,0.9,stroke)
 var hand := rest_hand
 if kind == "build":
  hand += aim.normalized()*sin(t*PI)*8
 else:
  var reach := 12.0 if kind in ["punch","blade"] else 8.0
  hand = rest_hand.lerp(Vector2(0,-5)+Vector2.from_angle(angle)*reach,presence)
 var elbow := Vector2(6,-2).lerp(Vector2(5,-4).lerp(hand,0.5)+Vector2(0,1.5),presence)
 var drive := sin(t*PI)*presence
 return {"hand":hand,"elbow":elbow,"angle":angle,"presence":presence,
  "lean":lerpf(-0.045,0.065,stroke)*presence,"offset":Vector2(aim.normalized().x*drive*0.8,-drive*0.25)}
