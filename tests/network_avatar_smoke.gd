extends SceneTree
const LOOKS=[
 {"gender":"male","build":"normal","hair":"short","hair_color":1,"skin":0},
 {"gender":"female","build":"sturdy","hair":"long_braid","hair_color":2,"skin":4},
 {"gender":"male","build":"slim","hair":"long_tail","hair_color":3,"skin":2},
 {"gender":"female","build":"normal","hair":"short_curls","hair_color":4,"skin":1}]
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var role:String=OS.get_cmdline_user_args()[0];var index:int=["host","a","b","late"].find(role)
 var app=root.get_node("GameApp");app.selected_character={"appearance":LOOKS[index]}
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.items.set_physics_process(false);main.player.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false
 if role=="host":
  main.network.peer_admitted.connect(func(id):main.get_node("Players").get_node(str(id)).set_physics_process(false))
  check(main.network.host_game()==OK,"avatar host starts");print("AVATAR_HOST_READY")
 else:check(main.network.join_game("127.0.0.1")==OK,"avatar "+role+" connects")
 var start:=Time.get_ticks_msec();var seen:Dictionary={};var signaled:=false;var invalid_sent:=false
 while Time.get_ticks_msec()-start<(9500 if role=="host" else (6500 if role=="late" else 8500)):
  await process_frame
  if not main.network.connected:continue
  for p in main.get_node("Players").get_children():
   var found:int=LOOKS.find(p.appearance)
   if found>=0:seen[found]=true
  if role=="host" and seen.size()==3 and not signaled:signaled=true;print("AVATAR_INITIAL_READY")
  if role=="a" and seen.size()==4 and not invalid_sent:
   invalid_sent=true;var bad:Dictionary=LOOKS[index].duplicate();bad.hair_color=99;main.network.request_appearance.rpc_id(1,bad)
 check(seen.size()==4,"all four complete appearances replicate to "+role)
 check(main.player.appearance==LOOKS[index],"own appearance remains identical to menu on "+role)
 var unchanged:=true
 for p in main.get_node("Players").get_children():
  unchanged=unchanged and p.modulate==Color.WHITE and p.get_node("Collision").shape.size==Vector2(10,28) and p.resources.max_health==100
 check(unchanged,"co-op does not tint hair skin or change hitboxes on "+role)
 if role=="host":
  var state:Dictionary=main.saves.capture()
  check(preload("res://scripts/save_schema.gd").validate(state)=="" and state.profiles.size()==4,"host ledger persists four full cosmetic records")
 await main.network.stop();await create_timer(.2).timeout
 if role!="host":check(main.player.appearance==LOOKS[index],"leaving restores own full appearance on "+role)
 main.queue_free();await process_frame;print("NETWORK_AVATAR_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
