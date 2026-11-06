extends CharacterBody2D
var appearance: Dictionary = preload("res://data/appearance.gd").DEFAULT.duplicate()
var equipment:Dictionary=preload("res://data/equipment.gd").empty()
var roll_cooldown:=0.0
var guard_cooldown:=0.0
var block_requires_release:=false
var held_item:=""
var block_flash:=0.0
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
var visual_air_time:=0.0
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
var money:=0
var recovery_count:=0
var help_progress:=0.0
var revive_immunity:=0.0
var revive_trail:Array[Vector2]=[]
var trail_clock:=0.0
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
  velocity.x=move_toward(velocity.x,0,1000*delta)
  velocity.y=minf(600,velocity.y+GRAVITY*delta)
  move_and_slide()
  return
 knockback_remaining = maxf(0.0, knockback_remaining - delta)
 if fighter.mode=="block":
  velocity.x=move_toward(velocity.x,move_command*SPEED*0.35,1000*delta)
 elif fighter.mode == "roll":
  velocity.x = fighter.direction.x*float(Battle.ROLL.speed)
 elif fighter.mode in ["parry","parry_success","help"]:
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
 swing_unarmed=kind=="punch"
 swing_tool=kind=="axe"
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
 if revive_immunity>0 and not dead:
  trail_clock+=delta
  if trail_clock>=.06:
   trail_clock=0;revive_trail.append(position)
   if revive_trail.size()>5:revive_trail.pop_front()
 else:revive_trail.clear()
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
  self_modulate.a=1
  queue_redraw()
 else:
  self_modulate.a=.58 if revive_immunity>0 else 1
  visual_alive_unclothed=unclothed
 visual_was_dead = dead
 visual_health = health
 heal_flash_remaining = maxf(0, heal_flash_remaining - delta)
 # Remote bodies do not run local physics; use replicated velocity for their gait.
 var grounded := presentation_grounded()
 visual_air_time=0 if grounded else visual_air_time+delta
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
  visual_clock += delta * absf(visual_speed) * (TAU/(20.0/0.42))
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
 if revive_immunity>0 and not dead:
  for i in range(revive_trail.size()):draw_rect(Rect2(revive_trail[i]-position+Vector2(-4,-12),Vector2(8,17)),Color(.7,.93,.86,.035*(i+1)))
  for pad in [3,2,1]:draw_rect(Rect2(-6-pad,-20-pad,12+pad*2,26+pad*2),Color(.7,.94,.84,.035))
 preload("res://scripts/visuals/hero_sprite.gd").draw_actor(self)

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
