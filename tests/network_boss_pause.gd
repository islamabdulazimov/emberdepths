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
 main.set_physics_process(false);main.interaction.set_process(false);main.combat.spawning_enabled=false;main.survival.set_physics_process(false);main.exploration.set_process(false);main.player.set_physics_process(false)
 var e=main.encounter;var joins:Array=[];var frozen:=[-1.0,-1.0,Vector2.ZERO]
 if role=="host":
  for x in range(65,128):
   for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
   for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
  e.journal.altar=Vector2(1544,416);main.player.position=Vector2(1304,406)
  main.network.peer_admitted.connect(func(id):
   joins.append(id);var p=main.get_node("Players").get_node(str(id));p.set_physics_process(false)
   if joins.size()==1:p.position=Vector2(1304,406);print("PAUSE_OBSERVER_READY")
   elif joins.size()==2:p.position=Vector2(1544,406);p.health=60
   else:
    check(p.health==60 and p.position==frozen[2],"reclaim preserves vulnerable body's exact position and health")
    check(p.hurt_immunity==frozen[1] and e.actor.phase_elapsed==frozen[0],"resume preserves immunity and boss phase without elapsed-time catchup")
    check(not e.returns.paused and e.state.health==99 and e.state.max_health==360,"real return resumes with old boss health and participant-only scale")
    print("PAUSE_RETURNED"))
  check(main.network.host_game()==OK,"pause host starts as nonparticipant");print("PAUSE_HOST_READY")
 else:main.network.join_game("127.0.0.1")
 var started:=Time.get_ticks_msec();var stage:=0;var voted:=false;var saw_pause:=false;var done:=false;var end_at:=0
 while Time.get_ticks_msec()-started<18000:
  await process_frame
  if not main.network.connected:continue
  if role=="host":
   if stage==0 and joins.size()==2:
    var p=main.get_node("Players").get_node(str(joins[1]))
    if e.choices.get(p.profile_id,{}).get("ready",false):
     check(e.choose(joins[1],"start")=="","sole fighter starts while host and observer skip")
     e.state.health=99;e.actor.enter_phase("stunned",999);stage=1
   elif stage==1 and e.returns.paused:
    var record:Dictionary=e.returns.offline.values()[0];var p=e.returns.body(record.id)
    frozen[0]=e.actor.phase_elapsed;frozen[1]=p.hurt_immunity;frozen[2]=p.position
    check(main.combat.connected_player_count()==2 and e.state.max_health==360,"two online observers do not affect boss scale or pause")
    stage=2;print("PAUSE_ACTIVE")
   elif stage==2 and joins.size()==2:
    check(e.actor.phase_elapsed==frozen[0],"paused boss phase stays frozen across network frames")
    stage=3
   elif stage==3 and joins.size()==3:end_at=Time.get_ticks_msec();stage=4
   elif stage==4 and Time.get_ticks_msec()-end_at>800:e.end_fight("defeated");end_at=Time.get_ticks_msec();stage=5
   elif stage==5 and Time.get_ticks_msec()-end_at>600:done=true;break
  elif role=="first":
   if not voted:
    voted=true;main.network.altar_local("join");await create_timer(.25).timeout;main.network.altar_local("ready")
   if is_instance_valid(e.actor) and e.state.health==99:await create_timer(.2).timeout;done=true;break
  elif role=="return":
   if is_instance_valid(e.actor) and not e.returns.paused:
    check(main.player.health==60 and e.state.health==99,"returning client gets original state after pause")
    done=true;await create_timer(1.0).timeout;break
  elif role=="observer":
   if e.returns.paused and not saw_pause:
    saw_pause=true;var ghosts:=0
    for p in main.get_node("Players").get_children():
     if int(str(p.name))<0 and p.profile_id in e.journal.last.participants and p.get_meta("attempt_paused",false):ghosts+=1
    check(ghosts==1 and e.state.health==99,"remote observer sees one retained body and shared pause state")
   if saw_pause and e.journal.last.get("status","")=="defeated":
    var ghosts:=0
    for p in main.get_node("Players").get_children():
     if int(str(p.name))<0:ghosts+=1
    check(ghosts==0 and not e.returns.paused and e.actor==null,"remote observer sees reclaim without ghost duplicate and terminal cleanup")
    done=true;break
 check(done,"pause network scenario completes on "+role)
 await main.network.stop();main.queue_free();await process_frame;print("PAUSE_NETWORK_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
