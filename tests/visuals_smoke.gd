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
