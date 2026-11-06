extends "res://tests/altar_render.gd"
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.player.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.exploration.set_process(false);main.survival.set_physics_process(false);main.encounter.set_physics_process(false);main.fps_label.hide()
 for x in range(65,128):
  for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
  for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
 main.world.solid.update_internals()
 var e=main.encounter;e.journal.altar=Vector2(1544,416);main.player.position=Vector2(1544,406);main.combat.world_time=100
 e.choose(1,"join");e.choose(1,"ready");check(e.choose(1,"start")=="","native entry fixture starts solo boss")
 e.actor.set_physics_process(false);e.state.health=99;e.state.poise=37
 main.add_player(2,e.returns.entry_position());main.saves.attach_peer(2,"2".repeat(32),"2".repeat(64));e.returns.admitted(2,"2".repeat(32),false)
 var p=main.get_node("Players/2");p.set_physics_process(false);p.health=44;p.appearance={"gender":"female","build":"normal","hair":"long_tail","hair_color":2,"skin":1}
 main.select_local_player(2);main.player.get_node("Camera2D").reset_smoothing()
 for i in range(4):await process_frame
 key(KEY_E,true);await process_frame;key(KEY_E,false);await process_frame
 check(main.altar.opened and main.altar.entry_mode,"actual E opens local entry warning at arena boundary")
 check(main.altar.detail.text.contains("полностью восстановит") and main.altar.detail.text.contains("450"),"warning shows full healing and new maximum before entry")
 await shot("entry-warning")
 for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=size;await process_frame;await process_frame
  check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(main.altar.panel.get_global_rect()),"entry warning fits "+str(size))
 root.size=Vector2i(1280,720);await process_frame;await process_frame
 key(KEY_ESCAPE,true);await process_frame;key(KEY_ESCAPE,false);await process_frame
 check(not main.altar.opened and e.state.health==99 and e.journal.last.participants.size()==1,"actual cancellation keeps old boss health and participants")
 key(KEY_E,true);await process_frame;key(KEY_E,false);await process_frame
 await click_text("Вступить · восстановить ОЗ босса")
 check(not main.altar.opened and main.combat_zone.contains_body(p),"actual confirm admits player and closes warning")
 check(e.state.health==450 and e.state.max_health==450 and e.state.poise==37 and p.health==44,"native entry heals only boss health")
 main.player.get_node("Camera2D").reset_smoothing();await shot("entry-confirmed")
 e.withdraw(main.get_node("Players/1").profile_id);main.select_local_player(1);e.returns.move_outside(main.player)
 for i in range(4):await process_frame
 key(KEY_E,true);await process_frame;key(KEY_E,false);await process_frame
 check(main.altar.opened and main.altar.enter_button.disabled and main.altar.detail.text.contains("Вернуться"),"withdrawn profile sees disabled entry and clear explanation")
 await shot("entry-withdrawn")
 key(KEY_ESCAPE,true);await process_frame;key(KEY_ESCAPE,false);await process_frame
 var profile:String=p.profile_id;var age:float=e.actor.phase_elapsed
 e.returns.retain_body(2);e.returns.tick(15);e.actor._physics_process(1)
 check(e.returns.paused and e.actor.phase_elapsed==age,"staged all-offline state freezes real boss phases")
 await shot("entry-paused")
 check(e.returns.reclaim(2,profile),"staged timely return reclaims retained body")
 e.returns.admitted(2,profile,true)
 check(not e.returns.paused and p.health==44 and e.state.health==450,"resume restores control without extra healing")
 main.queue_free();await process_frame;print("BOSS_RETURN_NATIVE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
