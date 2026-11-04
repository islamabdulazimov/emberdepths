extends SceneTree
const Daylight = preload("res://data/daylight.gd")
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok:
  print("PASS: ", message)
 else:
  failures += 1
  push_error(message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var role := OS.get_cmdline_user_args()[0]
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 # Avoid real mouse driving or mutating terrain in this scripted scenario.
 main.interaction.set_process(false)
 main.combat.spawning_enabled = false
 var tree_cell: Vector2i = main.world.trees[0].cell
 var tree_fixture := false
 var saw_tree_removed := false
 var saw_shared_sky := false
 if role == "host":
  # Test fixture only: grant remote players two stones, through host inventory.
  main.network.peer_admitted.connect(func(id):
   main.items.inventory_for(id).add("stone", 2)
   main.items.inventory_changed.emit(id))
  main.combat.world_time = 190.0
  check_result(main.network.host_game() == OK, "Host opens ENet server")
 else:
  main.network.join_game("127.0.0.1")
 var start := Time.get_ticks_msec()
 var saw_disconnect := false
 var saw_four := false
 var saw_mined := false
 var saw_built := false
 var saw_move := false
 var mined_once := false
 var late_snapshot := false
 var initial_x := 0.0
 var pickup_fixture := false
 var consumed_once := false
 var saw_pickup := false
 var transfer_sent := false
 var saw_transfer := false
 var saw_private_inventory := false
 var saw_late_drops := false
 var cell := Vector2i(96, 23)
 while Time.get_ticks_msec() - start < (4500 if role == "client2" else (5000 if role == "late" else 8500)):
  await process_frame
  if not main.network.active:
   continue
  if not main.network.connected:
   continue
  if role == "host" and not tree_fixture and Time.get_ticks_msec() - start > 1300:
   main.world.apply_edit(tree_cell,-1)
   main.items.terrain_changed.emit(tree_cell,-1)
   tree_fixture = true
  if not main.world.trees[0].active and main.world.block_at(tree_cell) == -1:
   saw_tree_removed = true
  var daylight := Daylight.sample(main.combat.world_time)
  if main.combat.world_time > 190 and main.combat.world_time < 210 and daylight.moon_alpha == 1 and daylight.stars == 1:
   saw_shared_sky = true
  if main.get_node("Players").get_child_count() == 4:
   saw_four = true
  if saw_four and main.get_node("Players").get_child_count() == 3:
   saw_disconnect = true
  if role == "late" and not late_snapshot:
   late_snapshot = true
   check_result(main.world.block_at(cell) == 2 and main.world.changes.get(cell) == 2, "Late join receives existing edits")
  if role == "host" and not pickup_fixture and Time.get_ticks_msec() - start > 1800:
   for id in main.network.commands:
    if id != 1:
     var body = main.get_node("Players").get_node(str(id))
     if body.position.x > main.world.spawn_position().x + 30:
      main.items.spawn_drop("dirt", 4, body.position + Vector2(0, -8))
      pickup_fixture = true
  if role == "client2" and main.items.local_inventory().slots[0].count == 2:
   saw_private_inventory = true
  if role == "late" and not main.items.drops.is_empty():
   saw_late_drops = true
  if role == "client1":
   var bag = main.items.local_inventory()
   if saw_built and bag.slots[0].item == "stone" and bag.slots[0].count == 1:
    consumed_once = true
   if bag.slots[1].item == "dirt" and bag.slots[1].count == 4:
    saw_pickup = true
   if saw_pickup and consumed_once and not transfer_sent:
    main.network.transfer_local(0, 1)
    transfer_sent = true
   if transfer_sent and bag.slots[1].item == "stone" and bag.slots[1].count == 1 and bag.slots[0].item == "dirt":
    saw_transfer = true
   if initial_x == 0.0:
    initial_x = main.player.position.x
   if main.player.position.x > initial_x + 8.0:
    saw_move = true
   var elapsed := Time.get_ticks_msec() - start
   var mode := 0
   var axis := 1.0 if elapsed < 350 else 0.0
   if elapsed > 500 and not mined_once:
    mode = 1
   elif mined_once and not saw_built:
    mode = 2
   main.network.submit_local(axis, false, cell, mode, 0, 1.0 / 60.0)
  if main.world.changes.get(cell, 99) == -1:
   saw_mined = true
   mined_once = true
  if main.world.changes.get(cell, 99) == 2:
   saw_built = true
 if role != "rejected":
  check_result(saw_tree_removed, "Host tree removal reaches existing and late players on " + role)
  check_result(saw_shared_sky, "Sky samples shared host night clock on " + role)
  check_result(main.world.trees[1].active and main.world.trees[1].height in range(5,9), "Unchanged tree variant survives bootstrap on " + role)
 if role == "rejected":
  check_result(not main.network.active, "Fifth player is rejected")
 elif role == "host":
  check_result(saw_four, "Host and three clients share session")
  check_result(saw_mined and saw_built, "Host validates remote mining and building")
  check_result(saw_disconnect, "Disconnected player removed on host")
 elif role == "late":
  check_result(late_snapshot, "Late client joins")
  check_result(saw_late_drops, "Late client receives existing drops")
  check_result(saw_disconnect, "Disconnect replicated to remaining client")
 else:
  check_result(saw_four, "Client sees four players")
  check_result(saw_mined and saw_built, "Client receives ordered terrain edits")
  if role == "client1":
   check_result(saw_move, "Remote input moves server-controlled player")
   check_result(consumed_once, "Server consumes one item and syncs owner inventory")
   check_result(saw_pickup, "Server pickup replicates into owner inventory")
   check_result(saw_transfer, "Reliable inventory transfer swaps owner slots")
 if role == "client2":
  check_result(saw_private_inventory, "Other player's inventory stays independent")
  var before_leave: Array = main.items.local_inventory().to_data()
  var world_before: Dictionary = main.items.snapshot()
  main.network.stop()
  await create_timer(0.4).timeout
  check_result(main.items.local_inventory().count_item("stone") == 0 and before_leave[0].count == 2, "Leaving returns to original solo inventory without importing server items")
  check_result(main.items.drops.is_empty() and not world_before.is_empty(), "Leaving restores original solo world without copying server drops")
  check_result(main.world.trees[0].active and main.combat.world_time < 30, "Leaving restores original solo trees and daytime without importing host night")
 print("NETWORK ", role, " failures: ", failures)
 quit(1 if failures else 0)
