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

func submit_command(axis: float, jump: bool) -> void:
 move_command = clampf(axis, -1.0, 1.0)
 jump_command = jump

func _physics_process(delta: float) -> void:
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

func _draw() -> void:
 var stride := sin(elapsed * 16.0) * 2.0 if is_on_floor() and absf(velocity.x) > 5 else 0.0
 draw_rect(Rect2(-5, -8, 10, 12), Color("456b77"))
 draw_rect(Rect2(-5, -8, 10, 3), Color("82aca4"))
 draw_rect(Rect2(-4, -17, 8, 9), Color("d6aa86"))
 draw_rect(Rect2(-5, -19, 10, 4), Color("39394d"))
 draw_rect(Rect2(facing * 2, -13, 2, 2), Color("202b3c"))
 draw_rect(Rect2(-4, 4, 3, 6 + stride), Color("303c52"))
 draw_rect(Rect2(1, 4, 3, 6 - stride), Color("303c52"))
