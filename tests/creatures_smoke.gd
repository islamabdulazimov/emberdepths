extends SceneTree
const Creatures = preload("res://data/creatures.gd")
var failures := 0
var main: Node2D
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func reset_player() -> void:
 main.player.position = Vector2(650,630)
 main.player.facing = 1
 main.player.fighter.reset()
 main.player.resources.reset_full()
 main.player.hurt_immunity = 0
 main.player.knockback_remaining = 0
func begin_active(enemy: Node2D, d: Dictionary) -> void:
 enemy.attack_state = "windup"
 enemy.attack_elapsed = float(d.windup)
 enemy.attack_hits.clear()
 enemy.attack_facing = -1
 enemy.attack_target = main.player.position
 enemy.step_attack(0.001,main.player,main.combat)
func run() -> void:
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.combat.set_physics_process(false)
 main.interaction.set_process(false)
 main.items.set_physics_process(false)
 main.exploration.set_process(false)
 main.encounter.enabled = false
 main.player.set_physics_process(false)
 for x in range(25,60):
  for y in range(32,40): main.world.apply_edit(Vector2i(x,y),-1)
  main.world.apply_edit(Vector2i(x,40),2)
 main.world.solid.update_internals()
 await physics_frame
 for kind in Creatures.DEFINITIONS:
  reset_player()
  var d: Dictionary = Creatures.DEFINITIONS[kind]
  var id: int = main.combat.spawn_entity(kind,Vector2(674 if kind == "ashweaver" else 690,640))
  var enemy = main.combat.entities[id]
  check_result(main.combat.enemy_at(main.world.cell_at(enemy.position+Vector2(0,-d.size.y+2))) == id,kind+": mouse selection uses its real tall/wide collider")
  enemy.set_process(false)
  enemy.grace = 0
  enemy.step_attack(1.0/60,main.player,main.combat)
  check_result(enemy.attack_state == "windup" and main.player.health == 100,kind+": visible preparation is harmless")
  begin_active(enemy,d)
  for i in range(20): enemy.step_attack(1.0/60,main.player,main.combat)
  check_result(main.player.health == 100-int(d.damage) and enemy.attack_state == "recovery",kind+": active hit damages once, then opens recovery")
  reset_player()
  main.player.fighter.begin("roll",Vector2.RIGHT,0.44)
  main.player.fighter.elapsed = 0.1
  begin_active(enemy,d)
  for i in range(20): enemy.step_attack(1.0/60,main.player,main.combat)
  check_result(main.player.health == 100,kind+": an invulnerable roll avoids the attack")
  reset_player()
  main.player.fighter.begin("parry",Vector2.RIGHT,0.58)
  main.player.fighter.elapsed = 0.1
  begin_active(enemy,d)
  for i in range(20): enemy.step_attack(1.0/60,main.player,main.combat)
  check_result(main.player.health == 100 and enemy.attack_state == "stagger",kind+": successful parry interrupts and staggers")
  reset_player()
  for y in range(36,40): main.world.apply_edit(Vector2i(41 if kind == "ashweaver" else 42,y),2)
  main.world.solid.update_internals()
  await physics_frame
  enemy.attack_state = "chase"
  enemy.attack_elapsed = 0
  enemy.hit_stun = 0
  enemy.step_attack(0.1,main.player,main.combat)
  check_result(enemy.attack_state == "chase",kind+": cannot prepare a hit through solid terrain")
  begin_active(enemy,d)
  for i in range(20): enemy.step_attack(1.0/60,main.player,main.combat)
  check_result(main.player.health == 100,kind+": a block also stops an already released attack")
  for y in range(36,40): main.world.apply_edit(Vector2i(41 if kind == "ashweaver" else 42,y),-1)
  main.world.solid.update_internals()
  await physics_frame
  var scaled := true
  for players in range(1,5): scaled = scaled and main.combat.Rules.scaled_health(d.health,players) == ceili(float(d.health)*(1+0.25*(players-1)))
  check_result(scaled,kind+": all four health multipliers use original base health")
  if kind == "void_collector":
   enemy.health = 60
   enemy.attack_facing = 1
   main.combat.hit_entity(id,24,Vector2.LEFT)
   var front: int = enemy.health
   enemy.health = 60
   main.combat.hit_entity(id,24,Vector2.RIGHT)
   check_result(front == 48 and enemy.health == 36,kind+": frontal armour reduces damage, rear takes the full hit")
  if kind == "ashweaver":
   reset_player()
   begin_active(enemy,d)
   enemy.step_attack(1.0/60,main.player,main.combat)
   var velocity: Vector2 = enemy.velocity
   main.player.position.y -= 100
   enemy.step_attack(1.0/60,main.player,main.combat)
   check_result(enemy.velocity == velocity,kind+": the dive keeps its fixed aim when the player moves")
  enemy.health = 1
  main.combat.hit_entity(id,24,Vector2.RIGHT)
  check_result(not main.combat.entities.has(id) and not main.items.drops.is_empty(),kind+": lethal hit removes its collider and uses existing loot drops")
  print("CREATURE_DONE ",kind)
 main.world.configure_expanded()
 main.world.generate()
 reset_player()
 check_result(not main.exploration.spawn_safe("seamling",main.world.spawn_position(),[main.player]),"Expanded spawner forbids the safe arrival area")
 var id: int = main.combat.spawn_entity("seamling",Vector2(4000,1500))
 var enemy = main.combat.entities[id]
 enemy.site_guard = true
 enemy.attack_state = "active"
 main.player.position = main.world.spawn_position()
 var old_position: Vector2 = enemy.position
 main.combat._physics_process(1.0/60)
 check_result(enemy.position == old_position and not enemy.is_processing() and enemy.attack_state == "chase","Distant enemies sleep without scanning or simulating the whole world")
 var ambient: int = main.combat.spawn_entity("ashweaver",Vector2(4100,1500))
 main.combat._physics_process(1.0/60)
 check_result(not main.combat.entities.has(ambient) and main.combat.entities.has(id),"Far ambient enemies free the population cap while persistent ruin guards remain asleep")
 main.queue_free()
 await process_frame
 print("Creature failures: ",failures)
 quit(1 if failures else 0)
