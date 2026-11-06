extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func key(code:Key,pressed:bool) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.player.set_physics_process(false);main.combat.spawning_enabled=false;main.encounter.enabled=false
 main.player.equipment.shield="wood_shield"
 for i in range(4):await process_frame
 key(KEY_R,true);await physics_frame;await physics_frame
 check(main.player.fighter.mode=="block","real R raises equipped shield")
 key(KEY_R,false);await physics_frame;await physics_frame
 check(main.player.fighter.mode=="idle","release R lowers shield")
 key(KEY_P,true);await process_frame;key(KEY_P,false);await process_frame
 check(paused and main.pause_open and main.network_row.visible and main.network_row.can_process(),"offline pause exposes usable network controls")
 var before:float=main.combat.world_time
 await create_timer(.1).timeout
 check(main.combat.world_time==before,"offline pause really freezes shared time")
 var host:Button
 var leave:Button
 for node in main.network_row.get_children():
  if node is Button and node.text=="Создать сервер":host=node
  if node is Button and node.text=="Отключиться":leave=node
 host.pressed.emit();await process_frame
 check(main.network.active and not paused and main.pause_open,"hosting from pause starts simulation while local input stays blocked")
 before=main.combat.world_time
 await create_timer(.15).timeout
 check(main.combat.world_time>before and main.ui_blocked(),"paused host menu never freezes network world")
 leave.pressed.emit();for i in range(8):await process_frame
 check(not main.network.active and paused,"disconnect restores offline pause")
 main.pause_ui.resume();check(not paused and not main.pause_open,"resume restores local controls")
 main.queue_free();await process_frame;print("RECAST_INPUT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
