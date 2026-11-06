extends "res://tests/recast_ui_render.gd"
func click_text(text:String) -> void:
 for button in main.altar.panel.find_children("*","Button",true,false):
  if button.text==text:
   var at:Vector2=button.get_global_rect().get_center();mouse(at,1);await process_frame;mouse(at,0);await process_frame;await process_frame;return
 check(false,"missing altar button "+text)
func shot(name:String) -> void:
 await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/altar-"+name+".png")
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.player.set_physics_process(false);main.interaction.set_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.exploration.set_process(false);main.survival.set_physics_process(false);main.encounter.set_physics_process(false)
 main.combat.world_time=100
 main.fps_label.hide()
 main.items.local_inventory().slots[0]={"item":"wood_sword","count":1}
 main.interaction.set_process(true)
 for x in range(75,120):
  for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
  for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
 main.world.solid.update_internals();main.encounter.journal.altar=Vector2(1544,416);main.player.position=Vector2(1504,406)
 var camera:Camera2D=main.player.get_node("Camera2D");camera.align();camera.reset_smoothing();camera.force_update_scroll()
 for i in range(5):await process_frame
 await shot("world")
 key(KEY_E,true);await process_frame;key(KEY_E,false);await process_frame
 check(main.altar.opened and main.ui_blocked(),"actual E opens local altar window")
 await click_text("Участвую");await click_text("Готов")
 check(main.encounter.choices[main.player.profile_id].ready,"actual buttons choose participation and readiness")
 for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=size;await process_frame;await process_frame
  check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(main.altar.panel.get_global_rect()),"altar fits "+str(size))
 root.size=Vector2i(1280,720);await process_frame;await process_frame
 await shot("preparation")
 # Holding a click while closing must not leak into the world.
 mouse(Vector2(40,260),1);await process_frame
 key(KEY_ESCAPE,true);await process_frame;key(KEY_ESCAPE,false);await process_frame
 check(main.player.fighter.mode=="idle" and main.input_latched,"held mouse on closing altar never leaks an attack")
 mouse(Vector2(40,260),0);await process_frame
 check(not main.altar.opened and not main.inventory_ui.opened,"Esc closes altar without opening inventory")
 key(KEY_E,true);await process_frame;key(KEY_E,false);await process_frame
 var count:int=main.encounter.journal.sequence
 await click_text("Призвать · один вызов на команду")
 check(is_instance_valid(main.encounter.actor) and main.encounter.journal.sequence==count+1,"actual summon button starts one durably charged encounter")
 main.encounter.actor.set_physics_process(false)
 check(main.encounter.state.max_health==360 and main.encounter.journal.free_used,"solo native summon uses base health and world free attempt")
 check(not main.altar.opened,"successful summon automatically closes preparation so controls are available")
 await shot("fight")
 main.encounter.end_fight("player_died")
 key(KEY_E,true);await process_frame;key(KEY_E,false);await process_frame
 check(main.altar.opened and main.altar.detail.text.contains("Нужна Печать"),"repeat panel clearly shows paid recipe")
 await shot("repeat")
 await click_text("Участвую");await click_text("Готов");await click_text("Призвать · один вызов на команду")
 check(main.altar.feedback.contains("Нужна Печать") and main.encounter.actor==null,"missing item gives readable feedback without duplicate boss")
 await shot("missing-seal")
 main.queue_free();await process_frame;print("ALTAR_NATIVE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
