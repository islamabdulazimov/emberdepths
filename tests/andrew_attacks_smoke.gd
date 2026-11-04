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
 for i in range(90): await physics_frame
 main.player.set_physics_process(false)
 main.player.resources.max_health = 1000
 main.player.health = 1000
 main.encounter.pending = true
 check_result(main.encounter.try_spawn(), "Attack test creates boss on free terrain")
 main.combat_zone.unlock() # Geometry unit fixture deliberately repositions bodies beyond a live arena.
 var actor = main.encounter.actor
 actor.set_physics_process(false)
 main.encounter.enabled = false
 actor.position = Vector2(1608,352)
 var player = main.player
 player.position = Vector2(1632,342)
 actor._physics_process(1.0)
 check_result(player.health == 1000 and actor.phase == "intro", "Intro does not attack")
 actor.enter_phase("chase",0)
 actor.start_attack("uppercut",player)
 actor._physics_process(0.59)
 check_result(player.health == 1000 and actor.phase == "uppercut_windup", "Uppercut gives visible damage-free preparation")
 actor._physics_process(0.02)
 actor._physics_process(0.01)
 check_result(player.health == 978 and player.velocity.y == -220, "Uppercut damages and launches player upward")
 player.hurt_immunity = 0
 actor._physics_process(0.01)
 check_result(player.health == 978, "Uppercut never damages same player twice per attack")
 actor._physics_process(0.2)
 var health: int = player.health
 actor._physics_process(0.5)
 check_result(actor.phase == "uppercut_recovery" and player.health == health, "Uppercut has safe recovery window")
 actor.position = Vector2(1608,352)
 player.position = Vector2(1632,342)
 player.health = 1000
 player.hurt_immunity = 0
 actor.start_attack("backflip",player)
 var start_x: float = actor.position.x
 for i in range(20): actor._physics_process(1.0/60.0)
 check_result(actor.position.x < start_x and player.health == 1000, "Backflip changes distance without contact damage")
 actor.position = Vector2(1608,352)
 player.position = Vector2(1632,342)
 actor.start_attack("spin",player)
 actor._physics_process(0.84)
 check_result(player.health == 1000, "Spin telegraph is harmless")
 actor._physics_process(0.02)
 actor._physics_process(0.01)
 check_result(player.health == 975, "Spin damages inside circular zone")
 player.hurt_immunity = 0
 actor._physics_process(0.01)
 check_result(player.health == 975, "Spin damage is per execution rather than per frame")
 actor.position = Vector2(1608,352)
 player.position = Vector2(1544,342)
 player.health = 1000
 player.hurt_immunity = 0
 actor.start_attack("super",player)
 var locked: Vector2 = actor.locked_target
 var marker: Rect2 = actor.attack_rect("super")
 player.position.x += 100
 actor._physics_process(0.1)
 actor._damage_players("super")
 check_result(actor.locked_target == locked and actor.indicator_active and player.health == 1000, "Super target locks before jump and preparation causes no damage")
 check_result(marker.size == Vector2(96,40) and marker.position == locked + Vector2(-48,-40), "Ground warning matches exact configured impact rectangle")
 player.position = Vector2(1544,342)
 actor.set_physics_process(true)
 var saw_impact := false
 for i in range(180):
  await physics_frame
  if actor.phase == "super_impact" and actor.impact_emitted:
   saw_impact = true
   break
 actor.set_physics_process(false)
 check_result(saw_impact and actor.position.distance_to(locked) <= 14 and player.health == 966, "Real ballistic jump lands in announced zone and deals one impact")
 check_result(actor.attack_rect("super") == marker, "Impact geometry remains the originally announced rectangle")
 actor.hit_targets.clear()
 player.hurt_immunity = 0
 player.position = locked + Vector2(54,-10)
 actor._damage_players("super")
 check_result(player.health == 966, "Player beyond visible impact zone is safe")
 player.position = locked + Vector2(47,-10)
 actor._damage_players("super")
 player.hurt_immunity = 0
 actor._damage_players("super")
 check_result(player.health == 932, "Visible impact edge damages once and never repeats every frame")
 actor.position = Vector2(1608,352)
 player.position = Vector2(1544,342)
 actor.start_attack("super",player)
 actor.take_hit(1, actor.state.max_poise)
 var before: Vector2 = actor.position
 health = player.health
 actor._damage_players("super")
 actor._physics_process(1.0)
 actor.take_hit(1,90)
 check_result(actor.phase == "stunned" and actor.phase_elapsed == 1.0 and not actor.indicator_active and actor.position == before and player.health == health, "Stun interrupts super without residual warning damage motion or duration extension")
 actor._physics_process(1.01)
 check_result(actor.phase == "chase" and actor.state.poise == 90, "Interrupted super cannot resume after stagger recovery")
 # A tall wall blocks the arc. No damage may move to an unannounced landing.
 for y in range(14,22): main.world.apply_edit(Vector2i(98,y),2)
 main.world.solid.update_internals()
 for i in range(2): await physics_frame
 actor.position = Vector2(1608,352)
 player.position = Vector2(1544,342)
 player.health = 1000
 player.hurt_immunity = 0
 actor.start_attack("super",player)
 actor.set_physics_process(true)
 var cancelled := false
 for i in range(200):
  await physics_frame
  if actor.phase == "super_recovery":
   cancelled = true
   break
 actor.set_physics_process(false)
 check_result(cancelled and not actor.indicator_active and player.health == 1000 and actor.position.x > 1584, "Obstructed jump respects solid wall and cancels unannounced impact")
 actor.attack_index = 0
 actor._choose_attack(player)
 var first: String = actor.action_history.back()
 actor._choose_attack(player)
 check_result(first == "backflip" and actor.action_history.back() == "super", "Blocked approach changes tactics instead of endless punches into wall")
 actor.take_hit(100000,0)
 check_result(main.encounter.actor == null and not main.boss_ui.visible, "Boss death removes all attack zones and interface")
 print("Andrew attack failures: ", failures)
 quit(1 if failures else 0)
