extends Node
# Authoritative host: clients send intentions, never positions or terrain edits.
const PORT := 24567
const MAX_PLAYERS := 4
var stopping := false
var active := false
var connected := false
var status := "Одиночная игра"
var commands: Dictionary = {}
var mining: Dictionary = {}
var cooldowns: Dictionary = {}
var last_input: Dictionary = {}
var targets: Dictionary = {}
var send_clock := 0.0
var snapshot_clock := 0.0
var connection_clock := 0.0
var main: Node2D

func _ready() -> void:
 main = get_parent()
 main.combat.entity_changed.connect(_entity_changed)
 main.combat.chest_changed.connect(_chest_changed)
 main.combat.player_changed.connect(_player_changed)
 main.items.terrain_changed.connect(_terrain_changed)
 main.items.decoration_changed.connect(_decoration_changed)
 main.items.attack_started.connect(_attack_started)
 main.items.inventory_changed.connect(_inventory_changed)
 main.items.drop_changed.connect(_drop_changed)
 multiplayer.peer_connected.connect(_peer_joined)
 multiplayer.peer_disconnected.connect(_peer_left)
 multiplayer.connected_to_server.connect(func(): status = "Получение мира…")
 multiplayer.connection_failed.connect(func(): stop("Не удалось подключиться"))
 multiplayer.server_disconnected.connect(func(): stop("Хост отключился. Возврат в одиночную игру"))

func host_game(port: int = PORT) -> Error:
 if active or stopping:
  return ERR_ALREADY_IN_USE
 var peer := ENetMultiplayerPeer.new()
 var err := peer.create_server(port, MAX_PLAYERS - 1)
 if err != OK:
  status = "Не удалось открыть UDP-порт %d (ошибка %d)" % [port, err]
  return err
 multiplayer.multiplayer_peer = peer
 active = true
 connected = true
 status = "Хост · UDP %d · максимум 4 игрока" % port
 return OK

func join_game(address: String, port: int = PORT) -> Error:
 if active or stopping:
  return ERR_ALREADY_IN_USE
 if address.strip_edges().is_empty():
  status = "Введите IP хоста"
  return ERR_INVALID_PARAMETER
 var peer := ENetMultiplayerPeer.new()
 var err := peer.create_client(address.strip_edges(), port)
 if err != OK:
  status = "Ошибка подключения: %d" % err
  return err
 multiplayer.multiplayer_peer = peer
 active = true
 connected = false
 connection_clock = 0.0
 main.player.set_physics_process(false)
 status = "Подключение…"
 return OK

func stop(message: String = "Одиночная игра") -> void:
 if stopping:
  return
 stopping = true
 var carried_inventory: RefCounted = main.items.local_inventory()
 var carried_life: Dictionary = main.combat.player_data(main.player)
 var was_host := active and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.is_server()
 var can_notify := active and connected and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
 active = false
 connected = false
 if can_notify and not multiplayer.is_server():
  request_leave.rpc_id(1)
  # Keep polling long enough to flush the reliable leave request.
  await get_tree().create_timer(0.15).timeout
 multiplayer.multiplayer_peer.close()
 multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
 commands.clear()
 mining.clear()
 cooldowns.clear()
 last_input.clear()
 targets.clear()
 var kept_inventory: Array = carried_inventory.to_data()
 # On return to solo, preserve local inventory; release other inventories once.
 if was_host:
  for id in main.items.inventories.keys():
   if id != 1:
    var body = main.get_node("Players").get_node_or_null(str(id))
    main.items.retire_player(id, body.position if body != null else main.world.spawn_position())
 main.items.inventories.clear()
 main.reset_players()
 main.add_player(1, main.world.spawn_position())
 main.select_local_player(1)
 main.items.inventory_for(1).load_data(kept_inventory)
 main.combat.apply_player_state(1, carried_life)
 status = message
 stopping = false

func _peer_joined(id: int) -> void:
 if not multiplayer.is_server():
  return
 var existing := main.get_node("Players").get_children()
 main.add_player(id, main.world.spawn_position() + Vector2((existing.size() % 4) * 18, -8))
 var roster: Dictionary = {}
 for body in main.get_node("Players").get_children():
  roster[int(str(body.name))] = body.position
 var edits: Array = []
 for cell in main.world.changes:
  edits.append([cell, main.world.changes[cell]])
 bootstrap.rpc_id(id, main.world.world_seed, main.world.world_width, main.world.world_depth, edits, roster, main.items.snapshot(), main.items.inventory_for(id).to_data(), main.world.wall_changes, main.world.torches.keys(), main.combat.snapshot(true))
 for body in existing:
  var old_id := int(str(body.name))
  if old_id != 1:
   spawn_remote.rpc_id(old_id, id, roster[id])

@rpc("any_peer", "call_remote", "reliable", 0)
func request_leave() -> void:
 if not multiplayer.is_server():
  return
 var id := multiplayer.get_remote_sender_id()
 if id > 1:
  _peer_left(id, true)
  multiplayer.multiplayer_peer.disconnect_peer(id)

@rpc("authority", "call_remote", "reliable", 0)
func despawn_remote(id: int) -> void:
 main.remove_player(id)
 targets.erase(id)

func _peer_left(id: int, taking_inventory: bool = false) -> void:
 if active and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.is_server():
  var body = main.get_node("Players").get_node_or_null(str(id))
  if body != null:
   if taking_inventory:
    # Graceful exit carries this inventory into a separate solo world copy.
    # Do not also drop it into that same departing client's world replica.
    main.items.inventories.erase(id)
   else:
    main.items.retire_player(id, body.position)
  despawn_remote.rpc(id)
 main.remove_player(id)
 commands.erase(id)
 mining.erase(id)
 cooldowns.erase(id)
 last_input.erase(id)
 targets.erase(id)

@rpc("authority", "call_remote", "reliable", 0)
func bootstrap(seed_value: int, width: int, depth: int, edits: Array, roster: Dictionary, drop_state: Dictionary, inventory_data: Array, wall_state: Dictionary, torch_cells: Array, combat_state: Dictionary) -> void:
 main.world.world_seed = seed_value
 main.world.world_width = width
 main.world.world_depth = depth
 main.world.generate()
 for edit in edits:
  main.world.apply_edit(edit[0], edit[1])
 for cell in wall_state:
  main.world.apply_decoration("wall", cell, wall_state[cell])
 for cell in torch_cells:
  main.world.apply_decoration("torch", cell, 1)
 main.items.inventories.clear()
 main.items.load_drops(drop_state)
 main.reset_players()
 for id in roster:
  main.add_player(id, roster[id])
 main.select_local_player(multiplayer.get_unique_id())
 main.items.local_inventory().load_data(inventory_data)
 main.combat.apply_snapshot(combat_state)
 connected = true
 status = "Подключён · игроков: %d/4" % roster.size()

@rpc("authority", "call_remote", "reliable", 0)
func spawn_remote(id: int, position_value: Vector2) -> void:
 main.add_player(id, position_value)
 status = "Подключён · игроков: %d/4" % main.get_node("Players").get_child_count()

func submit_local(axis: float, jump: bool, cell: Vector2i, mode: int, slot: int, delta: float) -> void:
 if not active or not connected:
  return
 if multiplayer.is_server():
  _store_command(1, axis, jump, cell, mode, slot)
 else:
  send_clock += delta
  # Send a jump immediately so a brief key press is not lost between packets.
  if send_clock >= 1.0 / 30.0 or jump:
   send_clock = 0.0
   receive_command.rpc_id(1, axis, jump, cell, mode, slot)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func receive_command(axis: float, jump: bool, cell: Vector2i, mode: int, slot: int) -> void:
 if multiplayer.is_server():
  _store_command(multiplayer.get_remote_sender_id(), axis, jump, cell, mode, slot)

func _store_command(id: int, axis: float, jump: bool, cell: Vector2i, mode: int, slot: int) -> void:
 if not main.get_node("Players").has_node(str(id)) or not is_finite(axis):
  return
 if mode < 0 or mode > 2 or (slot < 0 or slot >= 10):
  return
 var pending_jump := bool(commands.get(id, {}).get("jump", false))
 commands[id] = {"axis": clampf(axis, -1.0, 1.0), "jump": jump or pending_jump, "cell": cell, "mode": mode, "slot": slot}
 last_input[id] = Time.get_ticks_msec()

func _physics_process(delta: float) -> void:
 if not active:
  return
 if not connected:
  connection_clock += delta
  if connection_clock > 10.0:
   stop("Хост не ответил за 10 секунд")
  return
 if not multiplayer.is_server():
  return
 for body in main.get_node("Players").get_children():
  var id := int(str(body.name))
  if not commands.has(id):
   continue
  if body.dead:
   body.submit_command(0.0, false)
   mining.erase(id)
   continue
  var command: Dictionary = commands[id]
  if Time.get_ticks_msec() - int(last_input[id]) > 500:
   command.axis = 0.0
   command.mode = 0
   command.jump = false
  body.submit_command(command.axis, command.jump)
  command.jump = false
  cooldowns[id] = maxf(0.0, float(cooldowns.get(id, 0.0)) - delta)
  var cell: Vector2i = command.cell
  var definition: Dictionary = main.items.selected_definition(body, command.slot)
  var primary: String = main.items.primary_status(body, cell, command.slot)
  if command.mode == 1 and definition.get("kind", "") == "weapon":
   mining.erase(id)
   main.items.use_primary(body, cell, command.slot)
  elif command.mode == 1 and primary.begins_with("Можно"):
   var progress: Dictionary = mining.get(id, {"cell": cell, "slot": command.slot, "time": 0.0})
   if progress.cell != cell or progress.slot != command.slot:
    progress = {"cell": cell, "slot": command.slot, "time": 0.0}
   progress.time += delta
   if progress.time >= main.items.primary_duration(body, cell, command.slot):
    main.items.use_primary(body, cell, command.slot)
    progress.time = 0.0
   mining[id] = progress
  else:
   mining.erase(id)
  if command.mode == 2 and cooldowns[id] <= 0.0:
   if main.items.place_selected(body, cell, command.slot):
    cooldowns[id] = 0.18
 snapshot_clock += delta
 if snapshot_clock >= 0.05:
  snapshot_clock = 0.0
  var state: Dictionary = {}
  for body in main.get_node("Players").get_children():
   state[int(str(body.name))] = [body.position, body.velocity, body.facing, body.life_revision]
  var drop_positions: Dictionary = {}
  for id in main.items.drops:
   drop_positions[id] = main.items.drops[id].position
  sync_positions.rpc(state, drop_positions, main.combat.motion_snapshot())

@rpc("authority", "call_remote", "reliable", 0)
func terrain_edit(cell: Vector2i, block_id: int) -> void:
 main.world.apply_edit(cell, block_id)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func sync_positions(state: Dictionary, drop_positions: Dictionary, combat_motion: Dictionary) -> void:
 if not connected:
  return
 targets = state
 main.combat.apply_motion(combat_motion)
 for id in drop_positions:
  if main.items.drops.has(id):
   main.items.drops[id].position = drop_positions[id]

func _process(delta: float) -> void:
 if not active or not connected or multiplayer.is_server():
  return
 for id in targets:
  var body = main.get_node("Players").get_node_or_null(str(id))
  if body == null or body.life_revision != int(targets[id][3]):
   continue
  body.position = body.position.lerp(targets[id][0], minf(1.0, delta * 22.0))
  body.velocity = targets[id][1]
  body.facing = targets[id][2]
  body.elapsed += delta
  body.queue_redraw()


func _inventory_changed(id: int) -> void:
 if active and connected and multiplayer.is_server() and id != 1:
  sync_inventory.rpc_id(id, main.items.inventory_for(id).to_data())

func _drop_changed(id: int, data: Dictionary) -> void:
 if active and connected and multiplayer.is_server():
  sync_drop.rpc(id, data)

@rpc("authority", "call_remote", "reliable", 0)
func sync_inventory(data: Array) -> void:
 main.items.local_inventory().load_data(data)

@rpc("authority", "call_remote", "reliable", 0)
func sync_drop(id: int, data: Dictionary) -> void:
 main.items.set_drop(id, data)

func transfer_local(source: int, destination: int) -> void:
 if not connected:
  return
 if multiplayer.is_server():
  main.items.transfer(1, source, destination)
 else:
  request_transfer.rpc_id(1, source, destination)

@rpc("any_peer", "call_remote", "reliable", 0)
func request_transfer(source: int, destination: int) -> void:
 if not multiplayer.is_server():
  return
 var id := multiplayer.get_remote_sender_id()
 if main.get_node("Players").has_node(str(id)):
  main.items.transfer(id, source, destination)


func _terrain_changed(cell: Vector2i, block_id: int) -> void:
 if active and connected and multiplayer.is_server():
  terrain_edit.rpc(cell, block_id)

func _decoration_changed(kind: String, cell: Vector2i, value: int) -> void:
 if active and connected and multiplayer.is_server():
  sync_decoration.rpc(kind, cell, value)

@rpc("authority", "call_remote", "reliable", 0)
func sync_decoration(kind: String, cell: Vector2i, value: int) -> void:
 main.world.apply_decoration(kind, cell, value)

func _attack_started(id: int, direction: Vector2) -> void:
 if active and connected and multiplayer.is_server():
  sync_attack.rpc(id, direction, bool(main.items.attack_profiles.get(id, {}).get("unarmed", false)))

@rpc("authority", "call_remote", "reliable", 0)
func sync_attack(id: int, direction: Vector2, unarmed: bool) -> void:
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body != null:
  body.play_swing(direction, unarmed)

func craft_local(recipe_id: String) -> void:
 if not connected or stopping:
  return
 if multiplayer.is_server():
  main.inventory_ui.show_craft_result(main.items.craft(1, recipe_id))
 else:
  request_craft.rpc_id(1, recipe_id)

@rpc("any_peer", "call_remote", "reliable", 0)
func request_craft(recipe_id: String) -> void:
 if not multiplayer.is_server():
  return
 var id := multiplayer.get_remote_sender_id()
 if main.get_node("Players").has_node(str(id)):
  var result: String = main.items.craft(id, recipe_id)
  craft_feedback.rpc_id(id, result)

@rpc("authority", "call_remote", "reliable", 0)
func craft_feedback(message: String) -> void:
 main.inventory_ui.show_craft_result(message)


func _entity_changed(id: int, data: Dictionary) -> void:
 if active and connected and multiplayer.is_server():
  sync_entity.rpc(id, data)

@rpc("authority", "call_remote", "reliable", 0)
func sync_entity(id: int, data: Dictionary) -> void:
 main.combat.set_entity(id, data)

func _chest_changed(id: int, data: Dictionary) -> void:
 if active and connected and multiplayer.is_server():
  sync_chest.rpc(id, data)

@rpc("authority", "call_remote", "reliable", 0)
func sync_chest(id: int, data: Dictionary) -> void:
 main.combat.set_chest(id, data)

func _player_changed(id: int, data: Dictionary) -> void:
 if active and connected and multiplayer.is_server():
  sync_life.rpc(id, data)

@rpc("authority", "call_remote", "reliable", 0)
func sync_life(id: int, data: Dictionary) -> void:
 main.combat.apply_player_state(id, data)
 targets.erase(id)
