extends CharacterBody2D
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
 swing_unarmed = unarmed
 swing_remaining = 0.24
 swing_direction = direction
 facing = 1 if direction.x >= 0 else -1
 queue_redraw()

func _process(delta: float) -> void:
 if swing_remaining > 0.0:
  swing_remaining = maxf(0.0, swing_remaining - delta)
  queue_redraw()

func _draw() -> void:
 if dead:
  return
 var stride := sin(elapsed * 16.0) * 2.0 if is_on_floor() and absf(velocity.x) > 5 else 0.0
 draw_rect(Rect2(-5, -8, 10, 12), Color("d6aa86") if unclothed else Color("456b77"))
 draw_rect(Rect2(-5, -8, 10, 3), Color("d6aa86") if unclothed else Color("82aca4"))
 draw_rect(Rect2(-4, -17, 8, 9), Color("d6aa86"))
 if not unclothed:
  draw_rect(Rect2(-5, -19, 10, 4), Color("39394d"))
 draw_rect(Rect2(facing * 2, -13, 2, 2), Color("202b3c"))
 if unclothed:
  draw_rect(Rect2(-5, 1, 10, 4), Color("303c52"))
 draw_rect(Rect2(-4, 4, 3, 6 + stride), Color("d6aa86") if unclothed else Color("303c52"))
 draw_rect(Rect2(1, 4, 3, 6 - stride), Color("d6aa86") if unclothed else Color("303c52"))

 if hurt_immunity > 0 and int(elapsed * 12) % 2 == 0:
  draw_arc(Vector2(0, -4), 18, 0, TAU, 20, Color(0.9, 0.8, 0.65, 0.45), 1)
 if swing_remaining > 0.0:
  var angle := swing_direction.angle() + lerpf(-1.15, 1.15, 1.0 - swing_remaining / 0.24)
  var hand := Vector2(0, -5)
  var tip := hand + Vector2.from_angle(angle) * 24.0
  if swing_unarmed:
   draw_rect(Rect2(hand + Vector2.from_angle(angle) * 12 - Vector2(2, 2), Vector2(5, 5)), Color("e5bc96"))
   return
  draw_arc(hand, 24.0, angle - 0.5, angle, 12, Color(0.95, 0.87, 0.64, 0.45), 2.0)
  draw_line(hand, tip, Color("b9ccce"), 3.0)
  draw_line(hand, hand + Vector2.from_angle(angle) * 5.0, Color("a88158"), 4.0)
