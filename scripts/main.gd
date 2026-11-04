extends Node2D
const PlayerScene = preload("res://scenes/player.tscn")
var player: CharacterBody2D
var interaction: Node2D
var network: Node
var items: Node2D
var inventory_ui: CanvasLayer
@onready var world = $World

func _ready() -> void:
 RenderingServer.set_default_clear_color(Color("8aabb0"))
 _bind_key("move_left", KEY_A)
 _bind_key("move_right", KEY_D)
 _bind_key("jump", KEY_SPACE)
 items = Node2D.new()
 items.name = "Items"
 items.set_script(preload("res://scripts/item_service.gd"))
 add_child(items)
 network = Node.new()
 network.name = "Network"
 network.set_script(preload("res://scripts/network.gd"))
 add_child(network)
 add_player(1, world.spawn_position())
 select_local_player(1)
 interaction = Node2D.new()
 interaction.set_script(preload("res://scripts/interaction.gd"))
 interaction.world = world
 interaction.player = player
 interaction.bodies = $Players
 interaction.label = $HUD/Panel/Label
 interaction.network = network
 interaction.z_index = 5
 add_child(interaction)
 inventory_ui = CanvasLayer.new()
 inventory_ui.set_script(preload("res://scripts/inventory_ui.gd"))
 add_child(inventory_ui)
 _create_network_ui()
 for arg in OS.get_cmdline_user_args():
  if arg == "--host":
   network.host_game()
  elif arg.begins_with("--join="):
   network.join_game(arg.trim_prefix("--join="))

func add_player(id: int, position_value: Vector2) -> void:
 if $Players.has_node(str(id)):
  return
 var body = PlayerScene.instantiate()
 body.name = str(id)
 $Players.add_child(body)
 items.inventory_for(id)
 body.position = position_value
 body.get_node("Camera2D").enabled = false
 body.set_physics_process(not network.active or multiplayer.is_server())
 # Visually distinguish peers without changing their appearance or hitboxes.
 var palette := [Color.WHITE, Color("b9d9ff"), Color("f8c7a9"), Color("cebddf")]
 body.modulate = palette[($Players.get_child_count() - 1) % 4]

func select_local_player(id: int) -> void:
 player = $Players.get_node(str(id))
 for body in $Players.get_children():
  body.get_node("Camera2D").enabled = body == player
 var camera: Camera2D = player.get_node("Camera2D")
 camera.limit_left = 0
 camera.limit_right = world.world_width * 16
 camera.limit_top = 0
 camera.limit_bottom = world.world_depth * 16
 camera.reset_smoothing()
 if is_instance_valid(interaction):
  interaction.player = player

func remove_player(id: int) -> void:
 var body = $Players.get_node_or_null(str(id))
 if body != null:
  $Players.remove_child(body)
  body.queue_free()

func reset_players() -> void:
 for body in $Players.get_children():
  $Players.remove_child(body)
  body.queue_free()

func _create_network_ui() -> void:
 var panel := HBoxContainer.new()
 panel.position = Vector2(14, 470)
 $HUD.add_child(panel)
 var address := LineEdit.new()
 address.placeholder_text = "IP хоста"
 address.text = "127.0.0.1"
 address.custom_minimum_size.x = 180
 panel.add_child(address)
 var host := Button.new()
 host.text = "Создать сервер"
 panel.add_child(host)
 host.pressed.connect(func(): network.host_game(); get_viewport().gui_release_focus())
 var join := Button.new()
 join.text = "Подключиться"
 panel.add_child(join)
 join.pressed.connect(func(): network.join_game(address.text); get_viewport().gui_release_focus())
 var leave := Button.new()
 leave.text = "Отключиться"
 panel.add_child(leave)
 leave.pressed.connect(func(): network.stop(); get_viewport().gui_release_focus())
 var status_label := Label.new()
 status_label.position = Vector2(14, 508)
 $HUD.add_child(status_label)
 network_status = status_label

var network_status: Label

func _physics_process(_delta: float) -> void:
 if is_instance_valid(network_status):
  network_status.text = network.status
  if network.active and network.connected:
   network_status.text += " · В мире: %d/4" % $Players.get_child_count()
 if not is_instance_valid(player):
  return
 var typing := get_viewport().gui_get_focus_owner() is LineEdit
 var axis := 0.0 if typing else Input.get_axis("move_left", "move_right")
 var jump := not typing and Input.is_action_just_pressed("jump")
 if network.active:
  var mode := 0
  if interaction.can_use_mouse():
   mode = 1 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else (2 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0)
  network.submit_local(axis, jump, world.cell_at(get_global_mouse_position()), mode, interaction.selected_slot, _delta)
 else:
  player.submit_command(axis, jump)
 if not network.active or multiplayer.is_server():
  for body in $Players.get_children():
   body.position.x = clampf(body.position.x, 6.0, world.world_width * 16.0 - 6.0)
   if body.position.y > world.world_depth * 16 + 64:
    body.position = world.spawn_position()
    body.velocity = Vector2.ZERO

func _bind_key(action: String, code: Key) -> void:
 if not InputMap.has_action(action):
  InputMap.add_action(action)
 var event := InputEventKey.new()
 event.physical_keycode = code
 if not InputMap.action_has_event(action, event):
  InputMap.action_add_event(action, event)
