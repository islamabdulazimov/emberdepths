extends CharacterBody2D
var appearance: Dictionary = preload("res://data/appearance.gd").DEFAULT.duplicate()
var fighter = preload("res://scripts/fighter_state.gd").new()
const Battle = preload("res://data/battle.gd")
const Art = preload("res://scripts/visuals/art_direction.gd")
const Action = preload("res://scripts/visuals/action_pose.gd")
const Limb = preload("res://scripts/visuals/limb_pose.gd")
var motion_track = preload("res://scripts/visuals/motion_track.gd").new()
var pose_transition = preload("res://scripts/visuals/pose_transition.gd").new()
var visual_action_time := 0.0
var visual_speed := 0.0
var visual_idle_clock := 0.0
var visual_roll := 0.0
const Pose = preload("res://scripts/visuals/player_pose.gd")
var visual_clock := 0.0
var cloth_motion = preload("res://scripts/visuals/cloth_motion.gd").new()
var visual_facing := 1
var visual_turn := 1.0
var visual_turn_age := 0.12
var visual_target_facing := 1
var visual_medicine := 0.0
var visual_landing := 0.0
var visual_grounded := false
var visual_fall_speed := 0.0
var visual_pose: Dictionary = {}
var visual_hit_direction := 1.0
var visual_hurt := 0.0
var visual_step := -1
var visual_initialized := false
var visual_was_dead := false
var visual_death_age := 1.0
var visual_alive_unclothed := false
var visual_death_unclothed := false
var visual_health := 100
var work_remaining := 0.0
var work_kind := "pick"
var work_direction := Vector2.RIGHT
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
var medicine_progress := 0.0
var medicine_cooldown := 0.0
var medicine_slot := -1 # Authoritative transient input state; never restored.
var medicine_latch := -1 # Keep a held self-use from digging after its last item.
var heal_flash_remaining := 0.0
var heal_flash_amount := 0
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
 if fighter.mode == "roll":
  velocity.x = fighter.direction.x*float(Battle.ROLL.speed)
 elif fighter.mode in ["parry","parry_success"]:
  velocity.x = move_toward(velocity.x,0,1600*delta)
 elif knockback_remaining <= 0:
  var movement_scale := 0.45 if fighter.mode == "attack" else 1.0
  velocity.x = move_toward(velocity.x,move_command*SPEED*movement_scale,1000*delta)
 if not is_on_floor():
  velocity.y = minf(velocity.y + GRAVITY * delta, 600.0)
 if jump_command and is_on_floor() and fighter.mode == "idle":
  velocity.y = JUMP_SPEED
 jump_command = false
 if move_command != 0 and fighter.mode == "idle":
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

func play_work(direction: Vector2, kind: String) -> void:
 work_direction = direction
 work_kind = kind
 work_remaining = 0.30

func emit_visual(kind: String, offset: Vector2 = Vector2.ZERO, direction: Vector2 = Vector2.UP) -> void:
 var main := get_parent().get_parent()
 var effects = main.get("effects")
 if is_instance_valid(effects): effects.burst(kind,position+offset,direction)

func show_heal(amount: int) -> void:
 emit_visual("heal",Vector2(0,-6))
 heal_flash_amount = amount
 heal_flash_remaining = 0.65
 queue_redraw()

func presentation_grounded() -> bool:
 if is_physics_processing(): return is_on_floor()
 if absf(velocity.y) >= 5: return false
 var world = get_parent().get_parent().get("world")
 if not is_instance_valid(world): return true # Standalone art review, without terrain.
 # Zero vertical speed also occurs at the apex of a remote player's jump.
 for x in [-4,0,4]:
  var cell: Vector2i = world.cell_at(position+Vector2(x,11))
  if world.block_at(cell) != -1: return true
  var door = world.door_at(cell)
  if door != null and not door.opened: return true
 return false

func _process(delta: float) -> void:
 if not visual_initialized:
  visual_facing = facing
  visual_target_facing = facing
 if facing != visual_target_facing:
  visual_target_facing = facing
  visual_turn_age = 0
 visual_turn_age = minf(0.12,visual_turn_age+delta)
 var turning := visual_turn_age/0.12
 if turning >= 0.5: visual_facing = visual_target_facing
 visual_turn = 1-sin(turning*PI)*0.72
 visual_action_time = motion_track.advance(fighter.mode,fighter.elapsed,delta,fighter.duration)
 visual_roll = lerpf(visual_roll,1.0 if fighter.mode == "roll" else 0.0,1-exp(-38*delta))
 visual_medicine = lerpf(visual_medicine,1.0 if medicine_progress > 0 and not dead else 0.0,1-exp(-20*delta))
 work_remaining = maxf(0,work_remaining-delta)
 visual_hurt = maxf(0,visual_hurt-delta)
 if visual_initialized:
  if dead and not visual_was_dead:
   visual_death_age=0
   visual_death_unclothed=visual_alive_unclothed
   emit_visual("death",Vector2(0,-5))
  elif not dead and visual_was_dead: emit_visual("respawn",Vector2(0,-5))
  elif health < visual_health:
   visual_hurt = 0.16
   visual_hit_direction = signf(velocity.x) if absf(velocity.x) > 1 else -float(facing)
   emit_visual("hurt",Vector2(0,-5),Vector2(-facing,-1))
 visual_initialized = true
 if dead:
  visual_death_age+=delta
  self_modulate.a=1-smoothstep(0.3,0.65,visual_death_age)
  queue_redraw()
 else:
  self_modulate.a=1
  visual_alive_unclothed=unclothed
 visual_was_dead = dead
 visual_health = health
 heal_flash_remaining = maxf(0, heal_flash_remaining - delta)
 # Remote bodies do not run local physics; use replicated velocity for their gait.
 var grounded := presentation_grounded()
 if grounded and not visual_grounded and visual_fall_speed > 70:
  visual_landing = clampf(visual_fall_speed / 350.0, 0, 1)
  emit_visual("land",Vector2(0,10))
 if not grounded and visual_grounded and velocity.y < -20: emit_visual("step",Vector2(0,10))
 visual_landing = move_toward(visual_landing, 0, delta * 6)
 visual_fall_speed = velocity.y
 visual_grounded = grounded
 if not dead:
  visual_idle_clock += delta
  visual_speed = lerpf(visual_speed,velocity.x,1-exp(-24*delta))
  visual_clock += delta * absf(visual_speed) * (TAU/(12.0/0.55))
  var step_index := floori(visual_clock/PI)
  if grounded and absf(velocity.x) > 30 and step_index != visual_step: emit_visual("step",Vector2(0,10),Vector2(-signf(velocity.x),-0.3))
  visual_step = step_index
  var target_pose := Pose.sample(visual_clock,visual_speed,velocity.y,grounded,visual_landing,visual_idle_clock)
  visual_pose = pose_transition.sample("ground" if grounded else "air",target_pose,delta)
  var cloth_target: float = float(target_pose.cloth)-velocity.x*visual_facing/115.0*1.5
  visual_pose.cloth = cloth_motion.advance(cloth_target,delta)
  queue_redraw()
 if swing_remaining > 0.0:
  swing_remaining = maxf(0.0, swing_remaining - delta)
  queue_redraw()

func _draw() -> void:
 if dead and visual_death_age>=0.65: return
 var bare:=visual_death_unclothed if dead else unclothed
 var pose: Dictionary = visual_pose if not visual_pose.is_empty() else Pose.sample(visual_clock,velocity.x,velocity.y,is_on_floor(),0)
 if dead:
  pose=pose.duplicate()
  var collapse:=smoothstep(0,0.4,visual_death_age)
  pose.scale=Vector2(1,lerpf(1,0.55,collapse))
  pose.offset=Vector2(0,3*collapse)
  pose.lean=0.15*collapse
  pose.front_foot=Vector2(2,10).lerp(Vector2(10,6),collapse)
  pose.back_foot=Vector2(-2,10).lerp(Vector2(-8,6),collapse)
  pose.front_hand=Vector2(pose.front_hand).lerp(Vector2(9,5),collapse)
  pose.back_hand=Vector2(pose.back_hand).lerp(Vector2(-7,4),collapse)
  pose.head=Vector2(pose.head)+Vector2(3,2)*collapse
 var skin := preload("res://data/appearance.gd").color(appearance).lerp(Art.IVORY,visual_hurt*3)
 var coat: Color = Art.JADE.darkened(0.13).lerp(Art.IVORY,visual_hurt*3)
 var trousers: Color = Art.SHADOW
 # A contact shadow should not travel through the air with the body.
 if visual_grounded: draw_rect(Rect2(-6,9,12,2),Color(0.06,0.10,0.13,0.24))
 var action: Dictionary = {}
 var action_kind := ""
 var action_progress := 0.0
 if fighter.mode == "attack" or swing_remaining > 0 or work_remaining > 0:
  var fighting := swing_remaining > 0
  action_progress = 1.0-swing_remaining/0.24 if fighting else 1.0-work_remaining/0.30
  if fighter.mode == "attack":
   fighting = true
   var t: float = visual_action_time
   if t < Battle.BLADE.windup: action_progress = t/Battle.BLADE.windup*0.40
   elif t < Battle.BLADE.windup+Battle.BLADE.active: action_progress = 0.40+(t-Battle.BLADE.windup)/Battle.BLADE.active*0.25
   else: action_progress = 0.65+(t-Battle.BLADE.windup-Battle.BLADE.active)/Battle.BLADE.recovery*0.35
  action_kind = ("punch" if swing_unarmed else ("axe" if swing_tool else "blade")) if fighting else work_kind
  var direction: Vector2 = (swing_direction if fighting else work_direction)*Vector2(visual_facing,1)
  action = Action.sample(action_kind,action_progress,direction,pose.front_hand)

 if visual_roll > 0.001:
  pose = pose.duplicate()
  pose.scale = Vector2(pose.scale).lerp(Vector2(1.08,0.72),visual_roll)
  pose.offset = Vector2(pose.offset).lerp(Vector2(0,-1),visual_roll)
  pose.head = Vector2(pose.head)+Vector2(1,4)*visual_roll
  pose.front_foot = Vector2(pose.front_foot).lerp(Vector2(5,7),visual_roll)
  pose.back_foot = Vector2(pose.back_foot).lerp(Vector2(-4,7),visual_roll)
  pose.front_hand = Vector2(pose.front_hand).lerp(Vector2(6,-5),visual_roll)
  pose.back_hand = Vector2(pose.back_hand).lerp(Vector2(-5,-5),visual_roll)
 var guard_weight := 0.0
 if fighter.mode in ["parry","parry_success"]:
  guard_weight = 1-smoothstep(0,fighter.duration,visual_action_time) if fighter.mode == "parry_success" else smoothstep(0,Battle.PARRY.window_from,visual_action_time)*(1-smoothstep(Battle.PARRY.window_to,fighter.duration,visual_action_time))
  pose = pose.duplicate()
  pose.front_hand = Vector2(pose.front_hand).lerp(Vector2(10,-9),guard_weight)
  pose.back_hand = Vector2(pose.back_hand).lerp(Vector2(-4,-7),guard_weight)
 var lean: float = float(pose.lean)+float(action.get("lean",0))*visual_facing
 var offset: Vector2 = Vector2(pose.offset)+Vector2(action.get("offset",Vector2.ZERO))*Vector2(visual_facing,1)
 var recoil := sin(clampf(1-visual_hurt/0.16,0,1)*PI)
 offset += Vector2(visual_hit_direction*recoil*1.5,-recoil*0.5)
 lean += visual_hit_direction*recoil*0.06
 var transform := Transform2D(lean,Vector2(pose.scale)*Vector2(visual_facing*visual_turn,1),0,Vector2.ZERO)
 transform.origin = offset+Vector2(0,10)-transform*Vector2(0,10)
 if fighter.mode == "roll":
  var pivot := Vector2(0,-3)
  var turn := Transform2D(Pose.smoother(visual_action_time/Battle.ROLL.duration)*TAU*signf(fighter.direction.x),Vector2.ZERO)
  turn.origin = pivot-turn*pivot
  transform = transform*turn
 if visual_roll > 0.001:
  # Keep the rotating silhouette against its support line, rather than orbiting
  # in the air. The collision shape and real player position stay untouched.
  var bottom := -INF
  var contact_points := [Vector2(-5,6),Vector2(5,6),Vector2(pose.front_foot)+Vector2(3,1),Vector2(pose.back_foot)+Vector2(-2,1),Vector2(pose.head)+Vector2(-4,-19),Vector2(pose.head)+Vector2(4,-19),Vector2(pose.head)+Vector2(-4,-8),Vector2(pose.head)+Vector2(4,-8)]
  for point in contact_points: bottom = maxf(bottom,(transform*Vector2(point)).y)
  transform.origin.y += (10-bottom)*visual_roll
 draw_set_transform_matrix(transform)
 if not bare:
  # Two scarf tails move at different phases; only the artwork moves.
  var tail: float = pose.cloth
  draw_colored_polygon(PackedVector2Array([Vector2(-3,-10),Vector2(-8,-7),Vector2(-10+tail,3),Vector2(-6+tail,1),Vector2(-4,5),Vector2(-2,-3)]),Art.INK)
  draw_line(Vector2(-5,-8),Vector2(-7+tail,1),Art.COPPER,2)
 _draw_limb(Vector2(-4,-5),Vector2(-6,-2),pose.back_hand,skin.darkened(0.2),3)
 _draw_leg(Vector2(-2,3),pose.back_foot,skin.darkened(0.2) if bare else trousers.darkened(0.15),Art.INK)
 _draw_leg(Vector2(2,3),pose.front_foot,skin if bare else trousers,Art.INK)
 draw_rect(Rect2(-5,-8,10,12),skin if bare else Art.INK)
 if bare:
  draw_rect(Rect2(-4,-7,8,10),skin)
  draw_rect(Rect2(-4,1,8,4),Art.SHADOW)
 else:
  var waist := 3.0 if appearance.get("gender","male") == "female" else 4.0
  draw_colored_polygon(PackedVector2Array([Vector2(-4,-8),Vector2(4,-8),Vector2(waist,1),Vector2(5,5),Vector2(1,6),Vector2(-1,3),Vector2(-5,5),Vector2(-waist,1)]),coat)
  draw_rect(Rect2(-4,-7,3,10),Art.JADE)
  draw_line(Vector2(0,-7),Vector2(1,2),Art.MIST,1)
  draw_rect(Rect2(-5,0,10,2),Art.COAL)
  draw_rect(Rect2(0,0,2,2),Art.EMBER)
  draw_rect(Rect2(3,-7,3,4),Art.COPPER)
  draw_rect(Rect2(3,-7,3,1),Art.EMBER)
 var head: Vector2 = pose.head
 draw_set_transform_matrix(transform.translated_local(head))
 if appearance.get("hair","short") == "long":
  draw_colored_polygon(PackedVector2Array([Vector2(-5,-17),Vector2(1,-18),Vector2(4,-13),Vector2(5,-3),Vector2(1,-5),Vector2(-1,-3),Vector2(-6,-4)]),Art.COAL)
 draw_rect(Rect2(-4,-17,8,9),Art.INK)
 draw_rect(Rect2(-3,-16,7,7),skin)
 draw_rect(Rect2(-3,-15,2,6),skin.darkened(0.2))
 if not bare:
  # Folded ash hood, porcelain half-mask, one visible eye.
  draw_colored_polygon(PackedVector2Array([Vector2(-5,-10),Vector2(-5,-17),Vector2(-2,-20),Vector2(3,-19),Vector2(5,-16),Vector2(4,-15),Vector2(0,-17),Vector2(-2,-14),Vector2(-2,-10)]),Art.SHADOW)
  draw_line(Vector2(-4,-17),Vector2(-1,-19),Art.SLATE,1)
  draw_rect(Rect2(0,-14,5,3),Art.IVORY)
  draw_rect(Rect2(4,-13,1,3),Art.COPPER)
  draw_rect(Rect2(-4,-10,8,2),Art.COPPER)
 else:
  draw_rect(Rect2(-4,-18,7,3),Art.COAL)
 var blink := fposmod(visual_idle_clock,6.0) > 5.85
 draw_rect(Rect2(2,-15,2,1 if blink else 2),Art.INK)
 draw_set_transform_matrix(transform)
 var hand: Vector2 = pose.front_hand
 if visual_medicine > 0.02 and action.is_empty():
  hand = hand.lerp(Vector2(5,-13),visual_medicine)
  _draw_limb(Vector2(4,-6),Vector2(8,-5),hand,skin,3)
  draw_texture_rect(preload("res://data/items.gd").icon("spark_balm"),Rect2(hand-Vector2(4,4),Vector2(8,8)),false,Color(1,1,1,visual_medicine))
 elif not action.is_empty():
  var progress := action_progress
  var kind := action_kind
  var angle: float = action.angle
  var presence: float = action.presence
  hand = action.hand
  _draw_limb(Vector2(4,-6),action.elbow,hand,skin,3)
  if kind == "build":
   draw_rect(Rect2(hand,Vector2(2,2)),Color(Art.EMBER, presence))
  else:
   var along := Vector2.from_angle(angle)
   var normal := along.orthogonal()
   var tip := hand+along*(20 if kind == "blade" else 15)
   if kind == "punch" and presence > 0.1:
    draw_rect(Rect2(hand-Vector2(2,2),Vector2(5,4)),skin.lightened(0.1))
   elif kind != "punch" and presence > 0.03:
    if progress > 0.4 and progress < 0.65 and (fighter.mode != "attack" or fighter.phase() == "attack_active"):
     draw_arc(Vector2(0,-5),24,angle-0.5,angle,9,Color(0.94,0.77,0.5,0.32),2)
    var tool_alpha := smoothstep(0,0.25,presence)
    draw_line(hand,tip,Color(Art.INK,tool_alpha),4)
    draw_line(hand,tip,Color(Art.COPPER if kind in ["pick","axe"] else Art.IVORY,tool_alpha),2)
    if kind == "axe":
     draw_colored_polygon(PackedVector2Array([(tip-along*5),(tip+along*3),(tip+along*3+normal*8),(tip-along*5+normal*6)]),Color(Art.MIST,tool_alpha))
     draw_line((tip+normal*7),(tip+along*3+normal*8),Color(Art.IVORY,tool_alpha),1)
    elif kind == "pick":
     draw_line((tip-normal*7-along*2),(tip+normal*7),Color(Art.MIST,tool_alpha),3)
     draw_line((tip+normal*7),(tip+normal*9-along*3),Color(Art.IVORY,tool_alpha),1)
    else:
     # A chipped slate blade with one porcelain edge, instead of a straight bar.
     draw_colored_polygon(PackedVector2Array([(hand+along*3-normal),(hand+along*7-normal*2),(hand+along*10-normal),(tip-along*2-normal*2),(tip+along),(tip-along*3+normal*2),(hand+along*3+normal)]),Color(Art.MIST,tool_alpha))
     draw_line((hand+along*4-normal),(tip+along),Color(Art.IVORY,tool_alpha),1)
     draw_line((hand-normal*3),(hand+normal*3),Color(Art.COPPER,tool_alpha),2)
 else:
  _draw_limb(Vector2(4,-5),Vector2(6,-2).lerp(Vector2(8,-9),guard_weight),hand,skin,3)
 draw_set_transform_matrix(Transform2D.IDENTITY)
 if fighter.roll_invulnerable():
  var trail_direction := signf(fighter.direction.x)
  draw_line(Vector2(-trail_direction*11,4),Vector2(-trail_direction*18,4),Color(0.70,0.81,0.77,0.45),1)
  draw_line(Vector2(-trail_direction*10,7),Vector2(-trail_direction*15,7),Color(0.53,0.67,0.66,0.3),1)
 if fighter.mode in ["parry","parry_success"]:
  var color := Art.IVORY if fighter.parry_open() or fighter.mode == "parry_success" else Art.SLATE
  color.a = guard_weight
  var at := Vector2(facing*12,-9)
  draw_line(at+Vector2(-3,-6),at+Vector2(4,0),color,2)
  draw_line(at+Vector2(4,0),at+Vector2(-3,6),color,2)
  if fighter.parry_open(): draw_rect(Rect2(at+Vector2(6,-1),Vector2(2,2)),Art.EMBER)
 if medicine_progress > 0:
  draw_rect(Rect2(-12,-29,24,3),Art.INK)
  draw_rect(Rect2(-12,-29,24*medicine_progress,3),Art.EMBER)
 if heal_flash_remaining > 0:
  var color := Art.IVORY
  color.a = minf(1,heal_flash_remaining*3)
  var text_at := Vector2(-9,-32-(0.65-heal_flash_remaining)*10)
  var text := "+%d" % heal_flash_amount
  draw_string_outline(ThemeDB.fallback_font,text_at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,1,Color(0.1,0.16,0.18,color.a))
  draw_string(ThemeDB.fallback_font,text_at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,color)
 if hurt_immunity > 0:
  var alpha := 0.15+sin(visual_idle_clock*6)*0.08
  for side in [-1,1]:
   draw_line(Vector2(side*11,-16),Vector2(side*14,-5),Color(0.88,0.87,0.76,alpha),1)

func _draw_limb(start: Vector2, joint: Vector2, end: Vector2, color: Color, width: float, sleeved: bool = true) -> void:
 var ink := Color("18252e")
 var axis := end-start
 var bend := 1.0 if (joint-start).dot(Vector2(axis.y,-axis.x)) >= 0 else -1.0
 joint = Limb.joint(start,end,4.5 if sleeved else 4.0,5.0 if sleeved else 4.0,bend)
 draw_line(start,joint,ink,width+2)
 draw_line(joint,end,ink,width+2)
 draw_line(start,joint,Art.JADE.darkened(0.22) if sleeved and not unclothed else color,width)
 draw_line(joint,end,color,width)

func _draw_leg(hip: Vector2, foot: Vector2, color: Color, boot: Color) -> void:
 var knee := Limb.joint(hip,foot-Vector2(0,1),4,4)
 _draw_limb(hip,knee,foot-Vector2(0,1),color,3,false)
 draw_rect(Rect2(foot+Vector2(-2,-1),Vector2(5,2)),boot)
