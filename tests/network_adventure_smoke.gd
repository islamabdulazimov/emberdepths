extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var role:String=OS.get_cmdline_user_args()[0]
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.interaction.set_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.player.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false
 var admissions:=[0];var remote:=[0];var stable:=[""];var saw_roll:=false;var rejoined:=false;var phase:=0;var clock:=Time.get_ticks_msec();var phase_at:=clock;var previous:=clock
 if role=="host":
  for x in range(88,105):
   for y in range(12,22):main.world.apply_edit(Vector2i(x,y),-1)
   main.world.apply_edit(Vector2i(x,22),2)
  main.world.solid.update_internals()
  main.network.peer_admitted.connect(func(id):
   remote[0]=id;admissions[0]+=1
   var body=main.get_node("Players").get_node(str(id));body.set_physics_process(false)
   if admissions[0]==1:
    body.equipment.ability="traveler_knot";body.position=Vector2(1544,342);stable[0]=body.profile_id
   else:check(body.profile_id==stable[0] and body.equipment.ability=="traveler_knot" and body.roll_cooldown==6,"host restores same profile and roll cooldown after rejoin"))
  check(main.network.host_game()==OK,"adventure ENet host starts");print("ADVENTURE_HOST_READY")
 else:check(main.network.join_game("127.0.0.1")==OK,"adventure client starts")
 while Time.get_ticks_msec()-clock<(8000 if role=="host" else 6000):
  await process_frame
  var now:=Time.get_ticks_msec();var dt:=minf(.05,(now-previous)/1000.0);previous=now
  if not main.network.connected:continue
  if role=="host":
   var body=main.get_node("Players").get_node_or_null(str(remote[0]))
   if body!=null:
    saw_roll=saw_roll or body.fighter.mode=="roll"
    main.combat.tick_fighter(body,dt) # Deliberately freeze cooldown while observing reconnection.
  elif phase==0 and main.player.equipment.ability=="traveler_knot":
   check(not main.combat.start_defense(int(str(main.player.name)),"roll"),"client cannot authorize its own ability")
   main.network.defense_local("roll");phase=1
  elif phase==1:
   saw_roll=saw_roll or main.player.fighter.mode=="roll"
   if saw_roll and main.player.fighter.mode=="idle":
    check(main.player.roll_cooldown>5,"client receives authoritative ability cooldown")
    await main.network.stop()
    check(main.player.equipment.ability=="","leaving restores own local world instead of importing host gear")
    await create_timer(.25).timeout
    main.network.join_game("127.0.0.1");phase=2
  elif phase==2 and main.player.equipment.ability=="traveler_knot":
   check(main.player.roll_cooldown>5,"rejoin snapshot retains remaining cooldown")
   main.network.defense_local("roll");phase_at=now;phase=3
  elif phase==3 and now-phase_at>450:
   check(main.player.fighter.mode=="idle" and main.player.roll_cooldown>4,"server rejects cooldown bypass after reconnect")
   rejoined=true;phase=4
 if role=="host":check(admissions[0]==2 and saw_roll,"host observes one roll and two admissions for same character")
 else:check(rejoined,"client completes ability disconnect and rejoin flow")
 await main.network.stop();await create_timer(.2).timeout;main.queue_free();await process_frame
 print("NETWORK_ADVENTURE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
