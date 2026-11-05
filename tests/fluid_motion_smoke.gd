extends SceneTree
const Track = preload("res://scripts/visuals/motion_track.gd")
const Transition = preload("res://scripts/visuals/pose_transition.gd")
const Pose = preload("res://scripts/visuals/player_pose.gd")
const Limb = preload("res://scripts/visuals/limb_pose.gd")
const Action = preload("res://scripts/visuals/action_pose.gd")
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var track = Track.new()
 var steps: Array[float] = []
 for frame in range(12): steps.append(track.advance("attack",floori(frame/4.0)/60.0,1.0/240,0.47))
 var continuous := true
 for i in range(1,steps.size()): continuous = continuous and steps[i] > steps[i-1] and steps[i]-steps[i-1] < 0.008
 check_result(continuous,"60 Hz action samples produce distinct bounded poses on all 240 Hz frames")
 check_result(track.advance("attack",0.1,1,0.47) <= 0.1+1.0/60+0.00001,"A delayed frame cannot forecast more than one physics tick")
 check_result(track.advance("roll",0,1.0/240,0.44) < 0.005,"Changing action resets the render clock instead of inheriting elapsed attack time")
 check_result(track.advance("roll",0.3,0,0.44) >= 0.3 and track.advance("roll",0,0,0.44) == 0,"Corrections and same-action restarts reset without negative time")
 var derivatives := true
 for phase in [0.0,TAU*0.55]:
  var h := 0.0001
  var left := (Pose.foot(phase,1,1)-Pose.foot(phase-h,1,1))/h
  var right := (Pose.foot(phase+h,1,1)-Pose.foot(phase,1,1))/h
  derivatives = derivatives and left.distance_to(right) < 0.02
 check_result(derivatives,"Foot position and velocity join continuously at contact and lift-off")
 var comparison = Track.new()
 var time60 := 0.0
 for i in range(6): time60 = comparison.advance("attack",i/60.0,1.0/60,0.47)
 var comparison240 = Track.new()
 var time240 := 0.0
 for i in range(24): time240 = comparison240.advance("attack",floori(i/4.0)/60.0,1.0/240,0.47)
 check_result(absf(time60-time240) < 0.0001,"60 and 240 FPS reach the same action time after an equal simulation interval")
 var grounded_pose := Pose.sample(TAU*0.2,115,0,true,0.5,1)
 var contact_y: float = 10+(grounded_pose.front_foot.y-10)*grounded_pose.scale.y+grounded_pose.offset.y
 check_result(absf(contact_y-10) < 0.001,"Body bob and landing compression keep the supporting sole on the ground")
 var above_floor := true
 for i in range(1000): above_floor = above_floor and Pose.foot(i*TAU/1000,1,1).y <= 10.001
 check_result(above_floor,"Returning foot clears the floor rather than clipping through it")
 var joint := Limb.joint(Vector2.ZERO,Vector2(6,4),5.5,6.5)
 check_result(absf(joint.length()-5.5) < 0.001 and absf(joint.distance_to(Vector2(6,4))-6.5) < 0.001,"Arm bend preserves both segment lengths within its reach")
 check_result(Limb.joint(Vector2.ZERO,Vector2.ZERO,6,7).is_finite() and Limb.joint(Vector2.ZERO,Vector2(90,1),6,7).is_finite(),"Coincident and stretched limb targets remain finite")
 var transition = Transition.new()
 transition.sample("ground",{"hand":Vector2.ZERO},0)
 var first: Dictionary = transition.sample("air",{"hand":Vector2(10,0)},1.0/240)
 check_result(Vector2(first.hand).x < 0.1,"State transition begins from the visible pose without an immediate pop")
 for i in range(24): transition.sample("air",{"hand":Vector2(10,0)},1.0/240)
 check_result(transition.pose.hand == Vector2(10,0),"Pose transition settles exactly instead of permanently damping the gesture")
 transition.sample("air",{"hand":Vector2(5,2)},1.0/240)
 check_result(transition.pose.hand == Vector2(5,2),"Continuous gait follows its curve with no extra smoothing lag")
 var finite := true
 for i in range(241):
  var pose := Action.sample("blade",i/240.0,Vector2.RIGHT,Vector2(6,1))
  finite = finite and Vector2(pose.hand).is_finite() and Vector2(pose.elbow).is_finite() and absf(pose.lean) <= 0.13
 check_result(finite,"Stronger anticipation and follow-through remain bounded throughout the blade gesture")
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.set_physics_process(false)
 main.encounter.enabled = false
 main.items.set_physics_process(false)
 main.player.set_physics_process(false)
 var player = main.player
 var origin: Vector2 = player.position
 var captured: Dictionary = main.saves.capture()
 player.fighter.begin("roll",Vector2.RIGHT,0.44)
 var elapsed: float = player.fighter.elapsed
 for i in range(12): player._process(1.0/240)
 check_result(player.visual_roll > 0.7 and player.fighter.elapsed == elapsed,"Roll folds visually without advancing its real action or invulnerability")
 player.fighter.reset()
 player._process(1.0/240)
 check_result(player.visual_roll > 0 and player.visual_roll < 1,"Roll unfolds smoothly after the authoritative state ends")
 player.fighter.begin("parry",Vector2.RIGHT,0.58)
 for i in range(120): player._process(1.0/240)
 check_result(player.fighter.elapsed == 0 and not player.fighter.parry_open() and player.position == origin,"Render clock cannot open a parry window or move a collider")
 player.fighter.reset()
 check_result(main.saves.capture() == captured,"New clocks, bends and transitions remain entirely outside saved state")
 main.queue_free()
 await process_frame
 print("Fluid motion failures: ",failures)
 quit(1 if failures else 0)
