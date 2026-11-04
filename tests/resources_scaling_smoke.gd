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
 check_result(Rules.scaled_health(100, 0) == 100 and Rules.scaled_health(100, 9) == 175, "Player count is constrained to 1–4")
 var resources = Resources.new()
 resources.health = 40
 resources.tick(30)
 check_result(resources.health == 40 and resources.heal(100) == 60, "Health only restores by healing and never exceeds maximum")
 check_result(resources.spend_mana(20) and resources.mana == 30 and not resources.spend_mana(31), "Mana spend rejects insufficient reserve")
 check_result(resources.restore_mana(100) == 20 and resources.mana == 50, "Mana restoration respects maximum")
 check_result(resources.spend_stamina(20), "Stamina action can begin with sufficient reserve")
 resources.tick(0.5)
 check_result(resources.stamina == 80, "Stamina waits before regeneration")
 resources.set_continuous_use("future_sprint", true)
 resources.tick(5)
 check_result(resources.stamina == 80, "Continuous use prevents regeneration")
 resources.set_continuous_use("future_sprint", false)
 resources.tick(0.4)
 check_result(is_equal_approx(resources.stamina, 82.8), "Stamina regenerates only after remaining delay")
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
 var state: Dictionary = combat.entity_data(scaled)
 main.remove_player(4)
 var next: int = combat.spawn_entity("ashling", Vector2(1690, 300))
 check_result(combat.entities[next].max_health == 68 and combat.entities[scaled].max_health == 79, "Disconnect affects only new spawns")
 combat.set_entity(scaled, state)
 check_result(combat.entities[scaled].max_health == 79 and combat.entities[scaled].health == 79, "Replication restores frozen maximum without multiplying it again")
 check_result(combat.enemy_speed("ashling") == 34 and Rules.ENEMIES.ashling.day_damage == 14, "Scaling leaves speed and damage unchanged")
 main.items.local_inventory().add("stone_blade", 1)
 main.player.resources.stamina = 17
 main.items.attack_ready_at[1] = 0
 check_result(not main.items.swing(main.player, 0, Vector2.RIGHT) and main.player.swing_remaining == 0, "Insufficient stamina blocks attack before animation or damage")
 main.player.resources.stamina = 100
 check_result(main.items.swing(main.player, 0, Vector2.RIGHT) and main.player.resources.stamina == 82, "Existing weapon consumes configured stamina once")
 main.player.resources.stamina = 0
 check_result(main.player.swing_remaining > 0, "Started swing completes even if reserve then reaches zero")
 main.player.resources.mana = 7
 combat.respawn(main.player)
 check_result(main.player.health == 100 and main.player.resources.mana == 50 and main.player.resources.stamina == 100, "Respawn completely restores all three resources")
 main.player.resources.max_health = 120
 main.player.resources.max_mana = 70
 main.player.resources.max_stamina = 140
 main.player.resources.health = 90
 main.player.resources.mana = 15
 main.player.resources.stamina = 33
 var life: Dictionary = combat.player_data(main.player)
 main.player.resources.reset_full()
 combat.apply_player_state(1, life)
 check_result(main.player.health == 90 and main.player.resources.max_health == 120 and main.player.resources.mana == 15 and main.player.resources.max_mana == 70 and main.player.resources.stamina == 33 and main.player.resources.max_stamina == 140, "Life snapshot restores all current and maximum resource values")
 main.get_node("HUD/PlayerResources")._process(0)
 check_result(main.get_node("HUD/PlayerResources").labels[0].text == "ОЗ 90/120" and main.get_node("HUD/PlayerResources").labels[1].text == "МП 15/70", "HUD reads local player state and maximums")
 print("Resource/scaling failures: ", failures)
 quit(1 if failures else 0)
