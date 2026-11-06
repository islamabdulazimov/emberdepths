extends SceneTree
const Rules = preload("res://data/combat_rules.gd")
const Resources = preload("res://scripts/player_resources.gd")
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ", message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for players in range(1, 5):
  check_result(Rules.scaled_health(100, players) == [100, 125, 150, 175][players - 1], "Shared health multiplier for %d players" % players)
  check_result(Rules.scaled_health(45, players) == [45, 57, 68, 79][players - 1], "Fractional health rounds upward for %d players" % players)
 for players in range(1, 5):
  var boss = load("res://scripts/boss_state.gd").new()
  boss.begin(load("res://data/bosses.gd").ANDREW, players)
  check_result(boss.max_health == [360, 450, 540, 630][players - 1] and boss.max_poise == 90, "Andrew uses same scaling while poise stays unchanged for %d players" % players)
 check_result(Rules.scaled_health(100, 0) == 100 and Rules.scaled_health(100, 9) == 175, "Player count is constrained to 1–4")
 var resources = Resources.new()
 resources.health = 40
 check_result(resources.health == 40 and resources.heal(100) == 60, "Health only restores by healing and never exceeds maximum")
 check_result(resources.spend_mana(20) and resources.mana == 30 and not resources.spend_mana(31), "Mana spend rejects insufficient reserve")
 check_result(resources.restore_mana(100) == 20 and resources.mana == 50, "Mana restoration respects maximum")
 var legacy:Dictionary=resources.snapshot()
 legacy.merge({"stamina":0,"max_stamina":140,"stamina_delay":0.8})
 resources.apply(legacy)
 check_result(not resources.snapshot().has("stamina") and resources.health==100 and resources.mana==50,"Legacy stamina is ignored while health and mana remain")
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.spawning_enabled = false
 var combat = main.combat
 var actor: int = combat.spawn_entity("ashling", Vector2(1600, 300))
 for id in range(2, 5):
  main.add_player(id, Vector2(1500 + id * 16, 300))
  main.get_node("Players").get_node(str(id)).set_physics_process(false)
 main.get_node("Players/2").dead = true
 var scaled: int = combat.spawn_entity("ashling", Vector2(1650, 300))
 check_result(combat.entities[scaled].max_health == 79 and combat.entities[actor].max_health == 45, "Dead connected player counts and existing mobs never rescale on join")
 var ghost: int = combat.spawn_entity("spirit", Vector2(1700,300), Vector2(1700,300))
 combat.hit_entity(ghost,9999,Vector2.RIGHT)
 var first_ghost_hit: bool = combat.entities.has(ghost) and combat.entities[ghost].health == 2 and combat.entities[ghost].max_health == 4
 combat.hit_entity(ghost,1,Vector2.RIGHT)
 check_result(first_ghost_hit and not combat.entities.has(ghost), "Four-player spirit scales visible health yet still needs exactly two hits")
 var state: Dictionary = combat.entity_data(scaled)
 main.remove_player(4)
 var next: int = combat.spawn_entity("ashling", Vector2(1690, 300))
 check_result(combat.entities[next].max_health == 68 and combat.entities[scaled].max_health == 79, "Disconnect affects only new spawns")
 combat.set_entity(scaled, state)
 check_result(combat.entities[scaled].max_health == 79 and combat.entities[scaled].health == 79, "Replication restores frozen maximum without multiplying it again")
 check_result(combat.enemy_speed("ashling") == 34 and Rules.ENEMIES.ashling.day_damage == 14, "Scaling leaves speed and damage unchanged")
 main.items.local_inventory().add("stone_blade", 1)
 main.items.attack_ready_at[1] = 0
 check_result(main.items.swing(main.player, 0, Vector2.RIGHT) and not main.items.swing(main.player,0,Vector2.RIGHT), "Weapon needs no stamina but keeps its phase lock")
 combat.tick_fighter(main.player,0.5)
 check_result(main.items.use_primary(main.player, Vector2i(96,22),9), "Mining remains independent of combat resource costs")
 main.player.resources.mana = 7
 combat.respawn(main.player)
 check_result(main.player.health == 100 and main.player.resources.mana == 50, "Respawn restores health and mana")
 main.player.resources.max_health = 120
 main.player.resources.max_mana = 70
 main.player.resources.health = 90
 main.player.resources.mana = 15
 var life: Dictionary = combat.player_data(main.player)
 main.player.resources.reset_full()
 combat.apply_player_state(1, life)
 check_result(main.player.health == 90 and main.player.resources.max_health == 120 and main.player.resources.mana == 15 and main.player.resources.max_mana == 70 and not life.has("stamina"), "Life snapshot restores all current and maximum resource values")
 main.get_node("HUD/PlayerResources")._process(0)
 check_result(main.get_node("HUD/PlayerResources").labels[0].text == "ОЗ 90/120" and main.get_node("HUD/PlayerResources").labels[1].text == "МП 15/70", "HUD reads local player state and maximums")
 print("Resource/scaling failures: ", failures)
 quit(1 if failures else 0)
