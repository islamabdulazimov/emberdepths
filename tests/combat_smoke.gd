extends SceneTree
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok:
  print("PASS: ", message)
 else:
  failures += 1
  push_error(message)

func _initialize() -> void:
 call_deferred("run")

func clear_enemies(combat: Node2D) -> void:
 for id in combat.entities.keys():
  combat.set_entity(id, {})

func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 var combat = main.combat
 combat.spawning_enabled = false
 for i in range(90):
  await physics_frame
 combat.set_physics_process(false)
 var player = main.player
 player.set_physics_process(false)
 var original: Vector2 = player.position
 var items = main.items
 var bag = items.local_inventory()
 check_result(combat.damage_player(1, 14, original + Vector2(20, 0)) and player.health == 86, "Contact damage reduces health")
 check_result(not combat.damage_player(1, 14, original) and player.health == 86, "Hurt immunity prevents damage every frame")
 combat._physics_process(0.91)
 check_result(combat.damage_player(1, 14, original) and player.health == 72, "Damage resumes after immunity expires")
 for i in range(110):
  combat._physics_process(0.1)
 check_result(player.health == 72, "Health does not regenerate during recovery delay")
 for i in range(40):
  combat._physics_process(0.1)
 check_result(player.health == 72 and combat.heal_player(1, 5) == 5 and player.health == 77, "Health does not auto regenerate and explicit healing restores it")
 combat.world_time = 179.99
 combat._physics_process(0.02)
 check_result(combat.is_night() and combat.enemy_speed("ashling") == 65.0, "Night changes enemy speed")
 combat.world_time = 239.99
 combat._physics_process(0.02)
 check_result(not combat.is_night() and combat.enemy_speed("ashling") == 34.0 and combat.time_label().begins_with("День 2"), "Dawn advances day counter and lowers threat")
 check_result(combat._try_spawn([player]) and combat._try_spawn([player]) and not combat._try_spawn([player]), "Daytime enemy cap is two")
 var safe_spawns := true
 for enemy in combat.entities.values():
  safe_spawns = safe_spawns and enemy.position.distance_to(player.position) >= 160
 check_result(safe_spawns, "Natural spawns keep distance from players")
 clear_enemies(combat)
 combat.world_time = 180.0
 var spawned := 0
 for i in range(7):
  if combat._try_spawn([player]):
   spawned += 1
 check_result(spawned == 6, "Night enemy cap increases to six")
 clear_enemies(combat)
 player.hurt_immunity = 100.0
 var enemy_id: int = combat.spawn_entity("ashling", original + Vector2(90, -2))
 var start_x: float = combat.entities[enemy_id].position.x
 combat.set_physics_process(true)
 for i in range(60):
  await physics_frame
 combat.set_physics_process(false)
 check_result(combat.entities[enemy_id].position.x < start_x - 20 and combat.entities[enemy_id].is_on_floor(), "Enemy pursues at night and collides with ground")
 clear_enemies(combat)
 player.position = original
 player.health = 100
 player.hurt_immunity = 0
 combat.world_time = 0
 enemy_id = combat.spawn_entity("ashling", original)
 combat.entities[enemy_id].grace = 0
 var ash = combat.entities[enemy_id]
 ash.step_attack(0,player,combat)
 ash.step_attack(0.49,player,combat)
 ash.step_attack(0.01,player,combat)
 check_result(player.health == 86, "Day enemy active attack uses day damage")
 combat._physics_process(0.02)
 check_result(player.health == 86, "Repeated contact respects player immunity")
 player.health = 100
 player.hurt_immunity = 0
 combat.world_time = 180
 ash.night = true
 ash.change_attack("active")
 ash.step_attack(0.01,player,combat)
 check_result(player.health == 78, "Night active attack increases damage")
 clear_enemies(combat)
 player.health = 100
 player.hurt_immunity = 100
 player.position = original
 enemy_id = combat.spawn_entity("ashling", original + Vector2(32, 0))
 bag.add("stone_blade", 1)
 main.world.apply_edit(Vector2i(97, 21), 2)
 main.world.solid.update_internals()
 for i in range(2):
  await physics_frame
 player.fighter.reset()
 check_result(items.swing(player, 0, Vector2.RIGHT),"Blade begins beside an intervening block")
 combat.tick_fighter(player,0.13)
 check_result(combat.entities[enemy_id].health == 45,"Terrain blocks active melee damage")
 combat.tick_fighter(player,0.5)
 main.world.apply_edit(Vector2i(97, 21), -1)
 main.world.solid.update_internals()
 for i in range(2):
  await physics_frame
 items.attack_ready_at[1] = 0
 items.swing(player, 0, Vector2.LEFT)
 combat.tick_fighter(player,0.13)
 check_result(combat.entities[enemy_id].health == 45, "Melee cannot hit behind attack direction")
 combat.tick_fighter(player,0.5)
 items.attack_ready_at[1] = 0
 items.swing(player, 0, Vector2.RIGHT)
 combat.tick_fighter(player,0.13)
 check_result(combat.entities[enemy_id].health == 21, "Selected blade deals data-defined damage")
 check_result(not items.swing(player, 0, Vector2.RIGHT) and combat.entities[enemy_id].health == 21, "Swing cooldown also limits damage")
 main.add_player(2, original + Vector2(8, 0))
 main.get_node("Players/2").set_physics_process(false)
 combat.tick_fighter(player,0.5)
 items.attack_ready_at[1] = 0
 items.swing(player, 0, Vector2.RIGHT)
 combat.tick_fighter(player,0.13)
 combat.tick_fighter(player,0.5)
 check_result(not combat.entities.has(enemy_id), "Two blade strikes defeat normal enemy")
 check_result(main.get_node("Players/2").health == 100, "Cooperative melee has no friendly fire")
 main.remove_player(2)
 var loot := 0
 for drop in items.drops.values():
  if drop.item_id == "emberstone":
   loot += drop.count
 check_result(loot == 1, "Defeated enemy drops one fuel resource")
 items.set_physics_process(false)
 bag.load_data([])
 bag.add("stone", 10)
 bag.add("stone_pick", 1)
 bag.add("stone_blade", 1)
 bag.add("torch", 3)
 var carried: Array = bag.to_data()
 player.hurt_immunity = 0
 player.money=101
 check_result(combat.damage_player(1,999,original+Vector2(20,0)) and player.dead and player.health==0 and not player.unclothed,"fatal hit downs player without removing outfit")
 check_result(combat.chests.is_empty() and bag.to_data()==carried and player.money==51,"downed keeps complete inventory and half wallet")
 check_result(not combat.damage_player(1,999,original) and player.money==51,"repeat hits cannot charge a downed character twice")
 check_result(not items.use_primary(player,Vector2i(97,22),0) and not items.place_selected(player,Vector2i(97,21),0) and not items.transfer(1,0,1),"downed player cannot mine build or transfer")
 check_result(items.craft(1,"dirt_wall")=="Нельзя создавать предметы в упавшем состоянии","crafting disabled while downed")
 combat._physics_process(1.9)
 check_result(player.dead and bag.to_data()==carried,"time never automatically respawns downed character")
 check_result(main.survival.respawn_request(1) and player.health==100 and bag.to_data()==carried,"explicit respawn retains all items")
 player.hurt_immunity=0;combat.damage_player(1,999,original)
 check_result(player.dead and player.money==26 and combat.chests.is_empty(),"second death drops half remainder without a chest")
 main.survival.respawn_request(1)
 check_result(not combat.break_chest(player,main.world.cell_at(original)) and combat.entities.is_empty(),"old recovery interaction cannot create a new spirit")
 player.position=original;player.hurt_immunity=0;player.fighter.reset()
 main.world.apply_edit(Vector2i(96, 21), 2)
 main.world.apply_edit(Vector2i(96, 20), 2)
 var spawn: Vector2 = main.world.safe_spawn_position()
 check_result(main.world.block_at(main.world.cell_at(spawn + Vector2(0, -4))) == -1, "Respawn finder avoids player-built solid at original spawn")
 var state: Dictionary = combat.snapshot(true)
 check_result(state.chests.is_empty() and state.has("economy"), "Combat snapshot retains money for saves and late join")
 print("Combat failures: ", failures)
 quit(1 if failures else 0)
