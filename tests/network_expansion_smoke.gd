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
 main.combat.set_physics_process(false)
 main.items.set_physics_process(false)
 main.exploration.set_process(false)
 main.encounter.enabled = false
 main.player.set_physics_process(false)
 var anchor := Vector2i(73,57)
 var original := 0
 if role == "host":
  main.world.configure_expanded()
  main.world.generate()
  main.exploration.initialize_loot()
  main.player.position = main.world.cell_center(anchor)+Vector2(-32,-2)
  for x in range(190,220):
   for y in range(106,112): main.world.apply_edit(Vector2i(x,y),-1)
   main.world.apply_edit(Vector2i(x,112),2)
  main.world.solid.update_internals()
  var i := 0
  for kind in ["seamling","hollowbeak","ashweaver","void_collector"]:
   main.combat.spawn_entity(kind,Vector2((192+i*5)*16+8,112*16))
   i += 1
  original = main.storage.chests[anchor].inventory.count_item("wood")
  main.network.peer_admitted.connect(func(id):
   var body = main.get_node("Players").get_node(str(id))
   body.set_physics_process(false)
   body.position = main.world.cell_center(anchor)+Vector2(-32,-2)
   main.items.inventory_for(id).load_data([]))
  check_result(main.network.host_game() == OK,"Expanded ENet host starts")
  print("EXPANSION_HOST_READY")
 else: check_result(main.network.join_game("127.0.0.1") == OK,"Expanded client connects")
 var start := Time.get_ticks_msec()
 var opened := false
 var moved := false
 var received := false
 var checked := false
 var spawned := false
 while Time.get_ticks_msec()-start < (7500 if role == "host" else 5500):
  await process_frame
  if not main.network.active or not main.network.connected: continue
  if role == "host":
   if main.get_node("Players").get_child_count() == 2 and not spawned:
    main.combat.spawn_entity("seamling",Vector2(210*16+8,112*16))
    spawned = true
   if main.storage.chests[anchor].inventory.count_item("wood") == 0 and not checked:
    var sum := 0
    for body in main.get_node("Players").get_children(): sum += main.items.inventory_for(int(str(body.name))).count_item("wood")
    check_result(sum == original,"Host conserves one shared loot stack across both players")
    main.exploration.initialize_loot()
    check_result(main.storage.chests[anchor].inventory.count_item("wood") == 0,"Returning to a networked site cannot regenerate loot")
    check_result(main.combat.entities[1].max_health == 36 and main.combat.entities[5].max_health == 45,"Joining fixes new enemy HP at spawn without increasing existing enemies")
    checked = true
  else:
   if main.world.generator_version == 2 and main.storage.chests.has(anchor) and main.combat.entities.size() >= 5 and not opened:
    check_result(main.world.world_width == 384 and main.world.world_depth == 160 and main.world.sites.size() == 4,"Bootstrap reproduces generator2, dimensions and prepared sites")
    check_result(main.world.block_at(Vector2i(38,48)) == 2,"Client regenerates the same dungeon boundary")
    var kinds: Array = []
    for e in main.combat.entities.values(): kinds.append(e.kind)
    check_result(kinds.has("seamling") and kinds.has("hollowbeak") and kinds.has("ashweaver") and kinds.has("void_collector"),"All four original creature types replicate")
    check_result(main.combat.entities[1].max_health == 36 and main.combat.entities[5].max_health == 45,"Client receives fixed authoritative health scaling")
    main.network.open_storage_local(anchor,0)
    opened = true
   if main.inventory_ui.storage_anchor == anchor and main.inventory_ui.storage_slots.size() == 30 and not moved:
    main.network.move_storage_local(anchor,true,0,false,0,main.inventory_ui.storage_revision)
    moved = true
   if moved and main.items.local_inventory().count_item("wood") > 0 and not received:
    received = true
    check_result(main.inventory_ui.storage_slots[0].count == 0,"Client receives a single authoritative transfer without a personal copy of chest loot")
 if role == "host": check_result(checked and spawned,"Host completed expanded-world sharing and scaling checks")
 else: check_result(opened and moved and received,"Client opened and looted the shared generated container")
 main.network.stop()
 await create_timer(0.15).timeout
 main.queue_free()
 await process_frame
 print("Expansion network failures: ",failures)
 quit(1 if failures else 0)
