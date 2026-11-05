extends CharacterBody2D
const Battle = preload("res://data/battle.gd")
const Pose = preload("res://scripts/visuals/andrew_pose.gd")
var motion_track = preload("res://scripts/visuals/motion_track.gd").new()
var visual_facing := 1
var visual_target_facing := 1
var visual_turn_age := 0.12
var visual_turn_width := 1.0
var visual_facing_initialized := false
var visual_clock := 0.0
var visual_pose: Dictionary = {}
var visual_phase := ""
var visual_hit := 0.0
var encounter: Node2D
var state: RefCounted
var definition: Dictionary
var phase := "intro"
var phase_revision := 0
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
 phase_revision += 1
 phase_elapsed = 0
 phase_duration = duration
 indicator_active = false
 hit_targets.clear()
 impact_emitted = false
 var labels := {"intro": "вступление", "chase": "ищет дистанцию", "stunned": "оглушён", "uppercut_windup": "готовит апперкот", "uppercut_active": "апперкот", "uppercut_recovery": "восстанавливается", "backflip": "отскок", "spin_windup": "готовит вертушку", "spin_active": "вертушка", "spin_recovery": "восстанавливается", "super_windup": "готовит суператаку", "super_flight": "прыжок", "super_impact": "удар о землю", "super_recovery": "восстанавливается"}
 encounter.notice = state.boss_name + " · " + str(labels.get(value, value))
 encounter.publish()

func take_hit(damage: int, poise_damage: int) -> bool:
 if not encounter.authoritative() or not state.active or damage <= 0:
  return false
 visual_hit = 0.12
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
     if encounter.main.world.block_at(Vector2i(column,y)) != -1 or encounter.main.world.door_at(Vector2i(column,y)) != null: clear = false
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
  if not state.active or phase != {"uppercut":"uppercut_active","spin":"spin_active","super":"super_impact"}[action]: break
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
  var result: String = encounter.main.combat.receive_attack(id,amount,origin,self,true,action == "super")
  if result != "miss": hit_targets[id] = true
  if result == "hit" and action == "uppercut" and not player.dead: player.velocity.y = -220

func receive_parry() -> void:
 if not encounter.authoritative() or not state.active or phase == "stunned": return
 state.poise = maxi(0,state.poise-int(Battle.PARRY.boss_poise))
 velocity.x = 0
 if state.poise == 0:
  velocity = Vector2.ZERO
  enter_phase("stunned",definition.stun)
 elif phase == "uppercut_active": enter_phase("uppercut_recovery",definition.uppercut_recovery)
 elif phase == "spin_active": enter_phase("spin_recovery",definition.spin_recovery)
 elif phase == "super_impact": enter_phase("super_recovery",definition.super_recovery)
 encounter.publish()

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
   if not impact_emitted and phase_elapsed >= Battle.SUPER_HIT_DELAY:
    impact_emitted = true
    _damage_players("super")
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
 if encounter.main.combat_zone.active:
  var zone: Rect2i = encounter.main.combat_zone.bounds
  position.x = clampf(position.x,zone.position.x*16+20,zone.end.x*16-20)
 else: position.x = clampf(position.x,20,encounter.main.world.world_width*16-20)
 if phase == "super_flight":
  if not is_on_floor(): flight_started = true
  if is_on_floor() and (flight_started or phase_elapsed > 0.2):
   var landing := locked_target
   if position.distance_to(landing) <= 14:
    enter_phase("super_impact",Battle.SUPER_IMPACT)
    locked_target = landing
    encounter.publish()
   else:
    enter_phase("super_recovery", definition.super_recovery)
    encounter.notice = "Препятствие прервало прыжок Andrew"
    encounter.publish()
  elif phase_elapsed > 2.5:
   enter_phase("super_recovery", definition.super_recovery)
 if position.y > encounter.main.world.world_depth * 16 + 128: encounter.end_fight("fell")
 queue_redraw()

func snapshot() -> Dictionary:
 return {"state": state.snapshot(), "position": position, "velocity": velocity, "phase": phase, "phase_revision": phase_revision, "elapsed": phase_elapsed, "duration": phase_duration, "facing": facing, "target": locked_target, "indicator": indicator_active}

func apply(data: Dictionary) -> void:
 if int(data.state.health) < state.health: visual_hit = 0.12
 state.apply(data.state)
 if int(data.get("phase_revision", 0)) < phase_revision: return
 phase_revision = int(data.get("phase_revision", 0))
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
 if phase == "super_impact":
  draw_line(locked_target-global_position+Vector2(-18,-2),locked_target-global_position+Vector2(18,-2),Color("e1dec2"),3)
 if phase == "stunned":
  for i in range(3):
   draw_rect(Rect2(Vector2(sin(phase_elapsed * 5 + i * TAU / 3) * 16, -76 + cos(phase_elapsed * 5 + i * TAU / 3) * 3), Vector2(3,3)), Color("f6d68d"))
 if absf(velocity.y) < 5 and phase not in ["backflip","super_flight"]:
  draw_rect(Rect2(-18,-1,36,2),Color(0.06,0.10,0.13,0.24))
 # Transform only the artwork. World-space warning geometry above stays exact.
 var pose: Dictionary = visual_pose if not visual_pose.is_empty() else Pose.sample(phase, phase_elapsed, phase_duration, visual_clock, velocity.x)
 var turn_width: float = (0.16+0.84*absf(float(pose.turn)))*visual_turn_width
 var transform := Transform2D(float(pose.rotation) * visual_facing, Vector2.ZERO)
 var pivot := Vector2(0,-28)
 transform.origin = pivot - transform * pivot
 transform = Transform2D(float(pose.lean) * visual_facing, Vector2(pose.scale) * Vector2(visual_facing * turn_width, 1), 0, pose.offset) * transform
 draw_set_transform_matrix(transform)
 preload("res://scripts/visuals/andrew_art.gd").draw_body(self,pose,phase,visual_hit,visual_clock)
 draw_set_transform_matrix(Transform2D.IDENTITY)
 # Short motion trails are cosmetic; damage still follows the existing phase.
 if phase == "uppercut_active":
  draw_arc(Vector2(facing * 13,-39), 28, -1.3 if facing > 0 else PI-0.3, 0.3 if facing > 0 else PI+1.3, 10, Color(1,0.82,0.61,0.4),2)
 if phase == "spin_active":
  draw_arc(Vector2(0,-36), 49, visual_clock, visual_clock + PI * 0.8, 18, Color(1,0.82,0.61,0.4),2)

func _draw_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, skin: Color) -> void:
 draw_line(shoulder, elbow, Color("18252e"), 12)
 draw_line(elbow, hand, Color("18252e"), 10)
 draw_line(shoulder, elbow, skin, 10)
 draw_line(elbow, hand, skin, 8)
 draw_rect(Rect2(hand - Vector2(4,4),Vector2(8,8)),skin)
 draw_line(shoulder + Vector2(0,-2), elbow + Vector2(0,-2), skin.lightened(0.08), 2)

func _draw_leg(hip: Vector2, foot: Vector2, skin: Color) -> void:
 var knee := hip.lerp(foot,0.5) + Vector2(3,-1)
 draw_line(hip,knee,Color("18252e"),9)
 draw_line(knee,foot - Vector2(0,2),skin,7)
 draw_rect(Rect2(foot - Vector2(4,3),Vector2(10,3)),Color("293b46"))


func emit_visual(kind: String, at: Vector2) -> void:
 var main = encounter.get("main")
 if is_instance_valid(main) and is_instance_valid(main.get("effects")): main.effects.burst(kind,at)

func _process(delta: float) -> void:
 if not visual_facing_initialized:
  visual_facing = facing
  visual_target_facing = facing
  visual_facing_initialized = true
 if facing != visual_target_facing:
  visual_target_facing = facing
  visual_turn_age = 0
 visual_turn_age = minf(0.12,visual_turn_age+delta)
 if visual_turn_age >= 0.06: visual_facing = visual_target_facing
 visual_turn_width = 1-sin(visual_turn_age/0.12*PI)*0.65
 if visual_phase != phase:
  if phase == "super_impact": emit_visual("impact",position)
  elif phase == "intro": emit_visual("respawn",position+Vector2(0,-35))
  elif phase == "super_flight": emit_visual("land",position)
  visual_phase = phase
 visual_clock += delta * (2.0 + absf(velocity.x) * 0.13)
 visual_hit = maxf(0, visual_hit - delta)
 var render_time: float = motion_track.advance(phase,phase_elapsed,delta,phase_duration)
 var target_pose := Pose.sample(phase,render_time,phase_duration,visual_clock,velocity.x)
 if visual_pose.is_empty(): visual_pose = target_pose
 else:
  var blend := 1.0 - exp(-28.0 * delta)
  for key in target_pose:
   # Rotations complete exactly one revolution, without interpolating across TAU.
   if key in ["rotation", "turn"]: visual_pose[key] = target_pose[key]
   elif target_pose[key] is Vector2: visual_pose[key] = Vector2(visual_pose[key]).lerp(target_pose[key], blend)
   else: visual_pose[key] = lerpf(float(visual_pose[key]), float(target_pose[key]), blend)
 if not encounter.authoritative():
  position = position.lerp(remote_target, minf(1, delta * 22))
  phase_elapsed += delta
 queue_redraw()
