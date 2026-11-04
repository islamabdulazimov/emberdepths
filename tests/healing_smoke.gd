extends SceneTree
const Schema = preload("res://scripts/save_schema.gd")
const Inventory = preload("res://scripts/inventory.gd")
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")

func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.set_physics_process(false)
 main.combat.spawning_enabled = false
 main.items.set_physics_process(false)
 main.player.set_physics_process(false)
 var player = main.player
 var service = main.items
 var bag = service.local_inventory()
 bag.add("wood",2)
 bag.add("emberstone",1)
 check_result(service.craft(1,"spark_balm").begins_with("Создано") and bag.count_item("spark_balm") == 2 and bag.count_item("wood") == 0 and bag.count_item("emberstone") == 0,"Balm recipe consumes exact wood and fuel for two portions")
 var stack = Inventory.new()
 stack.add("spark_balm",21)
 check_result(stack.slots[0].count == 20 and stack.slots[1].count == 1,"Balm stacks have a dedicated limit of twenty")
 player.health = 60
 check_result(not service.use_primary(player,Vector2i.ZERO,0) and player.health == 60,"Direct primary completion cannot bypass preparation")
 service.medicine_step(player,0,0.4)
 check_result(player.health == 60 and bag.count_item("spark_balm") == 2 and is_equal_approx(player.medicine_progress,0.4),"Preparation shows progress without early healing or consumption")
 service.medicine_step(player,-1,0)
 check_result(player.medicine_progress == 0 and bag.count_item("spark_balm") == 2,"Releasing cancels without spending the portion")
 service.medicine_step(player,0,0.5)
 service.medicine_step(player,1,0.5)
 check_result(player.medicine_progress == 0 and player.health == 60,"Changing selected slot cancels preparation")
 service.medicine_step(player,0,0.9)
 check_result(player.health == 60 and bag.count_item("spark_balm") == 2,"Short hold cannot complete the heal")
 check_result(service.medicine_step(player,0,0.1) and player.health == 90 and bag.count_item("spark_balm") == 1,"One full second heals thirty and consumes exactly one")
 check_result(player.medicine_cooldown == 6 and player.medicine_progress == 0 and player.heal_flash_amount == 30,"Successful use sets global cooldown and actual heal feedback")
 check_result(player.resources.stamina == 100 and player.resources.mana == 50 and player.hurt_immunity == 0,"Healing does not grant stamina mana or invulnerability")
 check_result(not service.medicine_step(player,0,2) and player.health == 90 and bag.count_item("spark_balm") == 1,"Held input cannot bypass medicine cooldown")
 main.combat._physics_process(3)
 check_result(player.medicine_cooldown == 3 and player.health == 90,"Cooldown counts down without passive health regeneration")
 main.combat._physics_process(3)
 player.health = 95
 check_result(service.medicine_step(player,0,1) and player.health == 100 and player.heal_flash_amount == 5 and bag.count_item("spark_balm") == 0,"Near-full health clamps healing and reports actual restored amount")
 check_result(player.medicine_latch == 0 and player.medicine_progress == 0,"Last consumed portion keeps self-use input latched")
 bag.add("spark_balm",3)
 player.medicine_cooldown = 0
 check_result(not service.medicine_step(player,0,1) and bag.count_item("spark_balm") == 3,"Full health does not consume or start cooldown")
 player.health = 60
 check_result(not service.medicine_step(player,10,1) and not service.medicine_step(player,-2,1),"Invalid and non-hotbar slots cannot use medicine")
 player.dead = true
 check_result(not service.medicine_step(player,0,1) and bag.count_item("spark_balm") == 3,"Dead player cannot use a healing item")
 player.dead = false
 service.medicine_step(player,0,0.4)
 main.combat.damage_player(1,10,player.position-Vector2(10,0))
 check_result(player.health == 50 and player.medicine_progress == 0 and player.medicine_cooldown == 0.6 and bag.count_item("spark_balm") == 3,"Real damage interrupts preparation with no item loss")
 check_result(not service.medicine_step(player,0,1),"Interruption has a brief retry delay")
 main.combat._physics_process(0.6)
 service.medicine_step(player,0,0.5)
 var before: float = player.medicine_progress
 check_result(not main.combat.damage_player(1,10,player.position) and player.medicine_progress == before,"Damage rejected by immunity does not cancel a valid use")
 service.cancel_medicine(player)
 service.medicine_step(player,0,0.3)
 main.combat.heal_player(1,100)
 service.medicine_step(player,0,0.8)
 check_result(player.health == 100 and player.medicine_progress == 0 and bag.count_item("spark_balm") == 3,"External healing to full cancels pending use without spending")
 player.health = 50
 player.play_swing(Vector2.RIGHT)
 check_result(not service.medicine_step(player,0,1),"An already-started attack finishes before healing can begin")
 player.swing_remaining = 0
 service.medicine_step(player,0,0.4)
 bag.transfer(0,1)
 check_result(not service.medicine_step(player,0,0.6) and bag.count_item("spark_balm") == 3 and player.health == 50,"Moving the selected stack cannot finish or consume a missing portion")
 bag.transfer(1,0)
 check_result(service.medicine_step(player,0,1),"Medicine remains usable after cancellation and inventory transfer")
 main.combat._physics_process(1.25)
 main.saves.save_path = "user://tests/healing.json"
 check_result(main.saves.save_now(),"Healing state saves to disk")
 var saved: Dictionary = main.saves.capture()
 player.medicine_cooldown = 0
 player.health = 20
 bag.load_data([])
 check_result(main.saves.load_now() and main.player.health == 80 and is_equal_approx(main.player.medicine_cooldown,4.75) and service.local_inventory().count_item("spark_balm") == 2,"Load restores exact health remaining portions and cooldown")
 player = main.player
 player.set_physics_process(false)
 player.medicine_cooldown = 0
 player.health = 50
 service.medicine_step(player,0,0.5)
 check_result(main.saves.save_now() and main.saves.capture().profiles[main.saves.profile_id].life.medicine_progress == 0,"Save records no unfinished consumption")
 check_result(main.saves.load_now() and main.player.medicine_progress == 0 and main.player.medicine_slot == -1 and main.player.health == 50 and service.local_inventory().count_item("spark_balm") == 2,"Loading cannot complete or lose a pending portion")
 var invalid := saved.duplicate(true)
 invalid.profiles[main.saves.profile_id].life.medicine_cooldown = -1
 check_result(Schema.validate(invalid) != "","Schema rejects negative cooldown")
 invalid = saved.duplicate(true)
 invalid.profiles[main.saves.profile_id].life.medicine_progress = 2
 check_result(Schema.validate(invalid) != "","Schema rejects out-of-range use progress")
 var legacy := saved.duplicate(true)
 legacy.profiles[main.saves.profile_id].life.erase("medicine_cooldown")
 legacy.profiles[main.saves.profile_id].life.erase("medicine_progress")
 check_result(main.saves.restore(legacy) == "" and main.player.medicine_cooldown == 0,"Old saves load with no medicine cooldown by default")
 player = main.player
 player.set_physics_process(false)
 player.hurt_immunity = 0
 service.medicine_step(player,0,0.4)
 main.combat.damage_player(1,10000,player.position,true)
 var in_chest := 0
 for chest in main.combat.chests.values():
  for item in chest.contents:
   if item.item == "spark_balm": in_chest += item.count
 check_result(player.dead and player.medicine_progress == 0 and in_chest == 2,"Death cancels use and moves unconsumed portions into the death chest")
 main.combat._physics_process(0.2)
 check_result(is_equal_approx(player.medicine_cooldown,0.4),"Cooldown continues ticking while waiting to respawn")
 main.combat.respawn(player)
 check_result(player.health == 100 and player.medicine_progress == 0 and is_equal_approx(player.medicine_cooldown,0.4),"Respawn gives full resources without resetting remaining cooldown")
 main.get_node("HUD/PlayerResources")._process(0)
 check_result(main.get_node("HUD/PlayerResources").progress.text.begins_with("Бальзам"),"HUD shows the shared cooldown even after changing items")
 print("Healing failures: ",failures)
 quit(1 if failures else 0)
