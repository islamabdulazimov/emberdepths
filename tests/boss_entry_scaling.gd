extends "res://tests/altar_smoke.gd"
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);freeze(main)
 var e=main.encounter
 for x in range(65,128):
  for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
  for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
 e.journal.altar=Vector2(1544,416);main.player.position=Vector2(1544,406)
 ready(main,1);check(e.choose(1,"start")=="" and e.state.max_health==360,"solo initial attempt uses base health")
 e.actor.set_physics_process(false)
 for id in [2,3,4,5]:
  main.add_player(id,e.returns.entry_position());main.saves.attach_peer(id,str(id).repeat(32),str(id).repeat(64));e.returns.admitted(id,str(id).repeat(32),false);freeze(main)
  var p=main.get_node("Players").get_node(str(id));p.health=31;p.resources.mana=11
  e.state.health=3;e.state.poise=19
  var error:String=e.choose(id,"enter",e.journal.last.id)
  if id<=4:
   check(error=="" and e.state.health==[360,450,540,630][id-1] and e.state.max_health==[360,450,540,630][id-1],"explicit entry uses base health once for %d participants"%id)
   check(e.state.poise==19 and p.health==31 and p.resources.mana==11,"entry changes neither player stats nor boss poise")
  else:check(error!="" and e.journal.last.participants.size()==4 and e.state.health==3 and e.state.max_health==630,"fifth distinct historical participant is rejected without healing")
 check(preload("res://scripts/save_schema.gd").validate(main.saves.capture())=="","expanded participant roster remains valid save data")
 main.queue_free();await process_frame;print("BOSS_ENTRY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
