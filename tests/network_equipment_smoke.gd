extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var role:=OS.get_cmdline_user_args()[0]
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false;main.player.set_physics_process(false)
 var remote:=[0]
 if role=="host":
  main.network.peer_admitted.connect(func(id):
   remote[0]=id;var body=main.get_node("Players").get_node(str(id));body.set_physics_process(false);body.hurt_immunity=0;body.position=main.world.spawn_position()
   var bag=main.items.inventory_for(id);bag.load_data([]);bag.add("wood_shield",1);bag.add("wood_helm",1);bag.add("wood",30);main.items.inventory_changed.emit(id))
  main.storage.apply_object(Vector2i(98,21),{"empty":true,"opened":false})
  main.storage.chests[Vector2i(98,21)].inventory.add("wood",98)
  main.storage.chests[Vector2i(98,21)].inventory.add("stone",60)
  main.storage.refresh(Vector2i(98,21))
  check(main.network.host_game()==OK,"equipment ENet host starts");print("GEAR_HOST_READY")
 else:check(main.network.join_game("127.0.0.1")==OK,"equipment client starts")
 var start:=Time.get_ticks_msec();var phase:=0;var hit_at:=0;var guarded:=false;var broken:=false;var equipped:=false;var last:=start;var chest_sent:=false;var chest_returned:=false
 while Time.get_ticks_msec()-start<(8000 if role=="host" else 6000):
  await process_frame
  var now:=Time.get_ticks_msec();var delta:=minf(.05,(now-last)/1000.0);last=now
  if not main.network.connected:continue
  if role=="host" and remote[0]!=0:
   var body=main.get_node("Players").get_node_or_null(str(remote[0]))
   if body==null:continue
   main.combat.tick_fighter(body,delta)
   var count:int=main.storage.chests[Vector2i(98,21)].inventory.count_item("wood")
   var own:int=main.items.inventory_for(remote[0]).count_item("wood")
   if count==128 and own==0 and not chest_sent:check(true,"server quick move fills partial stack and next cell exactly once");chest_sent=true
   if chest_sent and count==99 and own==29 and not chest_returned:check(true,"server conserves shared loot after quick return");chest_returned=true
   if body.equipment.shield=="wood_shield" and body.equipment.head=="wood_helm":equipped=true
   if body.fighter.mode=="block" and phase==0:
    check(main.items.inventory_for(remote[0]).count_item("wood_shield")==0,"server removes equipped shield from bag")
    check(main.player.equipment.shield=="","client equip never changes host")
    check(main.combat.receive_attack(remote[0],20,body.position+Vector2(16,0),body)=="blocked","server resolves shield hit")
    phase=1;hit_at=now
   elif phase==1 and now-hit_at>500:
    body.hurt_immunity=0;main.combat.tick_fighter(body,1.21)
    check(body.fighter.mode=="idle" and body.guard_cooldown>0,"server expires shield hold into recovery")
    main.combat.player_changed.emit(remote[0],main.combat.player_data(body))
    phase=2
  elif role=="client":
   var bag=main.items.local_inventory()
   if phase==0 and bag.item_at(0)=="wood_shield":main.network.equip_local(0,"shield");phase=1
   elif phase==1 and main.player.equipment.shield=="wood_shield":main.network.equip_local(1,"head");phase=2
   elif phase==2 and main.player.equipment.head=="wood_helm":
    check(bag.count_item("wood_shield")==0 and bag.count_item("wood_helm")==0,"client receives authoritative gear and inventory")
    equipped=true;main.network.open_storage_local(Vector2i(98,21),0);phase=3
   elif phase==3 and main.inventory_ui.storage_anchor==Vector2i(98,21):
    main.network.quick_move_local(2,Vector2i(98,21),false,main.inventory_ui.storage_revision);phase=4
   elif phase==4 and bag.count_item("wood")==0 and main.inventory_ui.storage_slots[2].count==29:
    check(main.inventory_ui.storage_slots[0].count==99,"client quick move merges partial stack and empty destination")
    main.network.quick_move_local(2,Vector2i(98,21),true,main.inventory_ui.storage_revision);phase=5
   elif phase==5 and bag.count_item("wood")==29:
    check(main.inventory_ui.storage_slots[0].count==99 and main.inventory_ui.storage_slots[2].count==0,"client quick return has no duplicate loot")
    main.inventory_ui.toggle();main.network.block_local(true);phase=6
   if main.player.health==96 and not main.player.resources.snapshot().has("stamina"):guarded=true
   if main.player.guard_cooldown>0:broken=true
 if role=="host":check(equipped and phase==2 and chest_sent and chest_returned,"host completes multiplayer gear and quick-storage flow")
 else:
  check(equipped,"remote equipment replicates")
  check(guarded,"client receives exact shield chip without stamina")
  check(broken,"client sees shield recovery")
 main.network.stop();await create_timer(.2).timeout;main.queue_free();await process_frame
 print("NETWORK_EQUIPMENT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
