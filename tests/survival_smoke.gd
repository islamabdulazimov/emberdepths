extends SceneTree
const Rules=preload("res://data/survival.gd")
const Gear=preload("res://data/equipment.gd")
const Schema=preload("res://scripts/save_schema.gd")
var main:Node2D
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func cash_on_ground() -> int:
 var total:=0
 for coin in main.survival.coins.values():total+=coin.amount
 return total
func down(p:CharacterBody2D) -> void:
 p.revive_immunity=0;p.hurt_immunity=0;main.combat.damage_player(int(str(p.name)),10000,p.position,true)
func help_step(id:int,target:int,delta:float) -> void:
 main.survival.intent(id,target,true);main.survival.tick_help(delta)
func run() -> void:
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.player.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.survival.set_physics_process(false);main.interaction.set_process(false);main.exploration.set_process(false);main.encounter.enabled=false;main.combat.spawning_enabled=false
 for x in range(80,115):
  for y in range(10,25):main.world.apply_edit(Vector2i(x,y),-1)
  main.world.apply_edit(Vector2i(x,25),2)
 main.world.solid.update_internals();await physics_frame
 var p=main.player;var c=main.combat;var s=main.survival;var bag=main.items.local_inventory()
 p.position=Vector2(1544,390);main.equipment_service.starter(1);bag.add("wood",33);p.money=101
 var before:Array=bag.to_data();var worn:Dictionary=p.equipment.duplicate()
 down(p)
 check(p.dead and p.health==0 and p.money==51 and cash_on_ground()==50,"downing drops floor half wallet once")
 check(bag.to_data()==before and p.equipment==worn and not p.unclothed,"downing preserves bag armor and clothing")
 check(c.chests.is_empty() and c.entities.is_empty(),"new death creates neither chest nor spirit")
 check(not c.damage_player(1,100,p.position,true) and p.money==51 and cash_on_ground()==50,"duplicate lethal damage cannot charge twice")
 c._physics_process(120)
 check(p.dead and p.respawn_remaining==0,"downed player has no automatic death or respawn timer")
 check(not main.items.swing(p,0,Vector2.RIGHT) and not c.start_defense(1,"parry") and not main.equipment_service.move(1,-1,"head"),"downed character cannot attack defend or equip")
 check(s.respawn_request(1) and not s.respawn_request(1),"explicit respawn is idempotent")
 check(p.health==100 and p.equipment==worn and bag.to_data()==before and p.money==51,"respawn retains gear bag and remaining wallet")
 p.position=Vector2(1544,390);down(p)
 check(p.money==26 and cash_on_ground()==75 and s.coins.size()==2,"next death drops half remainder without deleting previous coins")
 c.respawn(p);p.position=Vector2(1304,390);p.hurt_immunity=0
 var mob_id:int=c.spawn_entity("ashling",Vector2(1544,400));var mob=c.entities[mob_id]
 mob.set_process(false)
 for coin in s.coins.values():coin.age=1;coin.position=mob.position;coin.velocity=Vector2.ZERO
 s.tick_coins(0)
 check(s.coins.is_empty() and mob.money==75 and p.money==26,"any nearby ordinary mob can collect actual ground money")
 var saved_mob:Dictionary=c.entity_data(mob_id);c.set_entity(mob_id,saved_mob)
 check(c.entities[mob_id].money==75,"mob snapshot restores held money once")
 c.hit_entity(mob_id,1000,Vector2.RIGHT)
 check(cash_on_ground()==75+Rules.MOB_REWARD and not c.entities.has(mob_id),"mob death returns all money plus provisional base reward")
 var another:int=c.spawn_entity("seamling",Vector2(1544,400));c.entities[another].money=13
 c.set_entity(another,{})
 check(cash_on_ground()==88+Rules.MOB_REWARD,"system removal refunds carried coins without kill reward")
 var far_coin:int=s.spawn_money(7,Vector2(-500,100000))
 check(Schema.point(s.coins[far_coin].position,main.world.world_width,main.world.world_depth),"invalid removal position relocates money to accessible world")
 for id in s.coins.keys():s.set_coin(id,{})
 var coin_id:int=s.spawn_money(17,p.position);s.coins[coin_id].age=1;p.money=Rules.MAX_MONEY-2
 s.tick_coins(0)
 check(p.money==Rules.MAX_MONEY and s.coins[coin_id].amount==15,"full wallet keeps exact uncollected remainder")
 p.money=0;s.tick_coins(0)
 check(p.money==15 and not s.coins.has(coin_id),"remainder can be collected once space exists")
 main.add_player(2,Vector2(1568,390));var helper=main.get_node("Players/2");helper.profile_id="2".repeat(32);helper.set_physics_process(false)
 main.add_player(3,Vector2(1520,390));var helper2=main.get_node("Players/3");helper2.profile_id="3".repeat(32);helper2.set_physics_process(false)
 p.position=Vector2(1544,390);down(p);var money_after_death:int=p.money
 s.intent(2,1,true);s.tick_help(1)
 check(s.channels.is_empty(),"help requires real consumable")
 var hb=main.items.inventory_for(2);hb.add(Rules.HELP_ITEM,3);main.items.inventory_for(3).add(Rules.HELP_ITEM,2)
 help_step(2,1,2)
 check(p.dead and is_equal_approx(helper.help_progress,.5) and hb.count_item(Rules.HELP_ITEM)==3,"partial help spends nothing")
 s.intent(2,1,false)
 check(s.channels.is_empty() and helper.help_progress==0 and hb.count_item(Rules.HELP_ITEM)==3,"release resets help without consuming")
 help_step(2,1,2);helper.position.x+=100;s.tick_help(.1)
 check(s.channels.is_empty() and hb.count_item(Rules.HELP_ITEM)==3,"walking out of range cancels help")
 helper.position=Vector2(1568,390);help_step(2,1,2);helper.hurt_immunity=0
 c.damage_player(2,5,helper.position+Vector2(10,0))
 check(s.channels.is_empty() and helper.help_progress==0 and hb.count_item(Rules.HELP_ITEM)==3,"damage immediately cancels progress without item loss")
 helper.fighter.reset();helper.move_command=0;helper.jump_command=false;helper.hurt_immunity=0
 help_step(2,1,1.99);s.intent(3,1,true);s.tick_help(1.99)
 check(p.dead and hb.count_item(Rules.HELP_ITEM)==3 and main.items.inventory_for(3).count_item(Rules.HELP_ITEM)==2,"two helpers cannot accelerate or spend twice")
 help_step(2,1,.03)
 check(not p.dead and p.health==30 and p.revive_immunity==1.5 and hb.count_item(Rules.HELP_ITEM)==2 and main.items.inventory_for(3).count_item(Rules.HELP_ITEM)==2,"four seconds consumes exactly one and revives at thirty percent")
 check(p.money==money_after_death and p.equipment==worn,"revive does not charge money or strip equipment")
 check(not c.damage_player(1,99,p.position,true) and c.receive_attack(1,99,p.position,helper)=="immune","revive protection covers hazards and attacks")
 c._physics_process(1.49);check(not c.damage_player(1,99,p.position,true),"full revival immunity lasts through 1.49 seconds")
 c._physics_process(.02);check(c.damage_player(1,10,p.position,true),"revival protection ends at configured time")
 down(p);helper.fighter.reset();s.intents.clear();help_step(2,1,1)
 main.remove_player(2)
 check(s.channels.is_empty(),"disconnecting helper cancels channel")
 s.intents.clear();helper2.fighter.reset();help_step(3,1,1)
 check(s.respawn_request(1) and s.channels.is_empty() and main.items.inventory_for(3).count_item(Rules.HELP_ITEM)==2,"explicit respawn cancels help without consuming")
 check(s.spawn_money(0,p.position)==-1 and s.spawn_money(-1,p.position)==-1,"invalid amounts never create money")
 var state:Dictionary=main.saves.capture()
 check(Schema.validate(state)=="","current snapshot with money and downed rules validates")
 var invalid:Dictionary=state.duplicate(true);invalid.profiles[invalid.host_profile].life.money=-1
 check(Schema.validate(invalid)!="","schema rejects negative wallet")
 invalid=state.duplicate(true);invalid.combat.economy.coins[999]={"amount":1,"position":p.position,"velocity":Vector2.ZERO,"age":0}
 check(Schema.validate(invalid)!="","schema rejects invalid money identifiers")
 main.queue_free();await process_frame
 print("SURVIVAL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
