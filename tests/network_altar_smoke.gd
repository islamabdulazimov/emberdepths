extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var role:=OS.get_cmdline_user_args()[0]
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.interaction.set_process(false);main.combat.spawning_enabled=false;main.exploration.set_process(false);main.survival.set_physics_process(false);main.encounter.set_physics_process(false);main.player.set_physics_process(false)
 var e=main.encounter;var admitted:Array=[];var peers:={}
 if role=="host":
  for x in range(65,128):
   for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
   for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
  e.journal.altar=Vector2(1544,416);main.player.position=Vector2(1544,406)
  main.network.peer_admitted.connect(func(id):
   admitted.append(id);var p=main.get_node("Players").get_node(str(id));p.position=Vector2(1544+admitted.size()*12,406);p.set_physics_process(false)
   if admitted.size()==1:main.items.inventory_for(id).add("andrew_seal",1);peers.fighter=id
   else:peers.observer=id)
  check(main.network.host_game()==OK,"altar host starts")
  e.choose(1,"join");e.choose(1,"ready");print("ALTAR_HOST_READY")
 else:main.network.join_game("127.0.0.1")
 var started:=Time.get_ticks_msec();var voted:=false;var saw_first:=false;var saw_second:=false;var done:=false;var ended_first:=false;var paid_at:=0
 while Time.get_ticks_msec()-started<14000:
  await process_frame
  if not main.network.connected:continue
  if role!="host" and not voted:
   voted=true
   main.network.altar_local("join" if role=="fighter" else "skip")
   await create_timer(.25).timeout
   if role=="fighter":main.network.altar_local("ready")
  if role=="host":
   if admitted.size()==2 and e.journal.sequence==0:
    var id:int=peers.fighter;var p=main.get_node("Players").get_node(str(id))
    if e.choices.get(p.profile_id,{}).get("ready",false) and e.choices.size()==3:
     check(e.choose(1,"start")=="","host starts with ready fighter and explicit spectator")
     e.actor.set_physics_process(false)
     check(e.state.max_health==450 and e.journal.last.participants.size()==2,"network health counts two participants out of three peers")
     print("ALTAR_FIRST_READY")
   if e.journal.sequence==1 and not ended_first and Time.get_ticks_msec()-started>2500:
    ended_first=true;e.end_fight("player_died");e.choose(1,"join");e.choose(1,"ready")
   if e.journal.sequence==2 and paid_at==0:
    paid_at=Time.get_ticks_msec();e.actor.set_physics_process(false)
    check(main.items.inventory_for(peers.fighter).count_item("andrew_seal")==0 and main.items.inventory_for(1).count_item("andrew_seal")==0,"remote owner pays one seal; host never pays")
    check(e.state.max_health==450 and e.state.max_poise==90,"paid repeat uses same participant-only health and poise")
    var p=main.get_node("Players").get_node(str(peers.observer))
    check(not e.can_damage(p.profile_id),"spectator cannot damage server boss")
   if paid_at>0 and Time.get_ticks_msec()-paid_at>1000 and is_instance_valid(e.actor):e.end_fight("defeated")
   if paid_at>0 and Time.get_ticks_msec()-paid_at>1800:done=true;break
  else:
   if e.journal.sequence==1 and e.journal.last.get("status","")=="active" and not saw_first:
    saw_first=true;check(is_instance_valid(e.actor) and e.state.max_health==450,"client sees first boss, journal and correct shared health")
    check(e.journal.free_used and e.journal.last.participants.size()==2,"client receives world-owned free charge and stable participants")
   if role=="fighter" and ended_first==false and e.journal.sequence==1 and e.journal.last.get("status","")=="player_died":
    ended_first=true;main.network.altar_local("join");await create_timer(.25).timeout;main.network.altar_local("ready");await create_timer(.25).timeout
    main.network.altar_local("start");main.network.altar_local("start")
   if e.journal.sequence==2 and not saw_second:
    saw_second=true;check(e.journal.last.id=="andrew:2" and is_instance_valid(e.actor),"remote start produces exactly one second attempt")
    if role=="fighter":check(main.items.local_inventory().count_item("andrew_seal")==0,"remote inventory confirms exactly one paid seal")
   if e.journal.sequence==2 and e.journal.last.get("status","")=="defeated":
    check(e.actor==null and not main.combat_zone.active,"victory snapshot removes boss and unlocks local arena")
    done=saw_first and saw_second;break
 check(done,"network altar scenario completes on "+role)
 await main.network.stop();main.queue_free();await process_frame
 print("ALTAR_NETWORK_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
