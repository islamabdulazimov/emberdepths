extends CharacterBody2D
var encounter: Node2D
var state: RefCounted
var definition: Dictionary
var phase := "intro"
var phase_elapsed := 0.0
var phase_duration := 2.2
var facing := 1
var locked_target := Vector2.ZERO
var indicator_active := false
var hit_targets: Dictionary = {}
var impact_emitted := false
var decision_clock := 0.0
var attack_index := 0
var stuck_time := 0.0
var last_position := Vector2.ZERO
var remote_target := Vector2.ZERO

func _ready() -> void:
 z_index = 4

func enter_phase(value: String, duration: float) -> void:
 phase = value
 phase_elapsed = 0
 phase_duration = duration
 indicator_active = false
 hit_targets.clear()
 impact_emitted = false
 encounter.publish()

func take_hit(damage: int, poise_damage: int) -> bool:
 if not encounter.authoritative() or not state.active or damage <= 0:
  return false
 state.health = maxi(0, state.health - damage)
 if state.health == 0:
  encounter.end_fight("defeated")
  return true
 if phase != "stunned":
  state.poise = maxi(0, state.poise - maxi(0, poise_damage))
  if state.poise == 0:
   velocity = Vector2.ZERO
   locked_target = Vector2.ZERO
   enter_phase("stunned", definition.stun)
 encounter.publish()
 return true

func _physics_process(delta: float) -> void:
 if not encounter.authoritative() or not state.active: return
 phase_elapsed += delta
 if phase == "stunned":
  velocity = Vector2.ZERO
  if phase_elapsed >= phase_duration:
   state.poise = state.max_poise
   enter_phase("chase", 0)
  return
 if phase == "intro":
  velocity.x = 0
  if phase_elapsed >= phase_duration: enter_phase("chase", 0)
 else:
  var target = encounter.nearest_player(position)
  if target != null:
   facing = 1 if target.position.x >= position.x else -1
   velocity.x = facing * float(definition.speed)
 velocity.y = minf(velocity.y + float(definition.gravity) * delta, 600)
 move_and_slide()
 queue_redraw()

func snapshot() -> Dictionary:
 return {"state": state.snapshot(), "position": position, "velocity": velocity, "phase": phase, "elapsed": phase_elapsed, "duration": phase_duration, "facing": facing, "target": locked_target, "indicator": indicator_active}

func apply(data: Dictionary) -> void:
 state.apply(data.state)
 position = data.position
 remote_target = position
 velocity = data.velocity
 phase = data.phase
 phase_elapsed = data.elapsed
 phase_duration = data.duration
 facing = data.facing
 locked_target = data.target
 indicator_active = data.indicator
 queue_redraw()

func _draw() -> void:
 var skin := Color("e4bba0")
 var shade := Color("c3927e")
 if phase == "super_windup": skin = Color("f17672")
 # Hair silhouette, torso, prominent belly, squared jaw and broad shoulders.
 draw_rect(Rect2(-12, -69, 24, 32), Color("705445"))
 draw_rect(Rect2(-8, -67, 16, 16), skin)
 draw_rect(Rect2(-10, -55, 20, 8), skin)
 draw_rect(Rect2(-5, -59, 3, 2), Color("38404a"))
 draw_rect(Rect2(3, -59, 3, 2), Color("38404a"))
 draw_rect(Rect2(-5, -50, 10, 2), shade)
 draw_rect(Rect2(-19, -47, 38, 20), skin)
 draw_rect(Rect2(-15, -44, 12, 8), shade)
 draw_rect(Rect2(3, -44, 12, 8), shade)
 draw_colored_polygon(PackedVector2Array([Vector2(-18,-32),Vector2(-23,-24),Vector2(-23,-14),Vector2(-16,-7),Vector2(16,-7),Vector2(23,-14),Vector2(23,-24),Vector2(18,-32)]), skin)
 draw_rect(Rect2(-1, -20, 2, 3), shade)
 var pose := phase == "intro"
 for side in [-1, 1]:
  var shoulder := Vector2(side * 18, -42)
  var elbow := Vector2(side * (31 if pose else 25), -43 if pose else -28)
  var hand := Vector2(side * (27 if pose else 23), -61 if pose else -16)
  draw_line(shoulder, elbow, skin, 10)
  draw_line(elbow, hand, skin, 9)
  draw_rect(Rect2(hand - Vector2(4, 4), Vector2(8, 8)), skin)
 draw_rect(Rect2(-17, -10, 34, 9), Color("394b58"))
 draw_rect(Rect2(-15, -1, 11, 3), skin)
 draw_rect(Rect2(4, -1, 11, 3), skin)


func _process(delta: float) -> void:
 if not encounter.authoritative():
  position = position.lerp(remote_target, minf(1, delta * 22))
  phase_elapsed += delta
 queue_redraw()
