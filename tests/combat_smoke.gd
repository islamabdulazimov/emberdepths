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
 check_result(player.health > 72 and player.health <= 100, "Safe recovery regenerates health within maximum")
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
 combat._physics_process(0.02)
 check_result(player.health == 86, "Day enemy contact uses day damage")
 combat._physics_process(0.02)
 check_result(player.health == 86, "Repeated contact respects player immunity")
 player.health = 100
 player.hurt_immunity = 0
 combat.world_time = 180
 combat._physics_process(0.02)
 check_result(player.health == 78, "Night contact increases damage")
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
 check_result(items.swing(player, 0, Vector2.RIGHT) and combat.entities[enemy_id].health == 45, "Terrain blocks melee damage")
 main.world.apply_edit(Vector2i(97, 21), -1)
 main.world.solid.update_internals()
 for i in range(2):
  await physics_frame
 items.attack_ready_at[1] = 0
 items.swing(player, 0, Vector2.LEFT)
 check_result(combat.entities[enemy_id].health == 45, "Melee cannot hit behind attack direction")
 items.attack_ready_at[1] = 0
 items.swing(player, 0, Vector2.RIGHT)
 check_result(combat.entities[enemy_id].health == 27, "Selected blade deals data-defined damage")
 check_result(not items.swing(player, 0, Vector2.RIGHT) and combat.entities[enemy_id].health == 27, "Swing cooldown also limits damage")
 main.add_player(2, original + Vector2(8, 0))
 main.get_node("Players/2").set_physics_process(false)
 items.attack_ready_at[1] = 0
 items.swing(player, 0, Vector2.RIGHT)
 items.attack_ready_at[1] = 0
 items.swing(player, 0, Vector2.RIGHT)
 check_result(not combat.entities.has(enemy_id), "Three blade strikes defeat normal enemy")
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
 check_result(combat.damage_player(1, 999, original + Vector2(20, 0)) and player.dead and player.health == 0 and player.unclothed, "Fatal hit kills player and removes outfit")
 check_result(combat.chests.size() == 1 and bag.count_item("stone") == 0 and combat.chests.values()[0].contents == carried, "Death transfers complete inventory into one chest")
 check_result(not combat.damage_player(1, 999, original) and combat.chests.size() == 1, "Dead player cannot create repeated chests from repeated hits")
 check_result(not items.use_primary(player, Vector2i(97, 22), 0) and not items.place_selected(player, Vector2i(97, 21), 0) and not items.transfer(1, 0, 1), "Dead player cannot mine build or transfer")
 check_result(items.craft(1, "dirt_wall") == "Нельзя создавать предметы после смерти", "Crafting disabled while dead")
 combat._physics_process(1.9)
 check_result(not player.dead and player.health == 100 and player.unclothed and player.hurt_immunity > 0 and bag.count_item("stone") == 0, "Respawn restores health and immunity but not inventory or outfit")
 player.hurt_immunity = 0
 combat.damage_player(1, 999, original)
 check_result(combat.chests.size() == 2 and combat.chests.values()[0].contents == carried, "Second death preserves earlier chest")
 combat._physics_process(1.9)
 var first_chest = combat.chests.values()[0]
 var chest_position: Vector2 = first_chest.position
 var chest_cell: Vector2i = main.world.cell_at(chest_position)
 player.position = chest_position + Vector2(100, 0)
 check_result(not combat.break_chest(player, chest_cell), "Chest cannot be broken beyond reach")
 player.position = chest_position
 check_result(combat.break_chest(player, chest_cell) and combat.chests.size() == 1 and combat.entities.size() == 1, "Breaking chest releases loot and one spirit")
 var stone_count := 0
 var pick_count := 0
 for drop in items.drops.values():
  if drop.item_id == "stone":
   stone_count += drop.count
  elif drop.item_id == "stone_pick":
   pick_count += drop.count
 check_result(stone_count == 10 and pick_count == 1, "Chest contents return exactly once as dropped resources")
 var spirit_id: int = combat.entities.keys()[0]
 var anchor: Vector2 = combat.entities[spirit_id].anchor
 player.position = anchor + Vector2(300, 0)
 combat.entities[spirit_id].position = anchor + Vector2(500, 0)
 var inside_tether := true
 for i in range(30):
  combat._physics_process(0.1)
  inside_tether = inside_tether and combat.entities[spirit_id].position.distance_to(anchor) <= 160.01
 check_result(inside_tether, "Flying spirit stays within ten blocks of original chest")
 combat.hit_entity(spirit_id, 9999, Vector2.RIGHT)
 check_result(combat.entities.has(spirit_id) and combat.entities[spirit_id].health == 1, "Spirit survives first hit regardless of weapon damage")
 combat.hit_entity(spirit_id, 1, Vector2.RIGHT)
 check_result(not combat.entities.has(spirit_id), "Second hit defeats spirit")
 player.position = original
 player.health = 100
 player.hurt_immunity = 0
 spirit_id = combat.spawn_entity("spirit", original, original)
 combat._physics_process(0.1)
 check_result(player.health == 100, "Newborn spirit gives time to recover equipment")
 combat._physics_process(1.2)
 check_result(player.health == 88, "Spirit contact damages after grace period")
 clear_enemies(combat)
 # The first chest is gone; punch target uses an adjacent empty tile.
 spirit_id = combat.spawn_entity("spirit", original + Vector2(20, 0), original)
 items.attack_ready_at[1] = 0
 var spirit_cell: Vector2i = main.world.cell_at(combat.entities[spirit_id].position)
 check_result(items.use_primary(player, spirit_cell, 9) and combat.entities[spirit_id].health == 1 and player.swing_unarmed, "Empty hand can strike spirit after loss of gear")
 items.attack_ready_at[1] = 0
 items.use_primary(player, spirit_cell, 9)
 check_result(not combat.entities.has(spirit_id), "Two unarmed strikes also defeat spirit")
 main.world.apply_edit(Vector2i(96, 21), 2)
 main.world.apply_edit(Vector2i(96, 20), 2)
 var spawn: Vector2 = main.world.safe_spawn_position()
 check_result(main.world.block_at(main.world.cell_at(spawn + Vector2(0, -4))) == -1, "Respawn finder avoids player-built solid at original spawn")
 var state: Dictionary = combat.snapshot(true)
 check_result(state.chests.size() == 1 and state.chests.values()[0].has("contents"), "Combat snapshot retains chest contents for future saves and late join")
 print("Combat failures: ", failures)
 quit(1 if failures else 0)
