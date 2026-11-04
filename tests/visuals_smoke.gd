extends SceneTree
const Pose = preload("res://scripts/visuals/player_pose.gd")
const BossPose = preload("res://scripts/visuals/andrew_pose.gd")
const Direction = preload("res://scripts/visuals/art_direction.gd")
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var continuous := true
 for weight in [0.0,0.4,1.0]:
  continuous = continuous and Pose.foot(0,1,weight).distance_to(Pose.foot(TAU-0.0001,1,weight)) < 0.01
 check_result(continuous,"Gait joins continuously at its loop boundary")
 check_result(Pose.foot(0.5,1,1).y == 10 and Pose.foot(4.5,1,1).y < 10,"Walk alternates planted support and lifted return foot")
 var finite := true
 for phase in ["intro","chase","uppercut_windup","uppercut_active","uppercut_recovery","spin_windup","spin_active","spin_recovery","backflip","super_windup","super_flight","super_impact","super_recovery","stunned"]:
  for frame in range(61):
   for value in BossPose.sample(phase,frame/60.0,1,frame*0.1,48).values():
    if value is Vector2: finite = finite and value.is_finite()
    else: finite = finite and is_finite(value)
 check_result(finite,"All boss phases produce finite artwork transforms at endpoints and transitions")
 check_result(Direction.stroke(0.2) < 0 and Direction.stroke(0.55) == 1,"Action curve separates anticipation strike and follow through")
 var gesture_neutral := true
 var gesture_finite := true
 var action = preload("res://scripts/visuals/action_pose.gd")
 var rest := Vector2(6,1)
 for kind in ["punch","blade","pick","axe","build"]:
  for aim in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
   for t in [0.0,1.0]:
    var end: Dictionary = action.sample(kind,t,aim,rest)
    gesture_neutral = gesture_neutral and Vector2(end.hand).distance_to(rest) < 0.001 and Vector2(end.elbow).distance_to(Vector2(6,-2)) < 0.001 and Vector2(end.offset).length() < 0.001 and absf(end.lean) < 0.001
   for frame in range(61):
    var pose: Dictionary = action.sample(kind,frame/60.0,aim,rest)
    gesture_finite = gesture_finite and Vector2(pose.hand).is_finite() and Vector2(pose.hand).length() < 24
 check_result(gesture_neutral,"Every aimed tool and melee gesture starts and ends at the neutral hand and elbow")
 check_result(gesture_finite,"All action directions remain finite and within arm reach")
 var cloth60 = preload("res://scripts/visuals/cloth_motion.gd").new()
 var cloth30 = preload("res://scripts/visuals/cloth_motion.gd").new()
 for i in range(60): cloth60.advance(5,1.0/60)
 for i in range(30): cloth30.advance(5,1.0/30)
 check_result(absf(cloth60.value-cloth30.value) < 0.01,"Cloth response stays consistent at 30 and 60 FPS")
 var previous: float = cloth60.value
 cloth60.advance(-5,1.0/60)
 check_result(cloth60.value > 0 and absf(cloth60.value-previous) < 1,"Reversing cloth target preserves inertia rather than snapping")
 for i in range(100): cloth60.advance(999 if i%2 else -999,1)
 check_result(is_finite(cloth60.value) and absf(cloth60.value) <= 6,"Cloth remains bounded after long frames and abrupt target changes")
 check_result(BossPose.sample("spin_active",0,1,0,0).turn > 0 and BossPose.sample("spin_active",0.5,1,0,0).turn < 0 and BossPose.sample("spin_active",1,1,0,0).turn > 0,"One boss spin presents front then back then front")
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.set_physics_process(false)
 main.encounter.enabled = false
 main.items.set_physics_process(false)
 main.player.set_physics_process(false)
 var player = main.player
 var shape: Vector2 = player.get_node("Collision").shape.size
 var origin: Vector2 = player.position
 player.position = Vector2(1544,342)
 player.velocity = Vector2.ZERO
 var resting: bool = player.presentation_grounded()
 player.position = Vector2(1544,64)
 var airborne: bool = not player.presentation_grounded()
 player.position = origin
 check_result(resting and airborne,"Remote zero vertical speed requires actual floor instead of showing a grounded pose at jump apex")
 var saved: Dictionary = main.saves.capture()
 main.items.animate_work(player,main.world.cell_at(origin)+Vector2i.RIGHT,"pick")
 check_result(player.work_remaining > 0 and player.swing_remaining == 0,"Mining gesture uses an independent cosmetic timer")
 for i in range(90):
  player.velocity = Vector2(115,0) if i < 30 else Vector2.ZERO
  player._process(1.0/60)
  main.effects._process(1.0/60)
 player.velocity = Vector2.ZERO
 check_result(player.position == origin and player.get_node("Collision").shape.size == shape and player.scale == Vector2.ONE,"Animation never moves or scales the physics body or its collider")
 check_result(player.resources.stamina == 100 and player.health == 100 and main.combat.entities.is_empty(),"Cosmetic movement and tool strokes cannot spend resources or deal damage")
 check_result(main.combat.world_time == 0,"Visual updates never advance shared gameplay time")
 check_result(main.saves.capture() == saved,"Transient poses and particles are excluded from persistent state")
 player.facing = -1
 player._process(0.03)
 var delayed_face: int = player.visual_facing
 player._process(0.04)
 check_result(delayed_face == 1 and player.visual_facing == -1 and player.facing == -1 and player.scale == Vector2.ONE,"Visual turn crosses its midpoint without delaying physical facing or scaling the body")
 player.medicine_progress = 0.5
 player._process(0.1)
 player.medicine_progress = 0
 player._process(0.03)
 check_result(player.visual_medicine > 0 and player.medicine_progress == 0 and player.medicine_cooldown == 0,"Lowering the flask continues visually without extending real medicine state")
 player.health = 50
 main.items.local_inventory().add("spark_balm",1)
 player.play_work(Vector2.RIGHT,"pick")
 check_result(main.items.primary_status(player,Vector2i.ZERO,0).begins_with("Можно применить"),"A cosmetic mining gesture cannot postpone medicine use")
 main.effects.clear()
 for i in range(50): main.effects.burst("impact",origin)
 check_result(main.effects.particles.size() <= 256 and main.effects.rings.size() <= 16,"Particle and ring pools remain bounded under rapid events")
 main.effects._process(3)
 check_result(main.effects.particles.is_empty() and main.effects.rings.is_empty(),"All transient effect instances expire")
 main.effects.burst("place",origin)
 main.world.generate()
 check_result(main.effects.particles.is_empty() and main.effects.rings.is_empty(),"Generating another world clears old cosmetic effects")
 player._process(0)
 player.dead = true
 player.visible = false
 player._process(0.01)
 check_result(main.effects.particles.size() > 0,"Hidden dead body can still emit its death dissolve")
 main.effects.clear()
 player.dead = false
 player._process(0.01)
 check_result(main.effects.rings.size() == 1,"Respawn emits a separate presentation effect")
 main.effects.clear()
 var enemy: int = main.combat.spawn_entity("ashling",origin+Vector2(80,0))
 main.combat.set_entity(enemy,{})
 check_result(main.effects.particles.is_empty(),"Snapshot cleanup does not play a false enemy death")
 enemy = main.combat.spawn_entity("ashling",origin+Vector2(80,0))
 main.combat.hit_entity(enemy,100,Vector2.RIGHT)
 check_result(not main.effects.particles.is_empty() and not main.combat.entities.has(enemy),"A real lethal hit emits its dissolve without keeping a ghost collider")
 var material: Texture2D = preload("res://assets/terrain.svg")
 check_result(material.get_width() == 48 and material.get_height() == 16,"New original terrain atlas preserves the stable 16 pixel tile regions")
 print("Visual failures: ",failures)
 quit(1 if failures else 0)
