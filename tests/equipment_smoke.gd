extends SceneTree
const Gear=preload("res://data/equipment.gd")
const Items=preload("res://data/items.gd")
var failures:=0
var checks:=0
var main:Node2D
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.player.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false
 var bag=main.items.local_inventory();bag.load_data([]);bag.add("wood",44)
 for item in ["wood_sword","wood_shield","wood_helm","wood_armor","wood_legs"]:
  check(bag.craft(item),"craft "+item)
 check(bag.count_item("wood")==0,"whole starter set uses 44 wood")
 for i in range(30):
  var item:String=bag.item_at(i)
  if item!="":check(main.equipment_service.move(1,i,Items.DEFINITIONS[item].equip_slot),"equip "+item)
 check(Gear.armor(main.player.equipment)==3 and bag.item_at(0)=="","armor moved out of inventory without copies")
 bag.add("dirt",10);var original:Array=bag.to_data();var gear_before:Dictionary=main.player.equipment.duplicate()
 check(not main.equipment_service.move(1,0,"head") and bag.to_data()==original and main.player.equipment==gear_before,"wrong-slot equip is atomic")
 bag.load_data([])
 for i in range(30):bag.slots[i]={"item":"dirt","count":99}
 check(not main.equipment_service.move(1,-1,"head") and main.player.equipment.head=="wood_helm","full bag keeps equipped item")
 bag.slots[5]={"item":"","count":0}
 check(main.equipment_service.into_bag(1,"head",5) and bag.item_at(5)=="wood_helm" and main.player.equipment.head=="","drag unequip into chosen cell")
 check(main.equipment_service.move(1,5,"head") and bag.item_at(5)=="","re-equip without duplicate")
 bag.load_data([]);bag.add("stone_blade",1)
 check(main.equipment_service.move(1,0,"weapon") and bag.item_at(0)=="wood_sword" and main.player.equipment.weapon=="stone_blade","weapon swap returns previous sword")
 main.equipment_service.move(1,0,"weapon")
 var state:Dictionary=main.saves.capture()
 check(preload("res://scripts/save_schema.gd").validate(state)=="","equipment save validates")
 main.player.equipment=Gear.empty();check(main.saves.restore(state)=="" and main.player.equipment.head=="wood_helm" and main.player.equipment.weapon=="wood_sword","equipment save roundtrip")
 bag=main.items.local_inventory()
 main.player.set_physics_process(false);main.player.hurt_immunity=0;main.player.health=100;main.player.fighter.reset();main.player.resources.stamina=100;main.player.facing=1
 main.equipment_service.block(1,true)
 check(main.player.fighter.mode=="block","R starts separate shield stance")
 var at:Vector2=main.player.position
 check(main.combat.receive_attack(1,20,at+Vector2(12,0),main.player)=="blocked" and main.player.resources.stamina==76 and main.player.health==96,"front block spends exact stamina and reduces chip with armor")
 main.player.hurt_immunity=0;main.player.health=100
 check(main.combat.receive_attack(1,20,at-Vector2(12,0),main.player)=="hit" and main.player.health==83,"rear hit bypasses shield but retains light armor")
 main.player.fighter.reset();main.player.hurt_immunity=0;main.player.health=100;main.equipment_service.block(1,true)
 check(main.combat.receive_attack(1,20,at-Vector2(12,0),main.player,true,true)=="hit" and main.player.health==83,"radial flag never turns frontal shield into rear protection")
 main.player.hurt_immunity=0;main.player.fighter.reset();main.player.resources.stamina=1;main.equipment_service.block(1,true)
 check(main.combat.receive_attack(1,20,at+Vector2(12,0),main.player)=="guard_broken" and main.player.resources.stamina==0 and main.player.fighter.mode=="guard_break","empty stamina breaks block")
 main.combat.tick_fighter(main.player,0.64);check(main.player.fighter.mode=="guard_break","guard break has recovery")
 main.combat.tick_fighter(main.player,0.02);check(main.player.fighter.mode=="idle","guard recovers after configured 0.65 seconds")
 main.player.resources.stamina=100;main.player.hurt_immunity=0
 check(main.combat.start_defense(1,"parry") and main.player.resources.stamina==86,"F remains separate 14-stamina parry")
 main.player.fighter.reset();main.player.equipment=Gear.empty();main.player.health=100
 main.combat.damage_player(1,20,at+Vector2(15,0));check(main.player.health==80,"unarmored damage unchanged")
 main.player.health=100;main.player.fighter.reset();main.player.hurt_immunity=0;main.player.resources.stamina=100;main.player.equipment.weapon="wood_sword"
 bag.load_data([])
 var enemy_id:int=main.combat.spawn_entity("seamling",main.player.position+Vector2(28,10))
 check(main.items.swing(main.player,0,Vector2.RIGHT),"equipped wood sword works from empty hotbar slot")
 check(main.player.resources.stamina==86,"wood sword costs data-defined 14 stamina")
 main.combat.tick_fighter(main.player,0.11);check(main.combat.entities[enemy_id].health==36,"windup has no premature damage")
 main.world.solid.update_internals();await physics_frame
 main.combat.tick_fighter(main.player,0.02);check(main.combat.entities[enemy_id].health==18,"wood sword deals exactly data-defined 18 on active phase")
 main.player.fighter.reset();main.player.equipment={"weapon":"wood_sword","head":"wood_helm","body":"wood_armor","legs":"wood_legs","shield":"wood_shield"};main.player.health=100;main.player.hurt_immunity=0
 for i in range(30):bag.slots[i]={"item":"dirt","count":99}
 main.combat.damage_player(1,1000,at,true)
 check(main.player.dead and main.player.equipment==Gear.empty() and bag.count_item("dirt")==0,"death removes worn gear and full inventory")
 var chest=main.combat.chests.values()[0]
 check(chest.contents.size()==30 and chest.equipment.weapon=="wood_sword" and chest.equipment.shield=="wood_shield","death chest retains full bag plus five gear pieces")
 var death_save:Dictionary=main.saves.capture()
 check(preload("res://scripts/save_schema.gd").validate(death_save)=="" and main.saves.restore(death_save)=="","death chest gear survives save roundtrip")
 main.combat.respawn(main.player);check(main.player.equipment==Gear.empty(),"respawn does not grant another starter set")
 var fresh_bag=main.items.local_inventory();fresh_bag.add("wood_helm",1);main.equipment_service.move(1,0,"head")
 check(main.player.unclothed and main.player.equipment.head=="wood_helm","equipping one piece after death never restores free base clothing")
 var chest_cell:Vector2i=main.world.cell_at(main.combat.chests.values()[0].position)
 check(main.combat.break_chest(main.player,chest_cell),"saved full death chest can be broken")
 var recovered:={}
 for drop in main.items.drops.values():recovered[drop.item_id]=int(recovered.get(drop.item_id,0))+drop.count
 check(recovered.get("dirt",0)==2970 and recovered.get("wood_sword",0)==1 and recovered.get("wood_shield",0)==1 and recovered.get("wood_armor",0)==1 and recovered.get("wood_legs",0)==1 and recovered.get("wood_helm",0)==1,"breaking chest recovers all thirty stacks and five gear pieces exactly once")
 var inventory=preload("res://scripts/inventory.gd").new();inventory.add("wood",99);inventory.slots[10]={"item":"wood","count":95}
 check(inventory.quick_to(inventory,0,range(10,30)) and inventory.slots[10].count==99 and inventory.slots[11].count==95 and inventory.slots[0].count==0,"Shift move fills partial stack then empty cell in one operation")
 for i in range(30):inventory.slots[i]={"item":"dirt","count":99}
 var snapshot:Array=inventory.to_data()
 check(not inventory.quick_to(inventory,0,range(10,30)) and inventory.to_data()==snapshot,"full destination rejects quick transfer without loss")
 var bad:Dictionary=death_save.duplicate(true);bad.profiles[bad.host_profile].life.equipment={"head":"wood_sword"}
 check(preload("res://scripts/save_schema.gd").validate(bad)!="","schema rejects wrong gear slot")
 main.queue_free();await process_frame;print("EQUIPMENT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
