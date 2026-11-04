extends SceneTree
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ", message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.spawning_enabled = false
 main.encounter.enabled = false
 for i in range(90): await physics_frame
 main.player.set_physics_process(false)
 for i in range(3):
  var id: int = main.combat.spawn_entity("ashling", Vector2(1700, 300))
  main.combat.hit_entity(id, 100000, Vector2.RIGHT)
 check_result(main.encounter.kills == 3 and main.encounter.pending and not main.encounter.used_once, "Three actual normal kills schedule one shared boss")
 var spirit: int = main.combat.spawn_entity("spirit", Vector2(1700, 300), Vector2(1700, 300))
 main.combat.hit_entity(spirit, 1000, Vector2.RIGHT)
 main.combat.hit_entity(spirit, 1000, Vector2.RIGHT)
 check_result(main.encounter.kills == 3, "Spirit does not increase ordinary kill counter")
 for x in range(75, 118):
  for y in range(72): main.world.apply_edit(Vector2i(x,y), 2)
 main.encounter.enabled = true
 check_result(not main.encounter.try_spawn() and main.encounter.pending and not main.encounter.used_once, "Blocked spawn retries without consuming or duplicating Andrew")
 main.world.generate()
 main.add_player(2, Vector2(1544, 342))
 main.add_player(3, Vector2(1544, 342))
 main.get_node("Players/2").set_physics_process(false)
 main.get_node("Players/3").set_physics_process(false)
 main.get_node("Players/3").dead = true
 check_result(main.encounter.try_spawn(), "Boss starts once a free large footprint exists")
 var actor = main.encounter.actor
 actor.set_physics_process(false)
 check_result(main.encounter.state.max_health == 540 and main.encounter.state.max_poise == 90, "Boss start counts dead connected player and scales health only")
 check_result(actor.phase == "intro" and actor.phase_duration == 2.2 and not actor.indicator_active, "Spawn starts safe double-biceps intro")
 main.boss_ui.refresh()
 check_result(main.boss_ui.visible and main.boss_ui.title.text.begins_with("Andrew"), "Andrew binds reusable boss interface")
 main.add_player(4, Vector2(1544, 342))
 main.remove_player(4)
 check_result(actor.state.max_health == 540 and actor.state.scaling_players == 3, "Boss health remains frozen on join and disconnect")
 actor.indicator_active = true
 actor.locked_target = Vector2(1600, 352)
 var stale: Dictionary = actor.snapshot()
 stale.erase("state")
 for i in range(5): actor.take_hit(18, 18)
 check_result(actor.phase == "stunned" and actor.state.poise == 0 and not actor.indicator_active and actor.locked_target == Vector2.ZERO, "Broken poise interrupts phase and clears attack markers")
 main.encounter.apply_motion(stale)
 check_result(actor.phase == "stunned" and not actor.indicator_active, "Old network motion cannot revive attack markers after interruption")
 actor.phase_elapsed = 0.8
 var before: int = actor.state.health
 actor.take_hit(18, 18)
 check_result(actor.phase_elapsed == 0.8 and actor.state.health == before - 18 and actor.state.poise == 0, "Hits during stun deal normal damage without extending stun")
 actor._physics_process(1.19)
 check_result(actor.phase == "stunned", "Stun remains until full two seconds")
 actor._physics_process(0.02)
 check_result(actor.phase == "chase" and actor.state.poise == 90, "Stun ends after two seconds and restores all poise")
 actor.take_hit(100000, 1)
 check_result(main.encounter.actor == null and not main.boss_ui.visible, "Boss death ends fight and hides interface")
 for i in range(5): main.encounter.register_kill("ashling")
 check_result(not main.encounter.try_spawn() and main.encounter.used_once, "Further kills never create second Andrew in same run")
 main.encounter.reset_run()
 main.encounter.pending = true
 check_result(main.encounter.try_spawn(), "New test world may start a fresh encounter")
 main.combat.damage_player(1, 1000, main.player.position, true)
 check_result(main.encounter.actor == null and not main.boss_ui.visible and main.encounter.used_once, "Participant death cancels encounter and prevents respawn of boss")
 print("Andrew base failures: ", failures)
 quit(1 if failures else 0)
