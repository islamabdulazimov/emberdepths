extends CharacterBody2D
const Pose = preload("res://scripts/visuals/player_pose.gd")
var visual_clock := 0.0
var visual_landing := 0.0
var visual_grounded := false
var visual_fall_speed := 0.0
var visual_pose: Dictionary = {}
# The host will simulate movement. Input is a separate command boundary so
# remote commands can use the same path once the network stage is implemented.
const SPEED := 115.0
const JUMP_SPEED := -290.0
const GRAVITY := 850.0
var move_command: float = 0.0
var jump_command: bool = false
var facing := 1
var elapsed := 0.0
var swing_remaining := 0.0
var swing_direction := Vector2.RIGHT
var swing_unarmed := false
var swing_tool := false
var profile_id := ""
var resources = preload("res://scripts/player_resources.gd").new()
var resource_sync := 0.0
var health: int:
 get: return resources.health
 set(value): resources.health = clampi(value, 0, resources.max_health)
var dead := false
var unclothed := false
var hurt_immunity := 0.0
var respawn_remaining := 0.0
var since_hurt := 0.0
var regen_fraction := 0.0
var knockback_remaining := 0.0
var life_revision := 0
var last_chest_position := Vector2(-1, -1)

func submit_command(axis: float, jump: bool) -> void:
 move_command = clampf(axis, -1.0, 1.0)
 jump_command = jump

func _physics_process(delta: float) -> void:
 if dead:
  velocity = Vector2.ZERO
  return
 knockback_remaining = maxf(0.0, knockback_remaining - delta)
 if knockback_remaining <= 0:
  velocity.x = move_toward(velocity.x, move_command * SPEED, 1000.0 * delta)
 if not is_on_floor():
  velocity.y = minf(velocity.y + GRAVITY * delta, 600.0)
 if jump_command and is_on_floor():
  velocity.y = JUMP_SPEED
 jump_command = false
 if move_command != 0:
  facing = 1 if move_command > 0 else -1
 move_and_slide()
 elapsed += delta
 queue_redraw()

func play_swing(direction: Vector2, unarmed: bool = false) -> void:
 swing_tool = false
 swing_unarmed = unarmed
 swing_remaining = 0.24
 swing_direction = direction
 facing = 1 if direction.x >= 0 else -1
 queue_redraw()

func play_tool_swing(direction: Vector2) -> void:
 play_swing(direction)
 swing_tool = true

func _process(delta: float) -> void:
 # Remote bodies do not run local physics; use replicated velocity for their gait.
 var grounded := is_on_floor() if is_physics_processing() else absf(velocity.y) < 5.0
 if grounded and not visual_grounded and visual_fall_speed > 70:
  visual_landing = clampf(visual_fall_speed / 350.0, 0, 1)
 visual_landing = move_toward(visual_landing, 0, delta * 6)
 visual_fall_speed = velocity.y
 visual_grounded = grounded
 if not dead:
  visual_clock += delta * (2.0 + absf(velocity.x) * 0.12)
  var target_pose := Pose.sample(visual_clock, velocity.x, velocity.y, grounded, visual_landing)
  if visual_pose.is_empty(): visual_pose = target_pose
  else:
   var blend := 1.0 - exp(-22.0 * delta)
   for key in target_pose:
    if target_pose[key] is Vector2: visual_pose[key] = Vector2(visual_pose[key]).lerp(target_pose[key], blend)
    else: visual_pose[key] = lerpf(float(visual_pose[key]), float(target_pose[key]), blend)
  queue_redraw()
 if swing_remaining > 0.0:
  swing_remaining = maxf(0.0, swing_remaining - delta)
  queue_redraw()

func _draw() -> void:
 if dead:
  return
 var pose: Dictionary = visual_pose if not visual_pose.is_empty() else Pose.sample(visual_clock,velocity.x,velocity.y,is_on_floor(),0)
 var skin := Color("d6aa86")
 var dark := Color("283341")
 var shirt := skin if unclothed else Color("456b77")
 var pants := skin if unclothed else Color("303c52")
 # Root at the feet keeps landing compression from sliding them through the floor.
 var transform := Transform2D(float(pose.lean), Vector2(pose.scale),0,Vector2(pose.offset) + Vector2(0,10) - Vector2(0,10) * Vector2(pose.scale))
 draw_set_transform_matrix(transform)
 _draw_limb(Vector2(-4,-5),Vector2(-6,-2),pose.back_hand,skin.darkened(0.18),3)
 _draw_limb(Vector2(-3,3),Vector2(-4,6),pose.back_foot,pants.darkened(0.15),3)
 _draw_limb(Vector2(3,3),Vector2(4,6),pose.front_foot,pants,3)
 draw_rect(Rect2(Vector2(pose.back_foot).round() + Vector2(-2,-1),Vector2(4,2)),dark)
 draw_rect(Rect2(Vector2(pose.front_foot).round() + Vector2(-2,-1),Vector2(4,2)),dark)
 draw_rect(Rect2(-5,-8,10,12),shirt)
 draw_rect(Rect2(-5,-8,10,3),skin if unclothed else Color("82aca4"))
 draw_rect(Rect2(-4,-17,8,9),skin)
 draw_rect(Rect2(-4,-17,2,8),Color("ae7b67"))
 draw_rect(Rect2(-4,-18,8,3),Color("54404a"))
 if not unclothed:
  draw_rect(Rect2(-5,-19,10,4),Color("39394d"))
  draw_rect(Rect2(-5,-19,10,1),Color("697185"))
 draw_rect(Rect2(facing * 2,-13,2,2),Color("202b3c"))
 if unclothed: draw_rect(Rect2(-5,1,10,4),Color("303c52"))
 var hand: Vector2 = pose.front_hand
 if swing_remaining > 0:
  var progress := 1.0 - swing_remaining / 0.24
  var stroke := 1.0 - pow(1.0 - progress,3)
  var angle := swing_direction.angle() + lerpf(-0.5,1.05,stroke) * facing
  hand = Vector2(0,-5) + Vector2.from_angle(angle) * (13.0 if swing_unarmed else 8.0)
  var shoulder := Vector2(facing * 4,-6)
  _draw_limb(shoulder,shoulder.lerp(hand,0.5) + Vector2(0,2),hand,skin,3)
  if swing_unarmed:
   draw_rect(Rect2(hand.round()-Vector2(2,2),Vector2(5,5)),skin.lightened(0.1))
  else:
   var pivot := Vector2(0,-5)
   var tip := pivot + Vector2.from_angle(angle) * 24
   draw_arc(pivot,24,angle - 0.4 * facing,angle,10,Color(0.95,0.87,0.64,0.4 * (1-progress)),2)
   if swing_tool:
    var along := Vector2.from_angle(angle)
    var normal := along.orthogonal()
    draw_line(hand,tip,Color("a88158"),3)
    draw_colored_polygon(PackedVector2Array([tip - along * 6,tip + along * 3,tip + along * 4 + normal * 9,tip - along * 5 + normal * 8]),Color("9fb3ba"))
    draw_line(tip + along * 4 + normal * 3,tip + along * 4 + normal * 9,Color("d5e6d6"),2)
   else:
    draw_line(hand,tip,Color("283341"),4)
    draw_line(hand,tip,Color("c4dcdb"),2)
    draw_line(hand,hand - Vector2.from_angle(angle) * 4,Color("a88158"),3)
 else:
  _draw_limb(Vector2(4,-5),Vector2(6,-2),hand,skin,3)
 draw_set_transform_matrix(Transform2D.IDENTITY)
 if hurt_immunity > 0 and int(elapsed * 12) % 2 == 0:
  draw_arc(Vector2(0,-4),18,0,TAU,20,Color(0.9,0.8,0.65,0.45),1)

func _draw_limb(start: Vector2, joint: Vector2, end: Vector2, color: Color, width: float) -> void:
 draw_line(start.round(),joint.round(),color,width)
 draw_line(joint.round(),end.round(),color,width)
