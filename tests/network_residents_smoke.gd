extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var role:=OS.get_cmdline_user_args()[0]
 var app=root.get_node("GameApp")
 app.selected_character={"appearance":{"gender":"female","hair":"long","skin":4}}
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.exploration.set_process(false);main.items.set_physics_process(false);main.player.set_physics_process(false);main.encounter.enabled=false
 if role=="host":
  main.world.configure_new();main.world.generate();main.npcs.sync()
  main.player.position=main.world.npc_records.julia.position+Vector2(24,0)
  main.network.peer_admitted.connect(func(id):
   var body=main.get_node("Players").get_node(str(id));body.set_physics_process(false);body.position=main.world.npc_records.julia.position+Vector2(32,0))
  check(main.network.host_game()==OK,"host starts");print("RESIDENT_HOST_READY")
 else:check(main.network.join_game("127.0.0.1")==OK,"client connects")
 var start:=Time.get_ticks_msec();var seen:=false;var local_dialogue:=false;var appearance:=false
 while Time.get_ticks_msec()-start<(6500 if role=="host" else 4500):
  await process_frame
  if not main.network.connected:continue
  if role=="client" and main.world.generator_version==3 and main.npcs.actors.size()==2:
   seen=true
   if not local_dialogue and main.npcs.nearest()=="julia":local_dialogue=main.npcs.talk("julia")
   appearance=appearance or main.player.appearance.skin==4
  elif role=="host" and main.get_node("Players").get_child_count()==2:
   seen=true
   for body in main.get_node("Players").get_children():
    if body!=main.player:appearance=appearance or body.appearance.skin==4
 if role=="client":
  check(seen and main.world.world_width==512,"generator3 and NPC bootstrap")
  check(local_dialogue and main.ui_blocked(),"client local dialogue blocks only its commands")
  check(appearance,"selected client appearance retained")
 else:
  check(seen and not main.npcs.opened and not main.ui_blocked(),"client dialogue never opens on host")
  check(appearance,"host accepts authoritative client appearance")
  check(main.npcs.actors.size()==2,"no duplicate resident network nodes")
 main.network.stop();await create_timer(0.2).timeout;main.queue_free();await process_frame
 print("RESIDENT_NETWORK_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
