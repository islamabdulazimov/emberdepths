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
 main.reset_players()
 main.add_player(1, main.world.spawn_position())
 main.select_local_player(1)
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
 bootstrap.rpc_id(id, main.world.world_seed, main.world.world_width, main.world.world_depth, edits, roster)
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
  _peer_left(id)
  multiplayer.multiplayer_peer.disconnect_peer(id)

@rpc("authority", "call_remote", "reliable", 0)
func despawn_remote(id: int) -> void:
 main.remove_player(id)
 targets.erase(id)

func _peer_left(id: int) -> void:
 if active and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.is_server():
  despawn_remote.rpc(id)
 main.remove_player(id)
 commands.erase(id)
 mining.erase(id)
 cooldowns.erase(id)
 last_input.erase(id)
 targets.erase(id)

@rpc("authority", "call_remote", "reliable", 0)
func bootstrap(seed_value: int, width: int, depth: int, edits: Array, roster: Dictionary) -> void:
 main.world.world_seed = seed_value
 main.world.world_width = width
 main.world.world_depth = depth
 main.world.generate()
 for edit in edits:
  main.world.apply_edit(edit[0], edit[1])
 main.reset_players()
 for id in roster:
  main.add_player(id, roster[id])
 main.select_local_player(multiplayer.get_unique_id())
 connected = true
 status = "Подключён · игроков: %d/4" % roster.size()

@rpc("authority", "call_remote", "reliable", 0)
func spawn_remote(id: int, position_value: Vector2) -> void:
 main.add_player(id, position_value)
 status = "Подключён · игроков: %d/4" % main.get_node("Players").get_child_count()

func submit_local(axis: float, jump: bool, cell: Vector2i, mode: int, block_id: int, delta: float) -> void:
 if not active or not connected:
  return
 if multiplayer.is_server():
  _store_command(1, axis, jump, cell, mode, block_id)
 else:
  send_clock += delta
  # Send a jump immediately so a brief key press is not lost between packets.
  if send_clock >= 1.0 / 30.0 or jump:
   send_clock = 0.0
   receive_command.rpc_id(1, axis, jump, cell, mode, block_id)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func receive_command(axis: float, jump: bool, cell: Vector2i, mode: int, block_id: int) -> void:
 if multiplayer.is_server():
  _store_command(multiplayer.get_remote_sender_id(), axis, jump, cell, mode, block_id)

func _store_command(id: int, axis: float, jump: bool, cell: Vector2i, mode: int, block_id: int) -> void:
 if not main.get_node("Players").has_node(str(id)) or not is_finite(axis):
  return
 if mode < 0 or mode > 2 or not main.world.Blocks.DEFINITIONS.has(block_id):
  return
 var pending_jump := bool(commands.get(id, {}).get("jump", false))
 commands[id] = {"axis": clampf(axis, -1.0, 1.0), "jump": jump or pending_jump, "cell": cell, "mode": mode, "block": block_id}
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
  var command: Dictionary = commands[id]
  if Time.get_ticks_msec() - int(last_input[id]) > 500:
   command.axis = 0.0
   command.mode = 0
   command.jump = false
  body.submit_command(command.axis, command.jump)
  command.jump = false
  cooldowns[id] = maxf(0.0, float(cooldowns.get(id, 0.0)) - delta)
  var cell: Vector2i = command.cell
  var bodies := main.get_node("Players").get_children()
  if command.mode == 1 and main.world.interaction_status(body, cell, false, bodies) == "Можно добыть":
   var progress: Dictionary = mining.get(id, {"cell": cell, "time": 0.0})
   if progress.cell != cell:
    progress = {"cell": cell, "time": 0.0}
   progress.time += delta
   var block: int = main.world.block_at(cell)
   if progress.time >= float(main.world.Blocks.DEFINITIONS[block].mine_time):
    _edit(body, cell, -1, bodies)
    progress.time = 0.0
   mining[id] = progress
  else:
   mining.erase(id)
  if command.mode == 2 and cooldowns[id] <= 0.0:
   if _edit(body, cell, command.block, bodies):
    cooldowns[id] = 0.18
 snapshot_clock += delta
 if snapshot_clock >= 0.05:
  snapshot_clock = 0.0
  var state: Dictionary = {}
  for body in main.get_node("Players").get_children():
   state[int(str(body.name))] = [body.position, body.velocity, body.facing]
  sync_positions.rpc(state)

func _edit(body: CharacterBody2D, cell: Vector2i, block_id: int, bodies: Array) -> bool:
 if not main.world.request_edit(body, cell, block_id, bodies):
  return false
 terrain_edit.rpc(cell, block_id)
 return true

@rpc("authority", "call_remote", "reliable", 0)
func terrain_edit(cell: Vector2i, block_id: int) -> void:
 main.world.apply_edit(cell, block_id)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func sync_positions(state: Dictionary) -> void:
 if not connected:
  return
 targets = state

func _process(delta: float) -> void:
 if not active or not connected or multiplayer.is_server():
  return
 for id in targets:
  var body = main.get_node("Players").get_node_or_null(str(id))
  if body == null:
   continue
  body.position = body.position.lerp(targets[id][0], minf(1.0, delta * 22.0))
  body.velocity = targets[id][1]
  body.facing = targets[id][2]
  body.elapsed += delta
  body.queue_redraw()
