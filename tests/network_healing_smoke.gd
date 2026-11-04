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
 main.combat.spawning_enabled = false
 main.player.set_physics_process(false)
 var fixture_profile := [""]
 if role == "host":
  main.network.peer_admitted.connect(func(id):
   var body = main.get_node("Players").get_node(str(id))
   body.set_physics_process(false)
   if fixture_profile[0] == "":
    fixture_profile[0] = body.profile_id
    body.health = 40
    main.items.inventory_for(id).add("wood",2)
    main.items.inventory_for(id).add("emberstone",1))
  check_result(main.network.host_game() == OK,"Healing host starts")
 else: main.network.join_game("127.0.0.1")
 var start := Time.get_ticks_msec()
 var crafted := false
 var checked_guard := false
 var saw_progress := false
 var interrupted := false
 var first_heal_time := -1.0
 var saw_second := false
 var first_empty_tick := 0
 var left_once := false
 var rejoining := false
 var reconnect_checked := false
 var saw_late := false
 var cursor_tick := 0
 var dirt_cell := Vector2i(96,22)
 while Time.get_ticks_msec()-start < (16000 if role == "host" else (13000 if role == "healer" else 12000)):
  await process_frame
  if rejoining and not main.network.active:
   rejoining = false
   main.network.join_game("127.0.0.1")
   continue
  if not main.network.active or not main.network.connected: continue
  if role == "host":
   for body in main.get_node("Players").get_children():
    if body.profile_id != fixture_profile[0]: continue
    if body.medicine_progress > 0: saw_progress = true
    if body.medicine_progress > 0.3 and not interrupted:
     interrupted = true
     main.combat.damage_player(int(str(body.name)),10,body.position-Vector2(10,0))
     body.velocity = Vector2.ZERO
     check_result(body.health == 30 and body.medicine_progress == 0 and main.items.inventory_for(int(str(body.name))).count_item("spark_balm") == 2,"Server damage interrupts use without spending a portion")
    if body.health == 60 and first_heal_time < 0:
     first_heal_time = main.combat.world_time
     check_result(body.medicine_cooldown > 5.8 and main.items.inventory_for(int(str(body.name))).count_item("spark_balm") == 1,"First server heal consumes one portion and starts cooldown")
     print("HEALED")
    if body.health == 90 and not saw_second:
     saw_second = true
     check_result(main.combat.world_time-first_heal_time >= 6.9,"Held commands cannot skip cooldown or second preparation")
  elif role == "healer":
   var bag = main.items.local_inventory()
   if not crafted:
    main.network.craft_local("spark_balm")
    crafted = true
   if bag.count_item("spark_balm") > 0 and not checked_guard:
    checked_guard = true
    check_result(not main.items.medicine_step(main.player,0,100) and main.player.health == 40 and bag.count_item("spark_balm") == 2,"Client cannot grant healing or advance authoritative use locally")
   if main.player.medicine_progress > 0: saw_progress = true
   if bag.count_item("spark_balm") == 0 and main.player.health == 90:
    if first_empty_tick == 0: first_empty_tick = Time.get_ticks_msec()
    if not left_once and Time.get_ticks_msec()-first_empty_tick > 850:
     check_result(main.world.block_at(dirt_cell) == 0,"Holding the last portion never turns into accidental mining")
     left_once = true
     main.network.stop()
     await create_timer(0.4).timeout
     check_result(main.player.health == 100 and main.player.medicine_cooldown == 0 and main.items.local_inventory().count_item("spark_balm") == 0,"Leaving restores own health and cooldown without importing server medicine")
     rejoining = true
     continue
    if left_once and not reconnect_checked and main.player.medicine_cooldown > 0:
     reconnect_checked = true
     check_result(main.player.health == 90 and main.player.medicine_cooldown > 3 and bag.count_item("spark_balm") == 0,"Reconnect preserves server cooldown health and consumed count")
   cursor_tick += 1
   var aim := dirt_cell if first_empty_tick > 0 else (Vector2i(-20,8) if cursor_tick%2 == 0 else Vector2i(180,40))
   main.network.submit_local(0,false,aim,0 if left_once else 1,0,1.0/60.0)
  else:
   for body in main.get_node("Players").get_children():
    if body != main.player and body.health == 60 and body.medicine_cooldown > 0 and not saw_late:
     saw_late = true
     check_result(body.medicine_progress == 0,"Late join receives cooldown without restarting a completed use")
    if body != main.player and body.medicine_progress > 0: saw_progress = true
    if body != main.player and body.health == 90: saw_second = true
 if role == "host":
  check_result(interrupted and first_heal_time >= 0 and saw_second,"Both server-authoritative heals finish after interruption")
  check_result(main.player.health == 100 and main.player.medicine_cooldown == 0,"Another player's medicine never heals or locks the host")
  check_result(main.world.block_at(dirt_cell) == 0,"Host terrain remains intact after held empty slot")
 elif role == "healer":
  check_result(checked_guard and reconnect_checked,"Healer completes craft use and reconnect scenario")
  check_result(main.player.resources.stamina == 100 and main.player.resources.mana == 50,"Healing leaves remote stamina and mana unchanged")
 else:
  check_result(saw_late and saw_second,"Observer sees initial healed state and later shared health change")
  check_result(main.items.local_inventory().count_item("spark_balm") == 0 and main.player.health == 100,"Observer retains independent inventory and health")
 check_result(saw_progress,"Shared player model renders medicine progress on "+role)
 print("Healing network ",role," failures: ",failures)
 quit(1 if failures else 0)
