extends RefCounted
const Ease = preload("res://scripts/visuals/player_pose.gd")
const Limb = preload("res://scripts/visuals/limb_pose.gd")

# Preparation [0,.4], contact [.4,.65], follow-through [.65,1]. The caller
# maps the authoritative weapon phases here; mining keeps its cosmetic timer.
static func sample(kind: String, progress: float, aim: Vector2, rest_hand: Vector2) -> Dictionary:
 var t := clampf(progress,0,1)
 var presence := Ease.smoother(t/0.22)*(1-Ease.smoother((t-0.72)/0.28))
 var angle_offset := -1.0
 var drive := 0.0
 var lean := 0.0
 if t < 0.4:
  var wind := Ease.smoother(t/0.4)
  angle_offset = lerpf(-0.8,-1.45,wind)
  lean = -0.08*wind
  drive = -0.8*wind
 elif t < 0.65:
  var strike := Ease.smoother((t-0.4)/0.25)
  angle_offset = lerpf(-1.45,0.45,strike)
  lean = lerpf(-0.08,0.12,strike)
  drive = lerpf(-0.8,1.6,strike)
 else:
  var release := Ease.smoother((t-0.65)/0.35)
  angle_offset = lerpf(0.45,0.3,release)
  lean = 0.12*(1-release)
  drive = 1.6*(1-release)
 var angle := aim.angle()+angle_offset
 var hand := rest_hand
 if kind == "build":
  hand += aim.normalized()*pow(sin(t*PI),2)*8
 else:
  var reach := 12.0 if kind in ["punch","blade"] else 8.0
  hand = rest_hand.lerp(Vector2(0,-5)+Vector2.from_angle(angle)*reach,presence)
 var elbow := Vector2(6,-2).lerp(Limb.joint(Vector2(4,-6),hand,6,7),presence)
 return {"hand":hand,"elbow":elbow,"angle":angle,"presence":presence,
  "lean":lean*presence,"offset":Vector2(aim.normalized().x*drive,-absf(drive)*0.2)*presence}
