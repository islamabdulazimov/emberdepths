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
var flight_started := false
var action_history: Array[String] = []

func _ready() -> void:
 phase_duration = definition.intro
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

func start_attack(action: String, target: CharacterBody2D) -> bool:
 if not state.active or phase == "stunned" or target == null: return false
 facing = 1 if target.position.x >= position.x else -1
 action_history.append(action)
 if action == "uppercut":
  velocity.x = 0
  enter_phase("uppercut_windup", definition.uppercut_windup)
 elif action == "spin":
  velocity.x = 0
  enter_phase("spin_windup", definition.spin_windup)
 elif action == "backflip":
  enter_phase("backflip", definition.backflip_time)
  velocity = Vector2(-facing * float(definition.backflip_speed), float(definition.backflip_jump))
 elif action == "super":
  var landing: Variant = _landing_target(target)
  if landing == null or position.distance_to(landing) > 240:
   return start_attack("backflip", target)
  enter_phase("super_windup", definition.super_windup)
  locked_target = landing
  indicator_active = true
  velocity.x = 0
  encounter.publish()
 else: return false
 return true

func _landing_target(target: CharacterBody2D) -> Variant:
 var origin: Vector2i = encounter.main.world.cell_at(target.position + Vector2(0, 10))
 for offset in [0, 1, -1, 2, -2, 3, -3]:
  var x: int = origin.x + offset
  for dy in [0, 1, -1, 2, 3, 4, 5, 6, 7, 8]:
   var floor_y: int = origin.y + dy
   if x < 2 or x >= encounter.main.world.world_width - 2 or floor_y < 5 or floor_y >= encounter.main.world.world_depth: continue
   var clear := true
   for column in range(x - 1, x + 2):
    if encounter.main.world.block_at(Vector2i(column, floor_y)) == -1: clear = false
    for y in range(floor_y - 4, floor_y):
     if encounter.main.world.block_at(Vector2i(column,y)) != -1: clear = false
   if clear: return Vector2(x * 16 + 8, floor_y * 16)
 return null

func attack_rect(action: String) -> Rect2:
 if action == "uppercut":
  return Rect2(position + Vector2(8 if facing > 0 else -float(definition.uppercut_radius), -62), Vector2(float(definition.uppercut_radius) - 8, 62))
 return Rect2(locked_target + Vector2(-float(definition.super_radius), -float(definition.super_height)), Vector2(float(definition.super_radius) * 2, float(definition.super_height)))

func _damage_players(action: String) -> void:
 if not state.active or phase == "stunned": return
 if action == "uppercut" and phase != "uppercut_active": return
 if action == "spin" and phase != "spin_active": return
 if action == "super" and phase != "super_impact": return
 var origin := position + Vector2(0, -24)
 if action == "super": origin = locked_target + Vector2(0, -8)
 for player in encounter.alive_players():
  if not state.active: break
  var id := int(str(player.name))
  if hit_targets.has(id): continue
  var collider: CollisionShape2D = player.get_node("Collision")
  var area: Rect2 = collider.global_transform * collider.shape.get_rect()
  var inside := false
  if action == "spin":
   var closest := Vector2(clampf(origin.x, area.position.x, area.end.x), clampf(origin.y, area.position.y, area.end.y))
   inside = closest.distance_to(origin) <= float(definition.spin_radius)
  else:
   inside = attack_rect(action).intersects(area)
  if not inside or not encounter.main.combat.line_clear(origin, player.position + Vector2(0, -4)): continue
  var amount: int = definition[action + "_damage"]
  if encounter.main.combat.damage_player(id, amount, origin):
   hit_targets[id] = true
   if action == "uppercut" and not player.dead: player.velocity.y = -220

func _choose_attack(target: CharacterBody2D) -> void:
 var distance := position.distance_to(target.position)
 var clear: bool = encounter.main.combat.line_clear(position + Vector2(0, -29), target.position + Vector2(0, -4))
 var action: String = ["uppercut", "backflip", "spin", "super"][attack_index % 4]
 attack_index += 1
 if not clear or stuck_time > 0.8:
  action = "super" if attack_index % 2 == 0 else "backflip"
 elif distance > 95:
  action = "super" if distance < 240 else "backflip"
 start_attack(action, target)
 decision_clock = 0
 stuck_time = 0

func _physics_process(delta: float) -> void:
 if not encounter.authoritative() or not state.active: return
 phase_elapsed += delta
 if phase == "stunned":
  velocity = Vector2.ZERO
  if phase_elapsed >= phase_duration:
   state.poise = state.max_poise
   enter_phase("chase", 0)
   decision_clock = 0
  return
 var target = encounter.nearest_player(position)
 if target == null:
  encounter.end_fight("no_players")
  return
 match phase:
  "intro":
   velocity.x = 0
   if phase_elapsed >= phase_duration:
    enter_phase("chase", 0)
    decision_clock = 0
  "chase":
   facing = 1 if target.position.x >= position.x else -1
   var distance_x := absf(target.position.x - position.x)
   velocity.x = facing * float(definition.speed) if distance_x > 52 else 0.0
   decision_clock += delta
   if distance_x > 52 and position.distance_to(last_position) < 0.3:
    stuck_time += delta
   else: stuck_time = maxf(0, stuck_time - delta)
   if stuck_time > 0.35 and is_on_floor(): velocity.y = -245
   if decision_clock >= float(definition.between_attacks) and (distance_x < 75 or decision_clock >= float(definition.chase_timeout)):
    _choose_attack(target)
  "uppercut_windup":
   velocity.x = 0
   if phase_elapsed >= phase_duration: enter_phase("uppercut_active", definition.uppercut_active)
  "uppercut_active":
   velocity.x = 0
   _damage_players("uppercut")
   if state.active and phase_elapsed >= phase_duration: enter_phase("uppercut_recovery", definition.uppercut_recovery)
  "spin_windup":
   velocity.x = 0
   if phase_elapsed >= phase_duration: enter_phase("spin_active", definition.spin_active)
  "spin_active":
   velocity.x = 0
   _damage_players("spin")
   if state.active and phase_elapsed >= phase_duration: enter_phase("spin_recovery", definition.spin_recovery)
  "backflip":
   if phase_elapsed >= phase_duration and (is_on_floor() or phase_elapsed > 1.4):
    velocity.x = 0
    enter_phase("chase", 0)
    decision_clock = 0
  "super_windup":
   velocity.x = 0
   if phase_elapsed >= phase_duration:
    var landing := locked_target
    enter_phase("super_flight", definition.super_flight)
    locked_target = landing
    indicator_active = true
    flight_started = false
    var time: float = definition.super_flight
    velocity.x = (locked_target.x - position.x) / time
    velocity.y = (locked_target.y - position.y - 0.5 * float(definition.gravity) * time * time) / time
    encounter.publish()
  "super_flight":
   pass
  "super_impact":
   velocity.x = 0
   if phase_elapsed >= phase_duration: enter_phase("super_recovery", definition.super_recovery)
  "uppercut_recovery", "spin_recovery", "super_recovery":
   velocity.x = 0
   if phase_elapsed >= phase_duration:
    enter_phase("chase", 0)
    decision_clock = 0
 if not state.active: return
 velocity.y = minf(velocity.y + float(definition.gravity) * delta, 650)
 last_position = position
 move_and_slide()
 position.x = clampf(position.x, 20, encounter.main.world.world_width * 16 - 20)
 if phase == "super_flight":
  if not is_on_floor(): flight_started = true
  if is_on_floor() and (flight_started or phase_elapsed > 0.2):
   var landing := locked_target
   if position.distance_to(landing) <= 14:
    enter_phase("super_impact", 0.12)
    locked_target = landing
    _damage_players("super")
    impact_emitted = true
    encounter.publish()
   else:
    enter_phase("super_recovery", definition.super_recovery)
    encounter.notice = "Препятствие прервало прыжок Andrew"
  elif phase_elapsed > 2.5:
   enter_phase("super_recovery", definition.super_recovery)
 if position.y > encounter.main.world.world_depth * 16 + 128: encounter.end_fight("fell")
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
 # Indicators use the exact same geometry as damage checks.
 if phase in ["uppercut_windup", "uppercut_active"]:
  var zone := attack_rect("uppercut")
  zone.position -= global_position
  draw_rect(zone, Color(1, 0.65, 0.3, 0.13))
  draw_rect(zone, Color("e5a76d"), false, 1)
 if phase in ["spin_windup", "spin_active"]:
  draw_circle(Vector2(0,-24), float(definition.spin_radius), Color(1,0.55,0.4,0.10))
  draw_arc(Vector2(0,-24), float(definition.spin_radius), 0, TAU, 40, Color("eea083"), 1)
 if indicator_active or phase == "super_impact":
  var zone := attack_rect("super")
  zone.position -= global_position
  draw_rect(zone, Color(1,0.12,0.13,0.2))
  draw_rect(zone, Color("ff6166"), false, 2)
  draw_line(locked_target - global_position - Vector2(float(definition.super_radius), 0), locked_target - global_position + Vector2(float(definition.super_radius), 0), Color("ff5158"), 3)
 var angle := 0.0
 if phase == "spin_active": angle = facing * TAU * clampf(phase_elapsed / phase_duration, 0, 1)
 if phase == "backflip": angle = -facing * TAU * clampf(phase_elapsed / phase_duration, 0, 1)
 var transform := Transform2D(angle, Vector2.ZERO)
 var pivot := Vector2(0,-28)
 transform.origin = pivot - transform * pivot
 draw_set_transform_matrix(transform)
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
  var hand := Vector2(side * (27 if pose else 23), -61 if pose else (-70 if phase == "uppercut_active" and side == facing else -16))
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
