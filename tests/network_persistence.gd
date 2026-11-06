extends SceneTree
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
 main.interaction.set_process(false)
 main.combat.spawning_enabled = false
 var admitted: Array = []
 var rejected: Array = []
 if role.begins_with("host"):
  main.combat.set_physics_process(false)
  main.network.profile_rejected.connect(func(_id, reason): rejected.append(reason))
  main.network.peer_admitted.connect(func(id):
   admitted.append(id)
   if role == "host_write" and admitted.size() == 1:
    var body = main.get_node("Players").get_node(str(id))
    main.items.inventory_for(id).add("stone", 13)
    main.items.inventory_for(id).add("stone_pick", 1)
    body.health = 63
    body.unclothed = true
    main.survival.recovery[body.profile_id]=[{"item":"torch","count":2}]
    main.survival.recover_inventory(id)
    main.items.inventory_changed.emit(id))
  if role == "host_read":
   check_result(main.saves.load_now(), "New host process loads world and offline character ledger")
   check_result(main.world.block_at(Vector2i(95, 35)) == -1 and main.world.block_at(Vector2i(108, 10)) == 2, "Host restart restores edited terrain")
   check_result(main.world.torches.has(Vector2i(98, 21)) and main.combat.world_time == 190, "Host restart restores torch and night")
  else:
   main.world.apply_edit(Vector2i(95, 35), -1)
   main.world.apply_edit(Vector2i(108, 10), 2)
   main.world.apply_decoration("wall", Vector2i(98, 21), 1)
   main.world.apply_decoration("torch", Vector2i(98, 21), 1)
   main.combat.world_time = 190
  check_result(main.network.host_game() == OK, "Persistence host opens server")
  print("HOST_READY")
  var deadline := Time.get_ticks_msec() + 16000
  while Time.get_ticks_msec() < deadline:
   await process_frame
   if role == "host_write" and admitted.size() == 2 and main.get_node("Players").get_child_count() == 1:
    check_result(main.saves.save_now(), "Host checkpoints disconnected character to physical save")
    print("WORLD_READY")
    break
   if role == "host_read" and admitted.size() == 1 and main.get_node("Players").get_child_count() == 1 and not rejected.is_empty():
    check_result(rejected[0] == "Ключ персонажа не совпадает", "Host rejects impostor reconnect key")
    check_result(main.saves.profiles.size() == 2, "Rejected identity creates no new or duplicated character")
    break
  check_result(Time.get_ticks_msec() < deadline, "Persistence host completed expected reconnect sequence")
 else:
  if role == "wrong":
   main.multiplayer.connected_to_server.disconnect(main.network._send_identity)
   main.multiplayer.connected_to_server.connect(func(): main.network.register_profile.rpc_id(1, main.saves.profile_id, "0".repeat(64)))
  check_result(main.network.join_game("127.0.0.1") == OK, "Client starts connection")
  var deadline := Time.get_ticks_msec() + 7000
  while not main.network.connected and main.network.active and Time.get_ticks_msec() < deadline:
   await process_frame
  if role == "wrong":
   check_result(not main.network.connected and main.network.status == "Ключ персонажа не совпадает", "Wrong key cannot receive saved character")
  else:
   check_result(main.network.connected, "Returning profile admitted")
   var inventory = main.items.local_inventory()
   check_result(main.player.health == 63 and main.player.unclothed, "Stable profile restores health and appearance")
   check_result(inventory.count_item("stone") == (12 if role == "restart" else 13) and inventory.count_item("stone_pick") == 1, "Reconnection restores exact server inventory without duplication")
   check_result(main.combat.chests.is_empty() and inventory.count_item("torch")==2,"recovered owner items survive reconnect without duplication")
   if role != "first":
    check_result(main.player.position.x > main.world.spawn_position().x + 20 and main.interaction.selected_slot == 1, "Position and selected slot survive reconnect")
   if role == "restart":
    check_result(inventory.count_item("stone_wall") == 4 and main.combat.world_time >= 190, "Host restart retains crafted items and phase")
   if role == "reconnect":
    main.network.craft_local("stone_wall")
   var began := Time.get_ticks_msec()
   while Time.get_ticks_msec() - began < 1400:
    await process_frame
    var axis := 1.0 if role == "first" and Time.get_ticks_msec() - began < 450 else 0.0
    main.network.submit_local(axis, false, Vector2i.ZERO, 0, 1, 1.0 / 60.0)
   if role == "reconnect":
    check_result(inventory.count_item("stone") == 12 and inventory.count_item("stone_wall") == 4, "Reconnected character crafts on host with correct cost")
   await main.network.stop()
   check_result(main.items.local_inventory().count_item("stone") == 0, "Client returns to separate original solo inventory")
 print("PERSISTENCE ", role, " failures: ", failures)
 quit(1 if failures else 0)
