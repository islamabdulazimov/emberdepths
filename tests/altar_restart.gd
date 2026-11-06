extends "res://tests/altar_smoke.gd"
func run() -> void:
 var mode:=OS.get_cmdline_user_args()[0]
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);freeze(main)
 var e=main.encounter;var bag=main.items.inventory_for(1)
 if mode=="write":
  for x in range(75,120):
   for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
   for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
  e.journal.altar=Vector2(1544,416);main.player.position=e.journal.altar+Vector2(0,-10)
  bag.add("andrew_seal",1);ready(main,1)
  check(e.choose(1,"start")=="","first process commits free appearance")
  e.actor.set_physics_process(false);e.end_fight("player_died");ready(main,1)
  check(e.choose(1,"start")=="" and bag.count_item("andrew_seal")==0,"paid appearance committed before process exits")
  e.actor.set_physics_process(false)
 else:
  check(e.actor==null and e.journal.sequence==2 and e.journal.last.id=="andrew:2" and e.journal.last.status=="interrupted","separate process preserves attempt identity and ends interrupted actor")
  check(e.journal.free_used and bag.count_item("andrew_seal")==0,"restart refunds neither free attempt nor spent item")
  check(e.journal.altar==Vector2(1544,416) and e.journal.last.participants==[main.player.profile_id],"altar position and persistent participant survive restart")
  ready(main,1);check(e.choose(1,"start")!="" and e.actor==null,"restart cannot summon without another seal")
 main.queue_free();await process_frame;print("ALTAR_RESTART_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
