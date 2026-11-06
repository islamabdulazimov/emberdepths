extends SceneTree
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ", message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var role := OS.get_cmdline_user_args()[0]
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.spawning_enabled = false
 main.player.resources.max_health = 1000
 main.player.health = 1000
 var admitted: Array = []
 var probes: Dictionary = {}
 if role == "host":
  main.network.peer_admitted.connect(func(id):
   admitted.append(id)
   var body = main.get_node("Players").get_node(str(id))
   body.resources.max_health = 1000
   body.resources.health = 1000
   if admitted.size() == 1:
    main.items.inventory_for(id).add("stone_blade",1)
    main.items.inventory_changed.emit(id)
   else:
    body.position = main.world.safe_spawn_position(35 + admitted.size() * 3)
    var count: int = main.combat.connected_player_count()
    probes[count] = main.combat.spawn_entity("ashling", main.world.safe_spawn_position(120 + count)))
  check_result(main.network.host_game() == OK, "Boss test host starts")
  print("HOST_READY")
 else:
  main.network.join_game("127.0.0.1")
 var start := Time.get_ticks_msec()
 var summoned := false
 var signalled := false
 var had_four := false
 var super_forced := false
 var terminal_set := false
 var finished := false
 var finish_at := 0
 var saw_frozen := false
 var saw_stun := false
 var saw_super := false
 var saw_regen := false
 var saw_private_hud := false
 var saw_three := false
 var saw_four_mob := false
 var saw_after_leave := false
 var checked_client := false
 var marker := Vector2.ZERO
 var marker_checked := false
 while Time.get_ticks_msec() - start < 18000:
  await process_frame
  if not main.network.active or not main.network.connected: continue
  var actor = main.encounter.actor
  if is_instance_valid(actor):
   saw_frozen = saw_frozen or actor.state.max_health == 450
   if actor.state.max_health != 450:
    check_result(false,"Active boss health must remain frozen at two-player maximum")
    break
   saw_stun = saw_stun or actor.phase == "stunned"
   if actor.phase == "super_windup":
    if not saw_super: marker = actor.locked_target
    saw_super = true
    if not marker_checked:
     check_result(actor.locked_target == marker and actor.indicator_active, "Super target remains fixed during network telegraph")
     marker_checked = true
    elif actor.locked_target != marker:
     check_result(false, "Telegraph must never follow moving target")
   main.boss_ui.refresh()
   main.get_node("HUD/PlayerResources")._process(0)
   saw_private_hud = saw_private_hud or (main.boss_ui.health_bar.max_value == 450 and main.get_node("HUD/PlayerResources").bars[0].max_value == 1000)
  for enemy in main.combat.entities.values():
   saw_three = saw_three or (enemy.scaling_players == 3 and enemy.max_health == 68)
   saw_four_mob = saw_four_mob or (enemy.scaling_players == 4 and enemy.max_health == 79)
  if saw_four_mob and main.get_node("Players").get_child_count() == 3 and is_instance_valid(actor):
   saw_after_leave = actor.state.max_health == 450
  if role == "host":
   if not summoned and admitted.size() == 1 and Time.get_ticks_msec() - start > 800:
    for i in range(3):
     var id: int = main.combat.spawn_entity("ashling",main.world.safe_spawn_position(120))
     main.combat.hit_entity(id,100000,Vector2.RIGHT)
    check_result(main.encounter.try_spawn(), "Three server kills summon Andrew")
    actor = main.encounter.actor
    actor.state.poise = 36 # Shorten only this network fixture's stagger setup.
    main.encounter.publish()
    summoned = true
   if is_instance_valid(actor):
    if actor.phase == "stunned" and not signalled:
     print("BOSS_READY")
     signalled = true
    had_four = had_four or main.get_node("Players").get_child_count() == 4
    if had_four and saw_stun and actor.phase == "chase" and not super_forced:
     super_forced = true
     actor.start_attack("super",main.get_node("Players").get_node(str(admitted[0])))
    if super_forced and actor.phase == "super_recovery" and not terminal_set:
     actor.state.health = 18 # Finish fixture without a long damage-sponge fight.
     actor.state.poise = 90
     main.encounter.publish()
     terminal_set = true
    if had_four and main.get_node("Players").get_child_count() == 3 and not probes.has(23):
     probes[23] = main.combat.spawn_entity("ashling",main.world.safe_spawn_position(127))
   elif terminal_set:
    if not finished:
     finished = true
     finish_at = Time.get_ticks_msec()
     for i in range(3): main.encounter.register_kill("ashling")
    if Time.get_ticks_msec() - finish_at > 600: break
   continue
  if is_instance_valid(actor) and not checked_client:
   var hp: int = actor.state.health
   check_result(not actor.take_hit(999999,999999) and actor.state.health == hp, "Client cannot apply boss damage locally")
   checked_client = true
  if role == "fighter":
   var axis := 0.0
   var mode := 0
   var cell := Vector2i.ZERO
   if is_instance_valid(actor):
    cell = main.world.cell_at(actor.position + Vector2(0,-29))
    if actor.phase == "super_windup":
     axis = -1
    elif not saw_stun or actor.state.health <= 18:
     if absf(actor.position.x - main.player.position.x) > 36:
      axis = signf(actor.position.x - main.player.position.x)
     else: mode = 1
    saw_regen = saw_regen or main.player.fighter.mode=="attack"
   main.network.submit_local(axis,false,cell,mode,0,1.0/60.0)
  elif role == "leaver" and saw_super and saw_four_mob:
   check_result(saw_frozen and saw_stun and saw_private_hud, "Late participant sees frozen boss and own independent resource HUD")
   await main.network.stop()
   print("Boss network leaver failures: ",failures)
   quit(1 if failures else 0)
   return
  if main.encounter.used_once and not is_instance_valid(actor) and saw_super:
   finished = true
   break
 check_result(saw_frozen and saw_stun and saw_super, "Boss health stagger and telegraph synchronize to " + role)
 check_result(saw_private_hud, "Player resources and boss health remain distinct on " + role)
 check_result(finished and main.encounter.used_once and not main.boss_ui.visible, "Boss death hides shared UI and prevents duplicate summon on " + role)
 if role in ["host","observer"]:
  check_result(saw_three and saw_four_mob and saw_after_leave, "New mobs scale for current three/four players while existing boss stays unchanged")
 if role == "fighter": check_result(saw_regen, "Server-authoritative attack phases reach fighter")
 print("Boss network ",role," failures: ",failures)
 quit(1 if failures else 0)
