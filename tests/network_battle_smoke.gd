extends SceneTree
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
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
 main.combat.set_physics_process(false)
 main.encounter.enabled = false
 main.items.set_physics_process(false)
 main.player.set_physics_process(false)
 var duelist := [0]
 var enemy_id := 1
 if role == "host":
  for x in range(88,106):
   for y in range(18,22): main.world.apply_edit(Vector2i(x,y),-1)
   main.world.apply_edit(Vector2i(x,22),2)
  main.world.solid.update_internals()
  main.player.position = Vector2(1448,342)
  enemy_id = main.combat.spawn_entity("ashling",Vector2(1572,352))
  main.network.peer_admitted.connect(func(id):
   var body = main.get_node("Players").get_node(str(id))
   body.set_physics_process(false)
   if duelist[0] == 0:
    duelist[0] = id
    body.position = Vector2(1544,342)
    main.items.inventory_for(id).add("stone_blade",1)
    print("DUELIST_ADMITTED")
   else: body.position = Vector2(1416,342))
  check_result(main.network.host_game() == OK,"Battle host starts existing ENet transport")
  print("BATTLE_HOST_READY")
 else: main.network.join_game("127.0.0.1")
 var start := Time.get_ticks_msec()
 var previous := start
 var phase := 0
 var saw_roll := false
 var saw_parry := false
 var saw_windup := false
 var saw_hit := false
 var guarded := false
 var roll_checked := false
 var parry_checked := false
 var windup_checked := false
 var final_stats := false
 while Time.get_ticks_msec()-start < (7500 if role == "host" else 6000):
  await process_frame
  var now := Time.get_ticks_msec()
  var delta := minf(0.05,float(now-previous)/1000)
  previous = now
  if not main.network.active or not main.network.connected: continue
  if role == "host":
   for body in main.get_node("Players").get_children(): main.combat.tick_fighter(body,delta)
  var actor = null
  if role == "host" and duelist[0] > 0: actor = main.get_node("Players").get_node_or_null(str(duelist[0]))
  elif role == "duelist": actor = main.player
  else:
   for body in main.get_node("Players").get_children():
    if body != main.player and str(body.name) != "1": actor = body
  if actor == null or not main.combat.entities.has(enemy_id): continue
  var enemy = main.combat.entities[enemy_id]
  saw_roll = saw_roll or actor.fighter.mode == "roll"
  saw_parry = saw_parry or actor.fighter.mode == "parry_success"
  saw_windup = saw_windup or actor.fighter.phase() == "attack_windup"
  saw_hit = saw_hit or enemy.health == 21
  if role == "host":
   final_stats = final_stats or (saw_hit and actor.fighter.mode == "idle" and actor.health == 100 and actor.resources.stamina == 44)
   if actor.fighter.roll_invulnerable() and not roll_checked:
    roll_checked = true
    check_result(main.combat.receive_attack(duelist[0],22,enemy.position,enemy) == "dodged" and actor.health == 100 and actor.resources.stamina == 76,"Host validates remote roll stamina and actual hit avoidance")
   if actor.fighter.parry_open() and not parry_checked:
    parry_checked = true
    check_result(main.combat.receive_attack(duelist[0],14,enemy.position,enemy) == "parried" and enemy.attack_state == "stagger" and actor.resources.stamina == 62,"Host resolves remote parry and enemy stagger")
   if actor.fighter.phase() == "attack_windup" and not windup_checked:
    windup_checked = true
    check_result(enemy.health == 45,"Remote attack cannot damage before its active phase")
  elif role == "duelist":
   if not guarded:
    guarded = true
    check_result(not main.combat.start_defense(int(str(main.player.name)),"roll") and not main.items.swing(main.player,0,Vector2.RIGHT),"Client cannot grant its own defense damage or stamina changes")
   if phase == 0 and main.get_node("Players").get_child_count() == 3:
    main.network.defense_local("roll")
    phase = 1
   elif phase == 1 and saw_roll and actor.fighter.mode == "idle":
    main.network.defense_local("parry")
    phase = 2
   elif phase == 2 and saw_parry and actor.fighter.mode == "idle": phase = 3
   if phase == 3:
    main.network.submit_local(0,false,Vector2i(98,21),0 if saw_hit else 1,0,1.0/30)
 check_result(saw_roll and saw_parry and saw_windup and saw_hit,"Roll parry and phased melee replicate to "+role)
 if role == "host":
  check_result(roll_checked and parry_checked and windup_checked and final_stats,"Server spends each action once and prevents defensive damage")
  check_result(main.items.local_inventory().count_item("stone_blade") == 0 and main.player.health == 100,"Remote actions preserve cooperative host inventory and health")
 check_result(main.combat.entities[enemy_id].health == 21,"One remote active swing produces one hit on "+role)
 print("Network battle ",role," failures: ",failures)
 quit(1 if failures else 0)
