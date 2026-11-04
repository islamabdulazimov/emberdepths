extends Node2D
const PlayerScene = preload("res://scenes/player.tscn")
const Daylight = preload("res://data/daylight.gd")
var player: CharacterBody2D
var interaction: Node2D
var network: Node
var items: Node2D
var combat: Node2D
var encounter: Node2D
var effects: Node2D
var storage: Node2D
var boss_ui: Control
var saves: Node
var close_dialog: ConfirmationDialog
var closing := false
var inventory_ui: CanvasLayer
var ambient: CanvasModulate
var sky: Control
@onready var world = $World

func _ready() -> void:
 $HUD/Panel.theme = preload("res://scripts/visuals/art_direction.gd").theme()
 $HUD/Panel/Label.add_theme_font_size_override("font_size",12)
 ambient = CanvasModulate.new()
 add_child(ambient)
 RenderingServer.set_default_clear_color(Color("8aabb0"))
 _bind_key("move_left", KEY_A)
 _bind_key("move_right", KEY_D)
 _bind_key("jump", KEY_SPACE)
 items = Node2D.new()
 items.name = "Items"
 items.set_script(preload("res://scripts/item_service.gd"))
 add_child(items)
 combat = Node2D.new()
 combat.name = "Combat"
 combat.set_script(preload("res://scripts/combat.gd"))
 add_child(combat)
 var sky_layer := CanvasLayer.new()
 sky_layer.name = "SkyLayer"
 sky_layer.layer = -100
 add_child(sky_layer)
 sky = Control.new()
 sky.set_script(preload("res://scripts/sky.gd"))
 sky.main = self
 sky_layer.add_child(sky)
 encounter = Node2D.new()
 encounter.name = "BossEncounter"
 encounter.set_script(preload("res://scripts/boss_encounter.gd"))
 add_child(encounter)
 storage = Node2D.new()
 storage.name = "Storage"
 storage.set_script(preload("res://scripts/storage_service.gd"))
 add_child(storage)
 effects = Node2D.new()
 effects.name = "VisualEffects"
 effects.set_script(preload("res://scripts/visuals/effects.gd"))
 add_child(effects)
 saves = Node.new()
 saves.name = "Saves"
 saves.set_script(preload("res://scripts/save_service.gd"))
 add_child(saves)
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
 interaction.label = $HUD/Panel/Label
 interaction.network = network
 interaction.z_index = 5
 add_child(interaction)
 inventory_ui = CanvasLayer.new()
 inventory_ui.set_script(preload("res://scripts/inventory_ui.gd"))
 add_child(inventory_ui)
 var resources_ui := Control.new()
 resources_ui.name = "PlayerResources"
 resources_ui.set_script(preload("res://scripts/player_resources_ui.gd"))
 resources_ui.main = self
 resources_ui.position = Vector2(14, 14)
 $HUD.add_child(resources_ui)
 boss_ui = Control.new()
 boss_ui.set_script(preload("res://scripts/boss_ui.gd"))
 boss_ui.main = self
 $HUD.add_child(boss_ui)
 _create_network_ui()
 saves.startup()
 get_tree().auto_accept_quit = false
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
 if id == 1 and is_instance_valid(saves):
  body.profile_id = saves.profile_id
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
 panel.theme = preload("res://scripts/visuals/art_direction.gd").theme()
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
    combat.damage_player(int(str(body.name)), 10000, body.position, true)

func _bind_key(action: String, code: Key) -> void:
 if not InputMap.has_action(action):
  InputMap.add_action(action)
 var event := InputEventKey.new()
 event.physical_keycode = code
 if not InputMap.action_has_event(action, event):
  InputMap.action_add_event(action, event)


func _process(_delta: float) -> void:
 if not is_instance_valid(player) or world.heights.is_empty():
  return
 var column := clampi(floori(player.position.x / 16.0), 0, world.world_width - 1)
 var depth: float = player.position.y / 16.0 - world.heights[column]
 var underground := clampf((depth - 2.0) / 13.0, 0.0, 1.0)
 var daylight := Daylight.sample(combat.world_time)
 ambient.color = daylight.ambient.lerp(Color("172331"), underground)
 sky.underground = underground


func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_CLOSE_REQUEST:
  _request_close()

func _request_close() -> void:
 if closing:
  return
 closing = true
 if saves.can_save() and not saves.save_now():
  closing = false
  if close_dialog == null:
   close_dialog = ConfirmationDialog.new()
   close_dialog.title = "Не удалось сохранить"
   close_dialog.ok_button_text = "Выйти без сохранения"
   close_dialog.confirmed.connect(func(): get_tree().quit())
   $HUD.add_child(close_dialog)
  close_dialog.dialog_text = saves.status + "\nЗакрыть игру без сохранения?"
  close_dialog.popup_centered()
  return
 if network.active:
  await network.stop()
 get_tree().quit()
