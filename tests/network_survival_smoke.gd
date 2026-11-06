extends SceneTree
const Rules=preload("res://data/survival.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var role:String=OS.get_cmdline_user_args()[0]
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.player.set_physics_process(false);main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.items.set_physics_process(false);main.interaction.set_process(false);main.exploration.set_process(false);main.encounter.enabled=false;main.combat.spawning_enabled=false
 var peers:Array[int]=[];var mob_id:=1;var interrupted:=false;var revived:=false;var first_at:=0;var second_at:=0;var returned:=false;var saw_downed:=false;var saw_revived:=false;var saw_returned:=false;var held:=false;var money_ok:=false;var late_seen:=false
 if role=="host":
  for x in range(80,121):
   for y in range(12,25):main.world.apply_edit(Vector2i(x,y),-1)
   main.world.apply_edit(Vector2i(x,25),2)
  main.world.solid.update_internals();main.player.position=Vector2(1544,390);main.equipment_service.starter(1);main.items.local_inventory().add("wood",33);main.player.money=101
  main.combat.damage_player(1,1000,main.player.position,true)
  mob_id=main.combat.spawn_entity("ashling",Vector2(1800,400));main.combat.entities[mob_id].money=7
  main.network.peer_admitted.connect(func(id):
   peers.append(id);var p=main.get_node("Players").get_node(str(id));p.set_physics_process(false);p.position=Vector2(1568 if peers.size()==1 else 1520,390)
   main.items.inventory_for(id).add(Rules.HELP_ITEM,2);main.items.inventory_changed.emit(id))
  check(main.network.host_game()==OK,"survival ENet host starts");print("SURVIVAL_HOST_READY")
 else:check(main.network.join_game("127.0.0.1")==OK,"survival "+role+" connects")
 var start:=Time.get_ticks_msec();var last:=start;var last_intent:=0
 while Time.get_ticks_msec()-start<(14500 if role=="host" else (7500 if role=="late" else 12500)):
  await process_frame
  var now:=Time.get_ticks_msec();var dt:=minf(.05,(now-last)/1000.0);last=now
  if not main.network.connected:continue
  if role=="host":
   for p in main.get_node("Players").get_children():
    p.resource_sync=maxf(0,p.resource_sync-dt);p.hurt_immunity=maxf(0,p.hurt_immunity-dt);p.revive_immunity=maxf(0,p.revive_immunity-dt)
    if not p.dead:main.combat.tick_fighter(p,dt)
   main.survival.tick_help(dt)
   if not interrupted and main.survival.channels.has(1) and main.survival.channels[1].elapsed>1:
    var id:int=main.survival.channels[1].helper
    check(id==peers[0],"first helper owns the channel")
    main.combat.damage_player(id,5,main.get_node("Players").get_node(str(id)).position+Vector2(15,0));interrupted=true
    check(main.survival.channels.is_empty() and main.items.inventory_for(id).count_item(Rules.HELP_ITEM)==2,"remote helper damage resets progress without consuming")
   if interrupted and not revived and not main.player.dead:
    revived=true;first_at=now
    check(main.player.health==30 and main.player.revive_immunity>1.4 and main.player.money==51,"host validates revival health protection and wallet")
    check(main.items.inventory_for(peers[0]).count_item(Rules.HELP_ITEM)+main.items.inventory_for(peers[1]).count_item(Rules.HELP_ITEM)==3,"simultaneous requests spend one successful helper item only")
    check(now-start>=5000,"interruption requires a full new four-second channel")
    check(main.player.equipment.head=="wood_helm" and main.items.local_inventory().count_item("wood")==33,"host retains equipment and inventory through network revive")
    check(not main.combat.damage_player(1,100,main.player.position,true),"server rejects damage during revival immunity")
    print("REVIVE_NET_DONE")
   if revived and second_at==0 and now-first_at>1800:
    main.player.revive_immunity=0;main.player.hurt_immunity=0;main.combat.damage_player(1,1000,main.player.position,true);second_at=now
    check(main.player.money==26 and main.survival.coins.size()==2,"second network death retains old money pile")
   if second_at>0 and not returned and now-second_at>900:
    check(main.survival.respawn_request(1) and not main.survival.respawn_request(1),"respawn cannot execute twice")
    var coin:int=main.survival.spawn_money(9,main.combat.entities[mob_id].position);main.survival.coins[coin].age=1;main.survival.tick_coins(0)
    check(main.combat.entities[mob_id].money==16 and not main.survival.coins.has(coin),"server transfers ground coins to ordinary mob")
    main.combat.hit_entity(mob_id,1000,Vector2.RIGHT);returned=true
    check(main.player.money==26 and main.player.equipment.head=="wood_helm","respawn keeps remaining currency and gear")
  else:
   var target=main.get_node("Players").get_node_or_null("1")
   if target==null:continue
   if role=="late" and not late_seen:
    late_seen=true;check(not target.dead and target.health==30 and target.money==51 and target.equipment.head=="wood_helm","late join receives revived character wallet and equipment")
    check(main.survival.coins.size()==1,"late join receives existing money pile exactly once")
   saw_downed=saw_downed or target.dead
   saw_revived=saw_revived or (not target.dead and target.health==30)
   saw_returned=saw_returned or (not target.dead and target.health==100 and target.money==26)
   if role=="helper" and not held and not saw_revived:
    check(not main.combat.damage_player(1,100,target.position,true) and main.survival.spawn_money(100,main.player.position)==-1,"client cannot change foreign health or mint coins")
    held=true
   if role in ["helper","observer"]:
    var can_help:bool=target.dead and not saw_revived and (role=="helper" or main.get_node("Players").get_node_or_null(str(main.player.name))!=null)
    if role=="observer":
     var first_help:=false
     for p in main.get_node("Players").get_children():
      if p!=main.player and p.help_progress>0:first_help=true
     can_help=can_help and first_help
    if now-last_intent>100:main.network.help_local(1,can_help);last_intent=now
   if not main.combat.entities.has(mob_id) and main.survival.coins.size()==4:money_ok=true
 if role=="host":check(interrupted and revived and returned,"host completes interrupted rescue death and respawn")
 else:
  check(saw_downed and saw_revived and saw_returned,"downed revival and explicit respawn replicate to "+role)
  var owned:int=main.items.local_inventory().count_item(Rules.HELP_ITEM)
  check(owned==2 if role=="late" else owned in [1,2],"at most one consumable spent by a helper on "+role)
  check(money_ok,"shared money and returned mob wallet replicate to "+role)
 await main.network.stop();await create_timer(.2).timeout
 if role!="host":check(main.player.money==0 and main.survival.coins.is_empty(),"leaving returns original local wallet and coin field")
 main.queue_free();await process_frame
 print("NETWORK_SURVIVAL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
