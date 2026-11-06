extends "res://tests/altar_smoke.gd"
func run() -> void:
 var mode:=OS.get_cmdline_user_args()[0]
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);freeze(main)
 var e=main.encounter
 if mode=="write":
  for x in range(65,128):
   for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
   for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
  e.journal.altar=Vector2(1544,416);main.player.position=Vector2(1544,406)
  for id in [2,3]:
   main.add_player(id,Vector2(1544+id*8,406));main.saves.attach_peer(id,str(id).repeat(32),str(id).repeat(64));ready(main,id)
  freeze(main);ready(main,1);check(e.choose(1,"start")=="","restart fixture starts with stable participants")
  e.actor.set_physics_process(false)
  main.items.inventory_for(2).add("wood",17);main.items.inventory_for(3).add("stone",13)
  for id in [2,3]:e.returns.retain_body(id)
  var two:int=e.returns.offline["2".repeat(32)].id;var three:int=e.returns.offline["3".repeat(32)].id
  main.combat.damage_player(two,75,Vector2.ZERO,true);main.combat.damage_player(three,1000,Vector2.ZERO,true)
  check(main.saves.save_now(),"host commits retained alive and downed body profiles")
 else:
  check(e.actor==null and e.journal.last.status=="interrupted" and e.journal.free_used,"host restart ends active attempt without refund or migration")
  check(main.saves.profiles["2".repeat(32)].life.health==25 and main.saves.profiles["3".repeat(32)].life.dead,"separate process reads exact retained life states")
  for id in [2,3]:main.add_player(id,Vector2(1544,406));main.saves.attach_peer(id,str(id).repeat(32),str(id).repeat(64))
  check(main.get_node("Players/2").health==25 and main.get_node("Players/3").dead,"later authenticated connection heals and resurrects nobody")
  check(main.items.inventory_for(2).count_item("wood")==17 and main.items.inventory_for(3).count_item("stone")==13,"retained inventory belongs to each profile exactly once")
 main.queue_free();await process_frame;print("RETURN_RESTART_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
