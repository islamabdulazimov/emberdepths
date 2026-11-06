extends SceneTree
var failures := 0
var cuts := 0
var wood_drops: Dictionary = {}
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")

func run() -> void:
 var role := OS.get_cmdline_user_args()[0]
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.set_physics_process(false)
 main.player.set_physics_process(false)
 var record: Dictionary = main.world.trees[0]
 var cell: Vector2i = record.cell + Vector2i.UP
 var build: Vector2i = record.cell + Vector2i(2,-1)
 var at := Vector2(record.cell.x*16+8,record.cell.y*16-10)
 var admissions := [0]
 if role == "host":
  for x in range(record.cell.x-5,record.cell.x+6):
   for y in range(record.cell.y-3,record.cell.y): main.world.apply_edit(Vector2i(x,y),-1)
   main.world.apply_edit(Vector2i(x,record.cell.y),0)
  main.world.solid.update_internals()
  main.player.position = at + Vector2(-64,0)
  main.items.local_inventory().add("stone_axe",1)
  main.network.peer_admitted.connect(func(id):
   admissions[0] += 1
   var body = main.get_node("Players").get_node(str(id))
   body.set_physics_process(false)
   body.position = at + Vector2(18 if admissions[0] == 1 else 64,0)
   if admissions[0] == 1:
    main.items.inventory_for(id).add("stone",4)
    main.items.inventory_for(id).add("dirt",2))
  main.items.tree_felled.connect(func(_index,_direction):
   cuts += 1
   print("TREE_CUT"))
  main.items.drop_changed.connect(func(id,data):
   if data.get("item","") == "wood": wood_drops[id] = data.count)
  check_result(main.network.host_game() == OK,"Logging host starts")
 else:
  main.network.join_game("127.0.0.1")
 var start := Time.get_ticks_msec()
 var craft_sent := false
 var wood_craft_sent := false
 var first_axe := 0
 var short_hold_checked := false
 var saw_tool := false
 var saw_built := false
 var saw_late_state := false
 var local_guard_checked := false
 var host_joined_chop := false
 while Time.get_ticks_msec() - start < (7500 if role == "host" else (5500 if role == "logger" else 4000)):
  await process_frame
  if not main.network.active or not main.network.connected: continue
  for body in main.get_node("Players").get_children():
   if body.swing_tool and body.swing_remaining > 0: saw_tool = true
  if main.world.block_at(build) == 4: saw_built = true
  if role == "late" and not saw_late_state:
   saw_late_state = true
   check_result(not main.world.trees[0].active,"Late join receives the felled tree")
  if role == "host":
   # Join the same tree slightly later: the first finisher must be the only one
   # to get a successful harvest, even though both host and client hold LMB.
   if main.get_node("Players").get_child_count() > 1:
    for peer_id in main.network.mining:
     if peer_id != 1 and main.network.mining[peer_id].time > 0.4: host_joined_chop = true
   if host_joined_chop and main.world.trees[0].active:
    main.network.submit_local(0,false,cell,1,0,1.0/60.0)
  elif role == "logger":
   var bag = main.items.local_inventory()
   if not craft_sent:
    main.network.craft_local("stone_axe")
    craft_sent = true
   if bag.item_at(0) == "stone_axe" and first_axe == 0:
    first_axe = Time.get_ticks_msec()
   if first_axe == 0: continue
   if not local_guard_checked:
    local_guard_checked = true
    check_result(not main.items.chop_tree(main.player,cell,0) and main.world.trees[0].active,"Client cannot fell tree or create wood locally")
   if not short_hold_checked and Time.get_ticks_msec()-first_axe > 600:
    short_hold_checked = true
    check_result(main.world.trees[0].active,"Short hold cannot bypass host logging timer")
   if main.world.trees[0].active:
    main.network.submit_local(0,false,cell,1,0,1.0/60.0)
   elif bag.count_item("wood") >= 2 and not wood_craft_sent:
    main.network.submit_local(0,false,cell,0,0,1.0/60.0)
    main.network.craft_local("wood_block")
    wood_craft_sent = true
   elif bag.count_item("wood_block") > 0 and not saw_built:
    main.network.submit_local(0,false,build,2,2,1.0/60.0)
   else: main.network.submit_local(0,false,build,0,2,1.0/60.0)
 check_result(not main.world.trees[0].active,"Harvest state is shared on "+role)
 check_result(saw_built and main.world.solid.get_cell_source_id(build) == 2,"Wooden block uses shared collision tile on "+role)
 if role == "host":
  check_result(cuts == 1 and wood_drops.size() == 1 and wood_drops.values()[0] == record.height,"Two simultaneous loggers create one exact wood drop")
  check_result(host_joined_chop and main.items.local_inventory().count_item("wood") == 0,"Cooperative race does not grant a second harvest")
 if role in ["host","logger"]: check_result(saw_tool,"Axe animation is replicated on "+role)
 if role == "logger":
  check_result(main.items.local_inventory().count_item("wood") == record.height-2 and main.items.local_inventory().count_item("wood_block") == 3,"Host craft pickup and placement conserve exact wood quantities")
  check_result(not main.player.resources.snapshot().has("stamina"),"Logging does not recreate remote stamina")
  main.network.stop()
  await create_timer(0.4).timeout
  check_result(main.world.trees[0].active and main.items.local_inventory().count_item("wood") == 0,"Leaving restores own uncut forest without copying host wood")
 print("Logging network ",role," failures: ",failures)
 quit(1 if failures else 0)
