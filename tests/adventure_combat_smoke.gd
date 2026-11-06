extends SceneTree
const Gear=preload("res://data/equipment.gd")
const Battle=preload("res://data/battle.gd")
const Schema=preload("res://scripts/save_schema.gd")
var main:Node2D
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.interaction.set_process(false);main.items.set_physics_process(false);main.combat.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false;main.combat.spawning_enabled=false;main.player.set_physics_process(false)
 for x in range(88,105):
  for y in range(12,22):main.world.apply_edit(Vector2i(x,y),-1)
  main.world.apply_edit(Vector2i(x,22),2)
 main.world.solid.update_internals();await physics_frame
 var p=main.player;var c=main.combat;var bag=main.items.local_inventory()
 p.position=Vector2(1544,342);p.hurt_immunity=0
 check(not c.start_defense(1,"roll") and p.fighter.mode=="idle","no innate roll without equipped ability")
 main.equipment_service.starter(1)
 check(p.equipment.ability=="" and bag.count_item("traveler_knot")==0,"starter wooden set never grants free roll")
 bag.load_data([]);bag.add("wood",8);bag.add("emberstone",2)
 check(main.items.craft(1,"traveler_knot").begins_with("Создано") and bag.count_item("wood")==0 and bag.count_item("emberstone")==0,"temporary ability recipe spends exact common materials")
 check(not main.equipment_service.move(1,0,"head") and bag.count_item("traveler_knot")==1,"ability cannot occupy armor slot or disappear")
 check(main.equipment_service.move(1,0,"ability") and bag.count_item("traveler_knot")==0,"ability can be equipped in its own slot")
 check(c.start_defense(1,"roll") and p.roll_cooldown==6 and p.fighter.direction==Vector2.RIGHT,"equipped ability starts server-owned cooldown")
 check(not c.start_defense(1,"roll") and not p.fighter.roll_invulnerable(),"startup remains vulnerable and cannot be restarted")
 c.tick_fighter(p,.06)
 check(c.receive_attack(1,20,p.position+Vector2(16,0),p)=="dodged" and p.health==100,"original short roll window still avoids hit")
 c.tick_fighter(p,.38)
 check(not c.start_defense(1,"roll") and p.roll_cooldown==6,"finishing animation does not clear cooldown")
 check(main.equipment_service.move(1,-1,"ability") and p.equipment.ability=="","unequipping removes access")
 check(main.equipment_service.move(1,0,"ability") and not c.start_defense(1,"roll"),"re-equipping does not bypass cooldown")
 var state:Dictionary=main.saves.capture()
 check(Schema.validate(state)=="" and not state.profiles[state.host_profile].life.has("stamina"),"new save includes cooldown without stamina")
 p.roll_cooldown=0;check(main.saves.restore(state)=="" and main.player.roll_cooldown==6 and main.player.equipment.ability=="traveler_knot","save restore preserves ability and remaining delay")
 p=main.player;bag=main.items.local_inventory();p.set_physics_process(false)
 c._physics_process(5.99);check(not c.start_defense(1,"roll"),"roll cannot restart just before cooldown ends")
 c._physics_process(.02);check(c.start_defense(1,"roll"),"roll becomes available after cooldown")
 p.fighter.reset();p.position.y=64;p.roll_cooldown=0
 check(not c.start_defense(1,"roll") and p.roll_cooldown==0,"airborne rejection never spends cooldown")
 p.position=Vector2(1544,342)
 p.equipment.ability=""
 check(c.start_defense(1,"parry") and not c.start_defense(1,"parry"),"parry works without roll item but keeps recovery against spam")
 c.tick_fighter(p,.59);check(c.start_defense(1,"parry"),"parry returns only after its existing timing")
 p.fighter.reset();bag.load_data([]);bag.add("wood_sword",1)
 var swings:=0
 for i in range(30):
  if main.items.swing(p,0,Vector2.RIGHT):swings+=1
  c.tick_fighter(p,.48)
 check(swings==30 and p.resources.mana==50 and p.health==100,"thirty completed swings need no replacement resource")
 check(not p.resources.snapshot().has("stamina") and main.get_node("HUD/PlayerResources").bars.size()==2,"runtime and HUD contain only health and mana")
 p.equipment.shield="wood_shield";p.equipment.head="";p.equipment.body="";p.equipment.legs="";p.hurt_immunity=0
 main.equipment_service.block(1,true);c.tick_fighter(p,.7)
 check(c.receive_attack(1,20,p.position+Vector2(16,0),p)=="blocked" and p.health==95 and is_equal_approx(p.fighter.elapsed,.7),"front block leaks damage and hit cannot extend hold")
 p.hurt_immunity=0
 check(c.receive_attack(1,20,p.position+Vector2(16,0),p)=="blocked" and p.health==90 and is_equal_approx(p.fighter.elapsed,.7),"repeated hit still preserves original hold timer")
 c.tick_fighter(p,.51)
 check(p.fighter.mode=="idle" and p.guard_cooldown==Gear.SHIELD.recovery,"shield expires into configured recovery")
 main.equipment_service.block(1,true);check(p.fighter.mode=="idle","held R cannot restart during recovery")
 c._physics_process(.46);main.equipment_service.block(1,true)
 check(p.fighter.mode=="idle","held R cannot restart after cooldown without release")
 main.equipment_service.block(1,false);main.equipment_service.block(1,true)
 check(p.fighter.mode=="block","released R allows next block")
 var held_save:Dictionary=main.saves.capture()
 check(held_save.profiles[held_save.host_profile].life.guard_cooldown==Gear.SHIELD.recovery and not held_save.profiles[held_save.host_profile].life.has("action"),"saving active shield enforces recovery instead of restoring a free hold")
 check(main.equipment_service.move(1,-1,"shield") and p.fighter.mode=="idle" and p.guard_cooldown>0,"unequipping an active shield ends hold with recovery")
 check(main.equipment_service.move(1,1,"shield") and p.guard_cooldown>0,"re-equipping shield never resets recovery")
 main.equipment_service.block(1,false);main.equipment_service.block(1,true)
 check(p.fighter.mode=="idle" and p.guard_cooldown>0,"tap-spamming shield still observes release recovery")
 c._physics_process(.46);main.equipment_service.block(1,false);main.equipment_service.block(1,true);p.hurt_immunity=0
 check(c.receive_attack(1,20,p.position-Vector2(16,0),p)=="hit" and p.health==70,"rear attack bypasses shield and ends hold")
 check(p.guard_cooldown>0,"damage interruption also imposes shield recovery")
 p.fighter.reset();p.health=40;p.hurt_immunity=0;bag.load_data([]);bag.add("spark_balm",2)
 check(main.items.medicine_step(p,0,1) and p.health==70 and p.medicine_cooldown==15,"healing uses fifteen-second global cooldown")
 c._physics_process(14.9)
 check(not main.items.medicine_step(p,0,1) and p.health==70 and bag.count_item("spark_balm")==1,"cooldown is shared and health never passively regenerates")
 c._physics_process(.11);check(main.items.medicine_step(p,0,1) and p.health==100 and bag.count_item("spark_balm")==0,"healing works after shared cooldown")
 # Original bytes must survive the first disk upgrade, including old death chest contents.
 var legacy:Dictionary=main.saves.capture();legacy.erase("combat_rules")
 legacy.profiles[legacy.host_profile].life.merge({"stamina":0,"max_stamina":140,"stamina_delay":.8})
 legacy.profiles[legacy.host_profile].life.equipment.erase("ability")
 var inv=preload("res://scripts/inventory.gd").new();inv.add("wood",99)
 legacy.combat.chests[1]={"position":p.position,"owner":1,"profile":p.profile_id,"contents":inv.to_data(),"equipment":{"head":"wood_helm"}}
 legacy.combat.next_chest=2
 var codec=preload("res://scripts/save_codec.gd").new();var payload:=JSON.stringify(codec.encode(legacy))
 var original:=JSON.stringify({"version":1,"payload":payload,"sha256":payload.sha256_text()})
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(main.saves.save_path.get_base_dir()))
 var f:=FileAccess.open(main.saves.save_path,FileAccess.WRITE);f.store_string(original);f.close()
 check(main.saves.load_now(),"legacy save loads with old stamina fields and no ability slot")
 var backup_path:String=main.saves.save_path+".pre-adventure.original"
 check(FileAccess.get_file_as_string(backup_path)==original,"upgrade stores immutable byte-identical original")
 check(main.player.equipment.ability=="" and not main.combat.player_data(main.player).has("stamina"),"legacy player gets empty ability and no resource resurrection")
 check(main.combat.chests[1].contents[0].count==99 and main.combat.chests[1].equipment.head=="wood_helm","legacy death chest items remain intact until dedicated migration")
 check(main.saves.save_now() and main.saves.load_now() and FileAccess.get_file_as_string(backup_path)==original,"saving and reloading new rules never overwrites original backup")
 var invalid:Dictionary=main.saves.capture();invalid.profiles[invalid.host_profile].life.roll_cooldown=INF
 check(Schema.validate(invalid)!="","schema rejects invalid ability cooldown")
 invalid=main.saves.capture();invalid.profiles[invalid.host_profile].life.guard_cooldown=-1
 check(Schema.validate(invalid)!="","schema rejects negative shield recovery")
 main.queue_free();await process_frame
 print("ADVENTURE_COMBAT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
