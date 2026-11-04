extends CharacterBody2D
const Art = preload("res://scripts/visuals/art_direction.gd")
const Pose = preload("res://scripts/visuals/player_pose.gd")
var visual_clock := 0.0
var visual_landing := 0.0
var visual_grounded := false
var visual_fall_speed := 0.0
var visual_pose: Dictionary = {}
var visual_hurt := 0.0
var visual_step := -1
var visual_initialized := false
var visual_was_dead := false
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

func _process(delta: float) -> void:
 work_remaining = maxf(0,work_remaining-delta)
 visual_hurt = maxf(0,visual_hurt-delta)
 if visual_initialized:
  if dead and not visual_was_dead: emit_visual("death",Vector2(0,-5))
  elif not dead and visual_was_dead: emit_visual("respawn",Vector2(0,-5))
  elif health < visual_health:
   visual_hurt = 0.16
   emit_visual("hurt",Vector2(0,-5),Vector2(-facing,-1))
 visual_initialized = true
 visual_was_dead = dead
 visual_health = health
 heal_flash_remaining = maxf(0, heal_flash_remaining - delta)
 # Remote bodies do not run local physics; use replicated velocity for their gait.
 var grounded := is_on_floor() if is_physics_processing() else absf(velocity.y) < 5.0
 if grounded and not visual_grounded and visual_fall_speed > 70:
  visual_landing = clampf(visual_fall_speed / 350.0, 0, 1)
  emit_visual("land",Vector2(0,10))
 if not grounded and visual_grounded and velocity.y < -20: emit_visual("step",Vector2(0,10))
 visual_landing = move_toward(visual_landing, 0, delta * 6)
 visual_fall_speed = velocity.y
 visual_grounded = grounded
 if not dead:
  visual_clock += delta * (2.0 + absf(velocity.x) * 0.12)
  var step_index := floori(visual_clock/PI)
  if grounded and absf(velocity.x) > 30 and step_index != visual_step: emit_visual("step",Vector2(0,10),Vector2(-signf(velocity.x),-0.3))
  visual_step = step_index
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
 if dead: return
 var pose: Dictionary = visual_pose if not visual_pose.is_empty() else Pose.sample(visual_clock,velocity.x,velocity.y,is_on_floor(),0)
 var skin := Color("cda88d").lerp(Art.IVORY,visual_hurt*3)
 var coat: Color = Art.JADE.darkened(0.13).lerp(Art.IVORY,visual_hurt*3)
 var trousers: Color = Art.SHADOW
 # Contact shadow remains outside the artwork transform.
 draw_rect(Rect2(-6,9,12,2),Color(0.06,0.10,0.13,0.24))
 var scale_value: Vector2 = pose.scale
 var transform := Transform2D(float(pose.lean),scale_value*Vector2(facing,1),0,Vector2(pose.offset)+Vector2(0,10)-Vector2(0,10)*scale_value)
 draw_set_transform_matrix(transform)
 if not unclothed:
  # Two scarf tails move at different phases; only the artwork moves.
  var tail: float = pose.cloth
  draw_colored_polygon(PackedVector2Array([Vector2(-3,-10),Vector2(-8,-7),Vector2(-10+tail,3),Vector2(-6+tail,1),Vector2(-4,5),Vector2(-2,-3)]),Art.INK)
  draw_line(Vector2(-5,-8),Vector2(-7+tail,1).round(),Art.COPPER,2)
 _draw_limb(Vector2(-4,-5),Vector2(-6,-2),pose.back_hand,skin.darkened(0.2),3)
 _draw_leg(Vector2(-2,3),pose.back_foot,skin.darkened(0.2) if unclothed else trousers.darkened(0.15),Art.INK)
 _draw_leg(Vector2(2,3),pose.front_foot,skin if unclothed else trousers,Art.INK)
 draw_rect(Rect2(-5,-8,10,12),skin if unclothed else Art.INK)
 if unclothed:
  draw_rect(Rect2(-4,-7,8,10),skin)
  draw_rect(Rect2(-4,1,8,4),Art.SHADOW)
 else:
  draw_colored_polygon(PackedVector2Array([Vector2(-4,-8),Vector2(4,-8),Vector2(5,5),Vector2(1,6),Vector2(-1,3),Vector2(-5,5)]),coat)
  draw_rect(Rect2(-4,-7,3,10),Art.JADE)
  draw_line(Vector2(0,-7),Vector2(1,2),Art.MIST,1)
  draw_rect(Rect2(-5,0,10,2),Art.COAL)
  draw_rect(Rect2(0,0,2,2),Art.EMBER)
  draw_rect(Rect2(3,-7,3,4),Art.COPPER)
  draw_rect(Rect2(3,-7,3,1),Art.EMBER)
 var head: Vector2 = Vector2(pose.head).round()
 draw_set_transform_matrix(transform.translated_local(head))
 draw_rect(Rect2(-4,-17,8,9),Art.INK)
 draw_rect(Rect2(-3,-16,7,7),skin)
 draw_rect(Rect2(-3,-15,2,6),skin.darkened(0.2))
 if not unclothed:
  # Folded ash hood, porcelain half-mask, one visible eye.
  draw_colored_polygon(PackedVector2Array([Vector2(-5,-10),Vector2(-5,-17),Vector2(-2,-20),Vector2(3,-19),Vector2(5,-16),Vector2(4,-15),Vector2(0,-17),Vector2(-2,-14),Vector2(-2,-10)]),Art.SHADOW)
  draw_line(Vector2(-4,-17),Vector2(-1,-19),Art.SLATE,1)
  draw_rect(Rect2(0,-14,5,3),Art.IVORY)
  draw_rect(Rect2(4,-13,1,3),Art.COPPER)
  draw_rect(Rect2(-4,-10,8,2),Art.COPPER)
 else:
  draw_rect(Rect2(-4,-18,7,3),Art.COAL)
 var blink := fposmod(visual_clock*0.27,6.0) > 5.85
 draw_rect(Rect2(2,-15,2,1 if blink else 2),Art.INK)
 draw_set_transform_matrix(transform)
 var hand: Vector2 = pose.front_hand
 if medicine_progress > 0:
  var lift := smoothstep(0.0,0.3,medicine_progress)
  hand = Vector2(8-lift*3,-3-lift*10)
  _draw_limb(Vector2(4,-6),Vector2(8,-5),hand,skin,3)
  draw_texture_rect(preload("res://data/items.gd").icon("spark_balm"),Rect2(hand.round()-Vector2(4,4),Vector2(8,8)),false)
 elif swing_remaining > 0 or work_remaining > 0:
  var fighting := swing_remaining > 0
  var progress := 1.0-swing_remaining/0.24 if fighting else 1.0-work_remaining/0.30
  var direction: Vector2 = (swing_direction if fighting else work_direction)*Vector2(facing,1)
  var stroke: float = Art.stroke(progress)
  var kind := ("punch" if swing_unarmed else ("axe" if swing_tool else "blade")) if fighting else work_kind
  var angle := direction.angle()+lerpf(-1.05,0.9,stroke)
  if kind == "build":
   hand = Vector2(4,-5)+direction.normalized()*sin(progress*PI)*8
   _draw_limb(Vector2(4,-6),Vector2(7,-3),hand,skin,3)
   draw_rect(Rect2(hand.round(),Vector2(2,2)),Art.EMBER)
  else:
   hand = Vector2(0,-5)+Vector2.from_angle(angle)*(12 if kind == "punch" else 8)
   _draw_limb(Vector2(4,-6),Vector2(5,-4).lerp(hand,0.5),hand,skin,3)
   var along := Vector2.from_angle(angle)
   var normal := along.orthogonal()
   var tip := Vector2(0,-5)+along*23
   if kind == "punch":
    draw_rect(Rect2(hand.round()-Vector2(2,2),Vector2(5,4)),skin.lightened(0.1))
   else:
    if progress > 0.22 and progress < 0.75:
     for i in range(3):
      var trail_angle := angle-0.18*i
      draw_line((Vector2(0,-5)+Vector2.from_angle(trail_angle)*16).round(),(Vector2(0,-5)+Vector2.from_angle(trail_angle)*24).round(),Color(0.94,0.77,0.5,(1-i*0.25)*0.45),2)
    draw_line(hand.round(),tip.round(),Art.INK,4)
    draw_line(hand.round(),tip.round(),Art.COPPER if kind in ["pick","axe"] else Art.IVORY,2)
    if kind == "axe":
     draw_colored_polygon(PackedVector2Array([(tip-along*5).round(),(tip+along*3).round(),(tip+along*3+normal*8).round(),(tip-along*5+normal*6).round()]),Art.MIST)
     draw_line((tip+normal*7).round(),(tip+along*3+normal*8).round(),Art.IVORY,1)
    elif kind == "pick":
     draw_line((tip-normal*7-along*2).round(),(tip+normal*7).round(),Art.MIST,3)
     draw_line((tip+normal*7).round(),(tip+normal*9-along*3).round(),Art.IVORY,1)
    else:
     draw_line((hand-normal*3).round(),(hand+normal*3).round(),Art.COPPER,2)
 else:
  _draw_limb(Vector2(4,-5),Vector2(6,-2),hand,skin,3)
 draw_set_transform_matrix(Transform2D.IDENTITY)
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
  var alpha := 0.15+sin(visual_clock*3)*0.08
  for side in [-1,1]:
   draw_line(Vector2(side*11,-16),Vector2(side*14,-5),Color(0.88,0.87,0.76,alpha),1)

func _draw_limb(start: Vector2, joint: Vector2, end: Vector2, color: Color, width: float) -> void:
 var ink := Color("18252e")
 draw_line(start.round(),joint.round(),ink,width+2)
 draw_line(joint.round(),end.round(),ink,width+2)
 draw_line(start.round(),joint.round(),color,width)
 draw_line(joint.round(),end.round(),color,width)

func _draw_leg(hip: Vector2, foot: Vector2, color: Color, boot: Color) -> void:
 var knee := hip.lerp(foot,0.5)+Vector2(2,-1)
 _draw_limb(hip,knee,foot-Vector2(0,1),color,3)
 draw_rect(Rect2(foot.round()+Vector2(-2,-1),Vector2(5,2)),boot)
