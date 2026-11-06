extends SceneTree
var failures:=0
func check(ok:bool,label:String) -> void:
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var mode:String=OS.get_cmdline_user_args()[0]
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.player.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false
 if mode=="write":
  main.player.equipment.ability="traveler_knot";main.player.roll_cooldown=4.25;main.player.guard_cooldown=.3;main.player.health=87;main.player.resources.mana=19
  main.items.local_inventory().add("wood",17)
  check(main.saves.save_now(),"save ability and remaining defense cooldowns to real disk")
 else:
  check(main.player.equipment.ability=="traveler_knot" and main.player.roll_cooldown==4.25 and main.player.guard_cooldown==.3,"fresh process restores ability and exact defense delays")
  check(main.player.health==87 and main.player.resources.mana==19 and main.items.local_inventory().count_item("wood")==17,"restart preserves resources and inventory")
  check(not main.combat.start_defense(1,"roll") and not main.combat.player_data(main.player).has("stamina"),"restart cannot bypass roll cooldown or recreate stamina")
 main.queue_free();await process_frame;print("ADVENTURE_RESTART_FAILURES ",failures);quit(1 if failures else 0)
