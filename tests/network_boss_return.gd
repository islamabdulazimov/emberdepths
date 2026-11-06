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
 main.set_physics_process(false);main.interaction.set_process(false);main.combat.set_physics_process(false);main.combat.spawning_enabled=false;main.survival.set_physics_process(false);main.exploration.set_process(false);main.player.set_physics_process(false)
 var e=main.encounter;var leases=e.returns;var joins:Array=[]
 if role=="host":
  for x in range(65,128):
   for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
   for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
  e.journal.altar=Vector2(1544,416);main.player.position=Vector2(1544,406)
  main.network.peer_admitted.connect(func(id):
   joins.append(id);var p=main.get_node("Players").get_node(str(id));p.set_physics_process(false)
   if joins.size()==1:
    p.position=Vector2(1560,406);p.health=70;p.resources.mana=13;p.roll_cooldown=5;main.items.inventory_for(id).add("wood",17)
   elif joins.size()==2:
    check(p.health==62 and p.resources.mana==13 and p.roll_cooldown==5,"real early rejoin preserves injured body and effects")
    check(e.state.health==111 and e.state.max_health==450 and e.state.poise==27,"real early rejoin never heals or rescales boss")
    check(e.actor.hit_targets.has(id) and leases.offline.is_empty(),"real early rejoin remaps hit ledger and removes ghost")
    print("RETURN_EARLY_ADMITTED")
   else:
    check(p.health==57 and not main.combat_zone.contains_body(p) and not e.can_damage(p.profile_id),"real late rejoin preserves health outside arena")
    check(e.state.health==112 and e.journal.last.participants.size()==2,"late connection itself never heals boss or duplicates participant")
    print("RETURN_LATE_ADMITTED"))
  check(main.network.host_game()==OK,"return host starts")
  e.choose(1,"join");e.choose(1,"ready");print("RETURN_HOST_READY")
 else:main.network.join_game("127.0.0.1")
 var start:=Time.get_ticks_msec();var stage:=0;var uid:="";var clock:=0;var voted:=false;var done:=false
 while Time.get_ticks_msec()-start<85000:
  await process_frame
  if not main.network.connected:continue
  if role=="host":
   if stage==0 and joins.size()==1:
    var p=main.get_node("Players").get_node(str(joins[0]));uid=p.profile_id
    if e.choices.get(uid,{}).get("ready",false):
     check(e.choose(1,"start")=="","network return test starts actual altar attempt")
     e.actor.set_physics_process(false);e.state.health=111;e.state.poise=27;e.publish();stage=1
   elif stage==1 and leases.offline.has(uid):
    var ghost:int=leases.offline[uid].id;var p=leases.body(ghost);p.hurt_immunity=0
    check(main.combat.damage_player(ghost,8,p.position,true) and p.health==62,"disconnected network body remains damageable")
    e.actor.hit_targets[ghost]=true;stage=2;print("RETURN_FIRST_HELD")
   elif stage==2 and joins.size()==2 and leases.offline.has(uid):
    var ghost:int=leases.offline[uid].id;var p=leases.body(ghost);p.hurt_immunity=0
    check(main.combat.damage_player(ghost,5,p.position,true) and p.health==57,"second disconnect keeps same injured character")
    e.state.health=112;e.publish();stage=3;clock=Time.get_ticks_msec();print("RETURN_SECOND_HELD")
   elif stage==3 and leases.offline.has(uid) and int(leases.offline[uid].id)==0:
    check(Time.get_ticks_msec()-clock>=60000,"late window expired after an actual wall-clock minute")
    check(main.saves.profiles[uid].life.health==57,"expired body life captured in persistent profile")
    stage=4;print("RETURN_LATE_READY")
   elif stage==4 and joins.size()==3 and e.can_damage(uid):
    check(e.state.health==450 and e.state.max_health==450 and e.state.poise==27 and e.journal.last.participants.size()==2,"late confirmation heals boss without multiplying same player again")
    var p=main.get_node("Players").get_node(str(joins[2]));check(p.health==57 and main.combat_zone.contains_body(p),"confirmed entry changes location only, never heals player")
    clock=Time.get_ticks_msec();stage=5
   elif stage==5 and Time.get_ticks_msec()-clock>500:
    e.state.health=119;e.publish();stage=6;clock=Time.get_ticks_msec()
   elif stage==6 and Time.get_ticks_msec()-clock>1300:
    check(e.state.health==119 and e.journal.last.participants.size()==2,"duplicate remote confirmation cannot heal or count twice")
    e.end_fight("defeated");stage=7;clock=Time.get_ticks_msec()
   elif stage==7 and Time.get_ticks_msec()-clock>600:done=true;break
  elif role=="first":
   if not voted:
    voted=true;main.network.altar_local("join");await create_timer(.25).timeout;main.network.altar_local("ready")
   if is_instance_valid(e.actor) and e.state.health==111:
    check(main.player.health==70 and e.journal.last.participants.size()==2,"initial peer receives actual participant state")
    await create_timer(.2).timeout;done=true;break
  elif role=="early":
   if is_instance_valid(e.actor) and e.state.health==111:
    check(main.player.health==62 and main.player.resources.mana==13 and main.player.roll_cooldown==5,"new process gets exact early-return character")
    check(e.journal.last.participants.size()==2 and main.items.local_inventory().count_item("wood")==17,"early-return inventory and participant identity are unchanged")
    await create_timer(.3).timeout;done=true;break
  elif role=="late":
   if stage==0 and is_instance_valid(e.actor):
    check(main.player.health==57 and e.state.health==112 and not main.combat_zone.contains_body(main.player),"late process starts outside with exact saved health")
    check(main.altar.open_panel() and main.altar.detail.text.contains("полностью восстановит"),"late process sees warning before explicit entry")
    main.network.altar_local("enter",e.journal.last.id);stage=1
   elif stage==1 and e.state.health==119:
    main.network.altar_local("enter",e.journal.last.id);stage=2
   elif stage==2 and e.actor==null:
    check(e.journal.last.status=="defeated" and not main.combat_zone.active,"returned client receives terminal attempt snapshot")
    done=true;break
 check(done,"real disconnect scenario completes: "+role)
 await main.network.stop();main.queue_free();await process_frame
 print("RETURN_NETWORK_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
