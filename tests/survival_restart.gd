extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var mode:String=OS.get_cmdline_user_args()[0]
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.items.set_physics_process(false);main.player.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false;main.combat.spawning_enabled=false
 if mode=="write":
  main.equipment_service.starter(1);main.items.local_inventory().add("wood",99)
  main.player.money=101;main.combat.damage_player(1,1000,main.player.position,true)
  var id:int=main.combat.spawn_entity("ashling",main.player.position+Vector2(120,0));main.combat.entities[id].money=13
  main.survival.recovery["e".repeat(32)]=[{"item":"wood","count":9}]
  check(main.saves.save_now(),"persist downed character coin pile mob wallet and deferred owner items")
 else:
  check(main.player.dead and main.player.money==51 and main.player.equipment.head=="wood_helm" and main.items.local_inventory().count_item("wood")==99,"fresh process preserves downed state gear items and wallet")
  check(main.survival.coins.size()==1 and main.survival.coins.values()[0].amount==50,"restart never deletes or duplicates dropped money")
  check(main.combat.entities.size()==1 and main.combat.entities.values()[0].money==13,"restart restores money held by mob")
  check(main.survival.recovery["e".repeat(32)][0].count==9,"restart preserves offline owner recovery")
  main.combat._physics_process(50)
  check(main.player.dead and main.player.money==51,"time after restart neither respawns nor charges again")
  check(main.saves.save_now(),"resaving downed state succeeds")
 main.queue_free();await process_frame
 print("SURVIVAL_RESTART_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
