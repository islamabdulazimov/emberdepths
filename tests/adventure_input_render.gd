extends "res://tests/recast_ui_render.gd"
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://scenes/combat_arena.tscn").instantiate();root.add_child(main)
 main.combat.spawning_enabled=false;main.encounter.enabled=false;main.player.set_physics_process(false)
 for id in main.combat.entities.keys():main.combat.set_entity(id,{})
 main.player.equipment=preload("res://data/equipment.gd").empty()
 for i in range(5):await process_frame
 key(KEY_SHIFT,true);await physics_frame;await physics_frame;key(KEY_SHIFT,false)
 check(main.player.fighter.mode=="idle" and main.player.roll_cooldown==0,"real Shift cannot grant innate roll")
 main.equipment_service.starter(1)
 var bag=main.items.local_inventory();bag.load_data([]);bag.add("traveler_knot",1);bag.add("wood_sword",1);bag.add("wood",32);bag.add("emberstone",8)
 main.equipment_service.move(1,1,"weapon")
 key(KEY_ESCAPE,true);await process_frame;key(KEY_ESCAPE,false);await process_frame
 main.inventory_ui.refresh();await process_frame
 await drag(main.inventory_ui.bag_buttons[0],main.inventory_ui.gear_buttons.ability)
 check(main.player.equipment.ability=="traveler_knot" and bag.item_at(0)=="","actual mouse drag equips ability without losing it")
 mouse(main.inventory_ui.gear_buttons.ability.get_global_rect().get_center());await process_frame
 main.inventory_ui.refresh();await process_frame
 check(main.inventory_ui.tooltip_label.text.contains("Надето: Узел странника"),"ability tooltip updates equipped comparison after drag")
 main.fps_label.hide()
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/adventure-equipped-ui.png")
 key(KEY_ESCAPE,true);await process_frame;key(KEY_ESCAPE,false);await process_frame;await process_frame
 mouse(Vector2(540,320))
 key(KEY_SHIFT,true);await physics_frame;await physics_frame;key(KEY_SHIFT,false)
 check(main.player.fighter.mode=="roll" and main.player.roll_cooldown>5,"real Shift starts equipped roll with cooldown")
 await create_timer(.55).timeout
 key(KEY_SHIFT,true);await physics_frame;await physics_frame;key(KEY_SHIFT,false)
 check(main.player.fighter.mode=="idle" and main.player.roll_cooldown>4,"repeated real Shift observes recovery")
 key(KEY_R,true);await physics_frame;await physics_frame;await process_frame
 check(main.player.fighter.mode=="block","real R starts timed shield hold")
 await create_timer(1.3).timeout
 check(main.player.fighter.mode=="idle" and main.player.guard_cooldown>0,"real held R expires instead of blocking indefinitely")
 await create_timer(.55).timeout
 check(main.player.fighter.mode=="idle","held R still needs release after shield cooldown")
 key(KEY_R,false);await physics_frame;await physics_frame
 key(KEY_R,true);await physics_frame;await physics_frame
 check(main.player.fighter.mode=="block","real R works after release and recovery")
 key(KEY_R,false);await physics_frame;await physics_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/adventure-combat-hud.png")
 main.queue_free();await process_frame
 print("ADVENTURE_NATIVE_INPUT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
