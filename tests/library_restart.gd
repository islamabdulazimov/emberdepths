extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var app=root.get_node("GameApp")
 var mode:=OS.get_cmdline_user_args()[0]
 if mode=="write":
  var legacy=load("res://scenes/main.tscn").instantiate();root.add_child(legacy)
  legacy.set_physics_process(false);legacy.combat.set_physics_process(false);legacy.player.set_physics_process(false)
  legacy.items.local_inventory().add("emberstone",3)
  check(legacy.saves.save_now(),"write original legacy save")
  var path:String=legacy.saves.save_path;var bytes:=FileAccess.get_file_as_bytes(path)
  legacy.queue_free();await process_frame
  app.import_legacy();app.import_legacy()
  check(app.characters().size()==1 and app.worlds(app.characters()[0].id).size()==1,"legacy migration idempotent")
  check(FileAccess.get_file_as_bytes(path)==bytes and FileAccess.get_file_as_bytes(app.ROOT+"/backups/"+path.get_file()+".original")==bytes,"migration backup preserves original bytes")
  var c:Dictionary=app.create_character("Новый",{"gender":"female","hair":"long","skin":2});var w:Dictionary=app.create_world(c,"Глубина","large")
  app.select_world(c,w,true)
  var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
  main.set_physics_process(false);main.combat.set_physics_process(false);main.player.set_physics_process(false);main.items.set_physics_process(false)
  main.player.position=main.world.npc_records.cameron.position+Vector2(30,0)
  main.items.local_inventory().add("emberstone",11)
  main.world.apply_edit(Vector2i(420,90),4)
  main.world.npc_records.julia.position.x+=16
  check(main.saves.save_now(),"new large world persists modified tiles and NPCs")
  app.set_fps(120,true);app.preview_resolution(Vector2i(1024,576));app.confirm_resolution()
  main.queue_free();await process_frame
 else:
  check(app.video.fps==120 and app.video.vsync and app.video.width==1024,"video settings survive process restart")
  app.import_legacy();check(app.characters().size()==2,"restart preserves both legacy and new character")
  for c in app.characters():
   var worlds:Array=app.worlds(c.id);check(worlds.size()==1,"one owned world per character after restart")
   var w:Dictionary=worlds[0];app.select_world(c,w,false)
   var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
   main.set_physics_process(false);main.combat.set_physics_process(false);main.player.set_physics_process(false);main.items.set_physics_process(false)
   if w.legacy:check(main.world.generator_version==1 and main.items.local_inventory().count_item("emberstone")==3,"legacy terrain and inventory still load")
   else:
    check(main.world.generator_version==3 and main.world.world_width==896 and main.items.local_inventory().count_item("emberstone")==11,"continue exact new large world and inventory")
    check(main.world.block_at(Vector2i(420,90))==4 and main.player.position==main.world.npc_records.cameron.position+Vector2(30,0),"modified tile and precise position after process restart")
    check(main.npcs.actors.size()==2 and main.player.appearance.skin==2,"appearance and residents persist")
    check(main.player.equipment.head=="wood_helm" and main.player.equipment.body=="wood_armor" and main.player.equipment.legs=="wood_legs" and main.player.equipment.shield=="wood_shield","starter armor and shield survive separate process restart")
    check(main.items.local_inventory().count_item("wood_sword")==1,"restart grants no duplicate starter sword")
   main.queue_free();await process_frame
 print("LIBRARY_RESTART_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
