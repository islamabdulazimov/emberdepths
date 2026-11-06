extends SceneTree
var failures:=0
var checks:=0
var app:Node
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
 else:print("PASS ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 app=root.get_node("GameApp")
 var menu=load("res://scenes/menu.tscn").instantiate();root.add_child(menu);current_scene=menu;await process_frame
 check(menu.page=="home","real startup home menu")
 menu.show_characters();check(menu.page=="characters" and app.characters().is_empty(),"empty character library")
 menu.show_character_creator();menu.name_input.text="   ";menu.save_character();check(menu.page=="create_character" and app.characters().is_empty(),"empty name rejected in UI")
 menu.name_input.text="Путник";menu.gender.select(1);menu.hair.select(3);menu.skin.select(4);menu.portrait.update_appearance(menu.creator_appearance());menu.save_character()
 check(menu.page=="create_world" and menu.selected.appearance.skin==4,"creator saves chosen female long hair dark skin")
 var a:Dictionary=menu.selected
 var b:Dictionary=app.create_character("Путник",{"gender":"male","hair":"short","skin":0})
 check(a.id!=b.id and app.characters().size()==2,"duplicate display names get different IDs")
 var wa:Dictionary=app.create_world(a,"Дом","small");var wb:Dictionary=app.create_world(b,"Дом","large")
 check(wa.id!=wb.id and app.worlds(a.id).size()==1 and app.worlds(b.id).size()==1,"world ownership separated")
 app.write_json(app.ROOT+"/characters/broken.json",{"id":"bad","name":"Bad","appearance":{"skin":"oops"}})
 app.write_json(app.ROOT+"/worlds/broken.json",{"id":"bad","character":a.id,"name":"Bad","size":"small","profile":"bad","seed":{}})
 check(app.characters().size()==2 and app.worlds(a.id).size()==1,"corrupt catalog records skipped")
 check(not app.select_world(b,wa),"cannot load another character world")
 menu.selected=a;menu.launch(wa,true)
 for i in range(8):await process_frame
 var main=current_scene
 check(main.scene_file_path=="res://scenes/main.tscn" and main.world.generator_version==3 and main.world.world_width==512,"menu creates small world")
 check(main.player.appearance==a.appearance and main.world.npc_records.size()==2,"actual player appearance and residents")
 main.set_physics_process(false);main.player.set_physics_process(false);main.combat.set_physics_process(false)
 var original:Vector2=main.player.position
 main.player.position.x+=40
 var exact:Vector2=main.player.position
 main.items.local_inventory().add("emberstone",7)
 check(main.saves.save_now(),"save selected world to own profile")
 main.player.position=original
 check(main.saves.load_now() and main.player.position==exact and main.items.local_inventory().count_item("emberstone")==7,"load restores position and inventory")
 var practice:Button
 for node in main.get_node("HUD").get_children():
  if node is Button and node.text=="Проверка боя":practice=node
 practice.pressed.emit();for i in range(8):await process_frame
 check(current_scene.has_meta("combat_test") and current_scene.player.appearance.skin==4,"selected character enters isolated arena")
 current_scene.leave_arena();for i in range(8):await process_frame
 main=current_scene
 check(main.world.generator_version==3 and main.items.local_inventory().count_item("emberstone")==7,"arena returns to catalog world without practice loot")
 main.pause_ui.open();check(paused and main.pause_open and main.ui_blocked(),"offline pause freezes and blocks commands")
 main.pause_ui.resume();check(not paused and not main.pause_open,"resume restores gameplay")
 main.pause_ui.save_exit();for i in range(8):await process_frame
 check(current_scene.scene_file_path=="res://scenes/menu.tscn","save exit returns home and releases lock")
 menu=current_scene;menu.selected=b;menu.launch(wb,true);for i in range(8):await process_frame
 main=current_scene
 check(main.world.world_width==896 and main.world.world_depth==256,"large world genuinely larger")
 check(main.player.appearance.skin==0 and main.items.local_inventory().count_item("emberstone")==0,"second character equipment and appearance isolated")
 main.pause_ui.save_exit();for i in range(8):await process_frame
 menu=current_scene;menu.selected=a;menu.launch(app.worlds(a.id)[0],false);for i in range(8):await process_frame
 main=current_scene;main.player.set_physics_process(false)
 check(main.items.local_inventory().count_item("emberstone")==7 and main.player.appearance.skin==4,"continue restores first character")
 check(main.npcs.actors.size()==2,"save exit and reload has no duplicate NPC")
 main.pause_ui.save_exit();for i in range(8):await process_frame
 var options=PanelContainer.new();options.set_script(load("res://scripts/ui/video_options.gd"));root.add_child(options)
 for value in app.FPS:
  app.set_fps(value,false);check(Engine.max_fps==value,"FPS cap "+str(value))
 var original_res:=Vector2i(app.video.width,app.video.height)
 app.preview_resolution(Vector2i(960,540));app.cancel_resolution();check(Vector2i(app.video.width,app.video.height)==original_res and not app.resolution_pending,"resolution rollback")
 options.resolution.select(0);options.apply_settings();check(app.resolution_pending,"resolution requires confirmation")
 options.remaining=0.01;options._process(0.02);check(not app.resolution_pending and Vector2i(app.video.width,app.video.height)==original_res,"timeout reverts without persisting preview")
 app.preview_resolution(Vector2i(960,540));app.confirm_resolution();app.load_video();check(app.video.width==960 and app.video.height==540,"confirmed resolution survives settings reload")
 app.set_fps(240,false)
 options.queue_free();current_scene.queue_free();await process_frame
 print("LIBRARY_MENU_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
