extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func freeze(main) -> void:
 main.set_physics_process(false);main.interaction.set_process(false);main.combat.set_physics_process(false);main.combat.spawning_enabled=false;main.survival.set_physics_process(false);main.exploration.set_process(false);main.encounter.set_physics_process(false)
 for p in main.get_node("Players").get_children():p.set_physics_process(false)
func ready(main,id:int) -> void:
 check(main.encounter.choose(id,"join")=="" and main.encounter.choose(id,"ready")=="","participant %d chooses and confirms"%id)
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);freeze(main)
 var e=main.encounter;var initial:Vector2=e.journal.altar
 check(initial!=Vector2.ZERO,"old world receives a supported reachable altar without changing terrain")
 var c:Vector2i=main.world.cell_at(initial)
 check(main.world.block_at(c)>=0 and main.world.block_at(c+Vector2i.UP)==-1,"altar rests on existing ground")
 for i in range(3):e.register_kill("ashling")
 e._physics_process(1)
 check(not e.pending and e.actor==null,"ordinary kills never auto-summon Andrew")
 for x in range(65,128):
  for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
  for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
 main.world.solid.update_internals();e.journal.altar=Vector2(96*16+8,26*16)
 main.player.position=e.journal.altar+Vector2(0,-10)
 main.add_player(2,main.player.position+Vector2(16,0));main.saves.attach_peer(2,"2".repeat(32),"a".repeat(64))
 main.add_player(3,main.player.position+Vector2(-16,0));main.saves.attach_peer(3,"3".repeat(32),"b".repeat(64));freeze(main)
 check(e.choose(1,"ready")!="","ready requires explicit participation")
 ready(main,1)
 check(e.choose(2,"join")=="" and e.choose(1,"start")!="" and not e.journal.free_used,"unready participant prevents free charge")
 check(e.choose(2,"ready")=="" and e.choose(3,"skip")=="","second ready and third skip")
 var before:Dictionary=e.persistent_data();var bag=main.items.inventory_for(1);bag.add("andrew_seal",2)
 main.saves.write_blocked=true
 check(e.choose(1,"start")!="" and e.persistent_data()==before and bag.count_item("andrew_seal")==2,"blocked saving cannot charge or summon")
 main.saves.write_blocked=false
 var path:String=main.saves.save_path;main.saves.save_path="user://unavailable/../saves" # existing directory cannot be replaced by a file
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(main.saves.save_path))
 var error:String=e.choose(1,"start")
 check(error!="" and e.actor==null and e.persistent_data()==before and bag.count_item("andrew_seal")==2 and not main.combat_zone.active,"actual disk write failure rolls back actor, free charge and arena")
 main.saves.save_path=path
 # A filled room must not be excavated automatically or charge anything.
 for x in range(80,113):
  for y in range(14,26):main.world.apply_edit(Vector2i(x,y),2)
 check(e.choose(1,"start")!="" and e.journal.sequence==0 and bag.count_item("andrew_seal")==2,"blocked boss footprint cancels without charging")
 for x in range(80,113):
  for y in range(14,26):main.world.apply_edit(Vector2i(x,y),-1)
 check(e.choose(1,"start")=="" and is_instance_valid(e.actor),"ready team summons one boss")
 e.actor.set_physics_process(false)
 check(e.journal.free_used and e.journal.sequence==1 and bag.count_item("andrew_seal")==2,"first successful appearance uses world free attempt only")
 check(e.state.max_health==450 and e.state.max_poise==90 and main.get_node("Players").get_child_count()==3,"two participants give x1.25 with a third connected spectator")
 check(e.alive_players().size()==2 and not e.can_damage("3".repeat(32)),"spectator cannot attack or become boss target")
 check(main.combat_zone.blocks_edit(main.world.cell_at(main.player.position)) and not main.combat_zone.blocks_edit(Vector2i(10,20)),"arena edit restriction stays local")
 check(e.choose(1,"start")!="" and e.journal.sequence==1 and bag.count_item("andrew_seal")==2,"duplicate summon cannot charge twice")
 var saved:Dictionary=main.saves._read(path)
 check(saved.error=="" and saved.state.boss_attempts.last.participants.size()==2 and saved.state.boss_attempts.free_used,"successful appearance is durably committed with stable profiles")
 e.end_fight("player_died")
 check(e.journal.last.status=="player_died" and not main.combat_zone.active,"defeat finishes journal and unlocks arena")
 ready(main,1);ready(main,2)
 check(e.choose(1,"start")=="" and e.journal.sequence==2 and bag.count_item("andrew_seal")==1,"repeat attempt consumes exactly one seal")
 e.actor.set_physics_process(false);e.end_fight("defeated")
 check(e.journal.last.status=="defeated" and e.journal.free_used,"victory does not restore free attempt")
 ready(main,1)
 check(e.choose(2,"start")!="" and e.actor==null,"seal must belong to the ready summoning player")
 ready(main,2)
 check(e.choose(1,"start")=="" and bag.count_item("andrew_seal")==0 and e.journal.sequence==3,"third attempt uses remaining seal once")
 e.actor.set_physics_process(false)
 var during:Dictionary=main.saves.capture()
 check(main.saves.restore(during)=="" and e.actor==null and e.journal.last.status=="interrupted" and e.journal.free_used,"load interrupts running attempt without free refund")
 freeze(main);main.player.position=e.journal.altar+Vector2(0,-10);ready(main,1)
 check(e.choose(1,"start")!="" and main.items.inventory_for(1).count_item("andrew_seal")==0,"loading cannot obtain another free summon")
 var legacy:Dictionary=main.saves.capture();legacy.erase("boss_attempts")
 check(main.saves.restore(legacy)=="" and not e.journal.free_used and e.journal.altar!=Vector2.ZERO,"pre-altar save receives one free attempt compatibly")
 var malformed:Dictionary=main.saves.capture();malformed.boss_attempts.sequence=NAN
 check(preload("res://scripts/save_schema.gd").validate(malformed)!="","invalid journal rejected before world restore")
 var journal=preload("res://scripts/boss_attempt.gd").new();journal.apply(before)
 journal.begin(["1".repeat(32)]);journal.last.participants.append("1".repeat(32))
 check(not journal.valid(journal.snapshot(),192,72),"duplicate stable participant IDs rejected")
 # Actual altar starts for each of the four participant counts, with four peers present.
 for id in [2,3,4]:
  main.add_player(id,e.journal.altar+Vector2((id-2)*16,-10))
  main.saves.attach_peer(id,str(id).repeat(32),{2:"a",3:"b",4:"c"}[id].repeat(64))
 freeze(main);main.player.position=e.journal.altar+Vector2(0,-10)
 bag=main.items.inventory_for(1);bag.add("andrew_seal",4)
 for count in range(1,5):
  for body in main.get_node("Players").get_children():body.position=e.journal.altar+Vector2((int(str(body.name))-1)*8,-10)
  for id in range(1,count+1):e.choose(id,"join");e.choose(id,"ready")
  check(e.choose(1,"start")=="" and e.state.max_health==[360,450,540,630][count-1] and e.state.max_poise==90,"actual altar health scales once for %d participants"%count)
  e.actor.set_physics_process(false)
  if count==2:
   var snapshot:Dictionary=e.persistent_data();var amount:int=bag.count_item("andrew_seal")
   e.end_fight("player_died");e.choose(1,"join");e.choose(1,"ready")
   var save_path:String=main.saves.save_path;main.saves.save_path="user://unavailable/../saves"
   check(e.choose(1,"start")!="" and e.journal.sequence==snapshot.sequence and bag.count_item("andrew_seal")==amount,"paid disk failure restores exactly the original seal count")
   main.saves.save_path=save_path
   e.choices.clear()
  else:e.end_fight("player_died")
 main.player.position=e.journal.altar+Vector2(0,-10)
 check(main.altar.open_panel() and main.ui_blocked(),"local altar panel blocks gameplay input")
 main.altar.close_panel();check(not main.altar.opened and main.input_latched,"closing panel latches mouse to prevent accidental attack")
 main.queue_free();await process_frame
 print("ALTAR_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
