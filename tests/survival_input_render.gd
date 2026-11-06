extends "res://tests/recast_ui_render.gd"
func shot(name:String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/"+name+".png")
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://scenes/combat_arena.tscn").instantiate();root.add_child(main)
 main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.combat.spawning_enabled=false;main.encounter.enabled=false;main.items.set_physics_process(false)
 for id in main.combat.entities.keys():main.combat.set_entity(id,{})
 main.player.set_physics_process(false);main.player.hurt_immunity=0;main.player.money=101;main.equipment_service.starter(1)
 main.equipment_service.move(1,0,"weapon")
 main.add_player(2,main.player.position+Vector2(26,0));var helper=main.get_node("Players/2");helper.profile_id="2".repeat(32);helper.set_physics_process(false)
 main.items.inventory_for(2).add("spark_binding",2)
 var target=main.player;var worn:Dictionary=target.equipment.duplicate()
 main.combat.damage_player(1,1000,target.position,true)
 for i in range(4):await process_frame
 check(target.dead and target.visible and main.survival.down_panel.is_visible_in_tree(),"downed body and choice panel are actually visible")
 check(target.self_modulate.a==1 and target.equipment==worn,"downed graphic keeps equipped armor without disappearing")
 main.fps_label.hide();await shot("survival-downed")
 var observe:Button=main.survival.observe
 mouse(observe.get_global_rect().get_center(),1);await process_frame;mouse(observe.get_global_rect().get_center(),0);await process_frame
 check(main.survival.watching==2 and target.dead,"actual observe click changes view without reviving")
 var button:Button=main.survival.down_panel.get_child(0).get_child(2)
 mouse(button.get_global_rect().get_center(),1);await process_frame;mouse(button.get_global_rect().get_center(),0);await process_frame;await process_frame
 check(not target.dead and target.money==51 and target.equipment==worn,"actual respawn click preserves gear and remaining money")
 check(target.fighter.mode=="idle","respawn UI click cannot become attack")
 mouse(button.get_global_rect().get_center(),0);await process_frame
 target.position=Vector2(90*16+8,26*16-10);target.hurt_immunity=0;main.combat.damage_player(1,1000,target.position,true)
 main.select_local_player(2);helper.position=target.position+Vector2(26,0)
 main.input_latched=false
 for i in range(3):await process_frame
 main.survival.set_physics_process(true)
 key(KEY_E,true);await create_timer(1.0).timeout
 check(target.dead and helper.help_progress>.1 and main.items.inventory_for(2).count_item("spark_binding")==2,"real held E advances help without early consumption")
 await shot("survival-help")
 key(KEY_E,false);await physics_frame;await process_frame
 check(helper.help_progress==0 and target.dead,"real E release cancels channel")
 key(KEY_E,true);await create_timer(4.25).timeout;key(KEY_E,false);await process_frame
 check(not target.dead and target.health==30 and main.items.inventory_for(2).count_item("spark_binding")==1,"real four-second hold revives once with one item")
 check(target.revive_immunity>0 and target.self_modulate.a<1,"revived character displays translucent protection")
 await shot("survival-revived")
 main.combat._physics_process(1.5);await process_frame;await RenderingServer.frame_post_draw
 check(target.revive_immunity==0 and target.self_modulate.a==1 and target.revive_trail.is_empty(),"visible protection ends together with immunity")
 main.queue_free();await process_frame;print("SURVIVAL_NATIVE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
