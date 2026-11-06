extends SceneTree
const LOOK={"gender":"female","build":"sturdy","hair":"long_braid","hair_color":2,"skin":4}
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func freeze(main:Node2D) -> void:
 main.set_physics_process(false);main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.items.set_physics_process(false);main.player.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false
func run() -> void:
 var app=root.get_node("GameApp");var mode:String=OS.get_cmdline_user_args()[0]
 if mode=="write":
  for old in [false,true]:
   var look:Dictionary={"gender":"male","hair":"long","skin":2} if old else LOOK.duplicate()
   var c:Dictionary=app.create_character("Прежний" if old else "Новый",look)
   if old:
    c.appearance=look;app.write_json(app.ROOT+"/characters/"+c.id+".json",c)
   var w:Dictionary=app.create_world(c,"Облик","small");app.select_world(c,w,true)
   var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);freeze(main)
   main.items.local_inventory().add("wood",17 if old else 33)
   check(main.saves.save_now(),"save world with "+("legacy" if old else "complete")+" appearance")
   if old:
    var state:Dictionary=main.saves.capture();state.profiles[state.host_profile].life.appearance=look
    var payload:=JSON.stringify(preload("res://scripts/save_codec.gd").new().encode(state))
    var file:=FileAccess.open(main.saves.save_path,FileAccess.WRITE);file.store_string(JSON.stringify({"version":1,"payload":payload,"sha256":payload.sha256_text()}));file.close()
   main.queue_free();await process_frame
 else:
  check(app.characters().size()==2,"restart lists both complete and legacy character files")
  for c in app.characters():
   var old:bool=c.name=="Прежний";var expected:Dictionary=preload("res://data/appearance.gd").clean({"gender":"male","hair":"long","skin":2}) if old else LOOK
   check(c.appearance==expected,"character catalog retains normalized "+c.name)
   var worlds:Array=app.worlds(c.id);app.select_world(c,worlds[0],false)
   var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);freeze(main)
   check(main.player.appearance==expected,"fresh game process restores exact "+c.name)
   check(main.items.local_inventory().count_item("wood")== (17 if old else 33) and main.player.equipment.head=="wood_helm","appearance update preserves inventory and equipped armor")
   main.queue_free();await process_frame
 print("AVATAR_RESTART_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
