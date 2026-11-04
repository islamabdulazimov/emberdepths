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

func blade_slot(inventory: RefCounted) -> int:
 for i in range(10):
  if inventory.item_at(i) == "stone_blade":
   return i
 return 0

func run() -> void:
 var role := OS.get_cmdline_user_args()[0]
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.spawning_enabled = false
 var fighter_ids: Array = []
 var enemy_damage: Array = []
 var ghost_health: Array = []
 if role == "host":
  main.combat.set_physics_process(false)
  main.combat.world_time = 180.5
  main.player.position = Vector2(1000, 100)
  main.network.peer_admitted.connect(func(id):
   if fighter_ids.is_empty():
    fighter_ids.append(id)
    main.items.inventory_for(id).add("stone_blade", 1)
    main.items.inventory_changed.emit(id)
   else:
    # Keep the observer away from the fighter's recovery drops.
    main.get_node("Players").get_node(str(id)).position = Vector2(1800, 100))
  main.combat.entity_changed.connect(func(_id, data):
   if not data.is_empty():
    if data.kind == "ashling" and data.health < 45:
     enemy_damage.append(data.health)
    elif data.kind == "spirit":
     ghost_health.append(data.health))
  check_result(main.network.host_game() == OK, "Combat host opens server")
 else:
  main.network.join_game("127.0.0.1")
 var started := Time.get_ticks_msec()
 var enemy_id := -1
 var forced_death := false
 var death_at := 0
 var respawned := false
 var phase := 0
 var saw_night := false
 var saw_dead := false
 var saw_respawn := false
 var saw_chest := false
 var saw_ghost := false
 var saw_recovered := false
 var saw_finished := false
 var checked_late := false
 var checked_client_authority := false
 while Time.get_ticks_msec() - started < (10000 if role == "host" else (9500 if role == "fighter" else 8000)):
  await process_frame
  if not main.network.active or not main.network.connected:
   continue
  saw_night = saw_night or main.combat.is_night()
  if not main.combat.chests.is_empty():
   saw_chest = true
  for actor in main.combat.entities.values():
   if actor.kind == "spirit":
    saw_ghost = true
  if role == "host":
   if not fighter_ids.is_empty():
    var fighter = main.get_node("Players").get_node_or_null(str(fighter_ids[0]))
    if fighter != null:
     if enemy_id == -1 and Time.get_ticks_msec() - started > 900:
      enemy_id = main.combat.spawn_entity("ashling", fighter.position + Vector2(22, 0))
     elif enemy_id != -1 and not main.combat.entities.has(enemy_id) and not forced_death:
      main.combat.damage_player(fighter_ids[0], 999, fighter.position, true)
      forced_death = true
      death_at = Time.get_ticks_msec()
      print("DEATH_READY")
     if forced_death and not respawned and Time.get_ticks_msec() - death_at > 1900:
      main.combat.respawn(fighter)
      respawned = true
     saw_dead = saw_dead or fighter.dead
     if respawned and fighter.health == 100 and fighter.unclothed:
      saw_respawn = true
     if saw_ghost and main.combat.entities.is_empty() and main.combat.chests.is_empty():
      saw_finished = true
   continue
  if not checked_client_authority:
   checked_client_authority = true
   check_result(not main.combat.damage_player(1, 999, Vector2.ZERO), "Client cannot apply authoritative player damage locally")
  if role == "late":
   if not checked_late:
    checked_late = true
    check_result(not main.combat.chests.is_empty(), "Late join restores death chest")
    var contents: Array = main.combat.chests.values()[0].contents
    var blades := 0
    for stack in contents:
     if stack.item == "stone_blade":
      blades += stack.count
    check_result(blades == 1, "Late chest snapshot contains exact recoverable equipment")
   for body in main.get_node("Players").get_children():
    if body != main.player and str(body.name) != "1":
     saw_dead = saw_dead or (body.dead and body.health == 0 and body.unclothed)
     saw_respawn = saw_respawn or (body.life_revision >= 2 and not body.dead and body.health == 100 and body.unclothed)
   if saw_ghost and main.combat.entities.is_empty() and main.combat.chests.is_empty():
    saw_finished = true
   continue
  var inventory = main.items.local_inventory()
  var target := Vector2i(0, 0)
  var mode := 0
  var slot := 0
  if main.player.dead:
   if not saw_dead:
    check_result(main.player.health == 0 and inventory.count_item("stone_blade") == 0 and main.player.unclothed, "Death clears client inventory and replicates naked state")
   saw_dead = true
   phase = 1
  elif phase == 0:
   for actor in main.combat.entities.values():
    if actor.kind == "ashling":
     target = main.world.cell_at(actor.position)
     mode = 1
     slot = blade_slot(inventory)
  elif phase == 1:
   check_result(main.player.health == 100 and main.player.unclothed and inventory.count_item("stone_blade") == 0, "Respawn syncs health while equipment remains in chest")
   saw_respawn = true
   var before: Vector2 = main.player.position
   main.network.targets[main.multiplayer.get_unique_id()] = [Vector2.ZERO, Vector2.ZERO, 1, 0]
   main.network._process(0.05)
   check_result(main.player.position == before, "Stale position snapshot cannot override respawn revision")
   phase = 2
  elif phase == 2:
   for chest in main.combat.chests.values():
    if chest.owner_id == main.multiplayer.get_unique_id():
     target = main.world.cell_at(chest.position)
     mode = 1
   if main.combat.chests.is_empty():
    phase = 3
  elif phase == 3:
   if inventory.count_item("stone_blade") == 1:
    saw_recovered = true
    phase = 4
  elif phase == 4:
   for actor in main.combat.entities.values():
    if actor.kind == "spirit":
     target = main.world.cell_at(actor.position)
     mode = 1
     slot = blade_slot(inventory)
   if saw_ghost and main.combat.entities.is_empty():
    saw_finished = true
    phase = 5
  main.network.submit_local(0, false, target, mode, slot, 1.0 / 60.0)
 check_result(saw_night, "Night phase synchronizes to " + role)
 check_result(saw_dead and saw_respawn, "Death and respawn synchronize to " + role)
 check_result(saw_chest and saw_ghost and saw_finished, "Chest recovery and spirit defeat complete on " + role)
 if role == "host":
  check_result(enemy_damage.has(27) and enemy_damage.has(9), "Remote weapon deals server-validated damage")
  check_result(ghost_health.has(2) and ghost_health.has(1), "Network spirit takes two distinct hits")
  check_result(main.player.health == 100, "Fighter does not damage cooperative host")
 if role == "fighter":
  check_result(saw_recovered, "Equipment recovered exactly once into owner inventory")
 print("NETWORK COMBAT ", role, " failures: ", failures)
 quit(1 if failures else 0)
