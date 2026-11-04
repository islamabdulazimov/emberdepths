extends SceneTree
var failures := 0
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
 main.combat.spawning_enabled = false
 main.encounter.enabled = false
 main.items.set_physics_process(false)
 main.player.set_physics_process(false)
 var anchor := Vector2i(98,21)
 var marker := Vector2i(96,18)
 var ids: Array = []
 if role == "host":
  for x in range(94,104):
   for y in range(18,22): main.world.apply_edit(Vector2i(x,y),-1)
   main.world.apply_edit(Vector2i(x,22),0)
  main.world.solid.update_internals()
  main.player.position = Vector2(1528,342)
  main.network.peer_admitted.connect(func(id):
   ids.append(id)
   var body = main.get_node("Players").get_node(str(id))
   body.set_physics_process(false)
   body.position = Vector2(1544,342)
   if ids.size() == 1:
    main.items.inventory_for(id).add("wood",6)
    main.items.inventory_for(id).add("stone",10))
  check_result(main.network.host_game() == OK,"Storage host starts")
 else: main.network.join_game("127.0.0.1")
 var start := Time.get_ticks_msec()
 var crafted := false
 var opened := false
 var deposited := false
 var ready := false
 var raced := false
 var race_checked := false
 var checked_late := false
 var checked_guard := false
 var checked_close := false
 var forced_tick := 0
 var range_tick := 0
 var range_checked := false
 var saw_chest := false
 var saw_removed := false
 while Time.get_ticks_msec()-start < (8500 if role == "host" else (6800 if role == "builder" else 5700)):
  await process_frame
  if not main.network.active or not main.network.connected: continue
  var chest = main.storage.at_cell(anchor)
  if chest != null: saw_chest = true
  if saw_chest and chest == null: saw_removed = true
  var ui = main.inventory_ui
  if role == "host":
   if chest != null and chest.inventory.count_item("stone") == 10 and not ready:
    ready = true
    print("STORAGE_READY")
   if main.storage.viewers.size() == 2 and not raced:
    raced = true
    main.world.apply_decoration("wall",marker,3)
    main.items.decoration_changed.emit("wall",marker,3)
   if chest != null and raced and chest.revision == 2 and forced_tick == 0:
    forced_tick = Time.get_ticks_msec()+500
   if forced_tick > 0 and Time.get_ticks_msec() >= forced_tick and not race_checked:
    race_checked = true
    var total := 0
    for id in ids: total += main.items.inventory_for(id).count_item("stone")
    check_result(total == 10 and chest.inventory.count_item("stone") == 0 and chest.revision == 2,"Concurrent remote withdrawals award exactly one stack")
    check_result(main.items.local_inventory().count_item("stone") == 0,"Remote storage transfers never modify host inventory")
    check_result(main.storage.viewers.size() == 2,"Both remote players can keep a shared chest open")
    chest.inventory.add("wood",3)
    chest.revision += 1
    main.storage.refresh(anchor)
    check_result(main.saves.capture().world.storage[anchor][0].item == "wood","Host save captures shared storage contents")
    main.get_node("Players").get_node(str(ids[0])).position.x = 100
    range_tick = Time.get_ticks_msec()+650
   if range_tick > 0 and Time.get_ticks_msec() >= range_tick and not range_checked:
    range_checked = true
    check_result(not main.storage.viewers.has(ids[0]) and chest.inventory.count_item("wood") == 3,"Host closes distant viewer and rejects subsequent forged withdrawal")
    check_result(main.items.use_primary(main.player,anchor+Vector2i.DOWN,9),"Host can mine storage support and spill contents")
  elif role == "builder":
   var bag = main.items.local_inventory()
   if not crafted:
    crafted = true
    main.network.craft_local("wood_chest")
   if chest == null and bag.count_item("wood_chest") == 1:
    main.network.submit_local(0,false,anchor,2,0,1.0/30.0)
   if chest != null and not opened:
    opened = true
    main.network.open_storage_local(anchor,9)
   if ui.storage_anchor == anchor and not deposited:
    deposited = true
    main.network.move_storage_local(anchor,false,1,true,0,ui.storage_revision)
   if main.world.wall_at(marker) == 3 and not raced:
    raced = true
    main.network.move_storage_local(anchor,true,0,false,5,1)
    main.network.move_storage_local(anchor,true,0,false,6,1)
   if raced and ui.storage_anchor == main.storage.NONE and chest != null and not checked_close:
    checked_close = true
    main.network.move_storage_local(anchor,true,0,false,7,3)
    check_result(not ui.storage_panel.visible,"Host automatically closes remote UI after leaving range")
  else:
   if not checked_late:
    checked_late = true
    check_result(chest != null and chest.opened and not chest.known_empty,"Late bootstrap receives storage placement lid and empty metadata")
    check_result(chest.inventory.count_item("stone") == 0 and ui.storage_slots.is_empty(),"Late arrival receives no contents until opening storage")
   if chest != null and not checked_guard:
    checked_guard = true
    check_result(not main.storage.move(int(str(main.player.name)),anchor,true,0,false,0,1) and not main.storage.remove_empty(main.player,anchor),"Client cannot mutate authoritative storage locally")
   if chest != null and not opened:
    opened = true
    main.network.open_storage_local(anchor+Vector2i.RIGHT,9)
   if main.world.wall_at(marker) == 3 and not raced:
    raced = true
    main.network.move_storage_local(anchor,true,0,false,5,1)
 if role == "host":
  check_result(ready and raced and race_checked and range_checked,"Shared storage network scenario completes")
 else:
  check_result(opened and raced,"Remote viewer participates in shared withdrawal on "+role)
  check_result(main.items.local_inventory().count_item("wood") == 0,"Spilled wood is not granted by a rejected storage request on "+role)
 check_result(saw_removed and main.storage.chests.is_empty(),"Storage removal synchronizes on "+role)
 var boxes := 0
 var wood := 0
 for drop in main.items.drops.values():
  if drop.item_id == "wood_chest": boxes += drop.count
  if drop.item_id == "wood": wood += drop.count
 check_result(boxes == 1 and wood == 3,"One chest and exact contents spill on "+role)
 if role == "builder":
  main.network.stop()
  await create_timer(0.3).timeout
  check_result(main.storage.chests.is_empty() and main.items.local_inventory().count_item("stone") == 0,"Leaving restores own world without importing server storage loot")
 print("Storage network ",role," failures: ",failures)
 quit(1 if failures else 0)
