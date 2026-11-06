extends Node2D
const PlayerScene = preload("res://scenes/player.tscn")
const Daylight = preload("res://data/daylight.gd")
var player: CharacterBody2D
var interaction: Node2D
var network: Node
var items: Node2D
var combat: Node2D
var altar:Node2D
var encounter: Node2D
var combat_zone: Node2D
var effects: Node2D
var survival:Node2D
var equipment_service:Node
var npcs: Node
var pause_ui: CanvasLayer
var pause_open := false
var input_latched := true
var exploration: Node
var storage: Node2D
var boss_ui: Control
var saves: Node
var close_dialog: ConfirmationDialog
var closing := false
var inventory_ui: CanvasLayer
var ambient: CanvasModulate
var presentation_clock := 0.0
var fps_clock := 0.0
var hud_help_label:Label
var fps_label: Label
var sky: Control
@onready var world = $World

func _ready() -> void:
 fps_label = Label.new()
 fps_label.position = Vector2(708,80)
 fps_label.size = Vector2(224,20)
 fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 fps_label.add_theme_font_size_override("font_size",12)
 fps_label.add_theme_color_override("font_color",Color("b6c9bd"))
 fps_label.add_theme_color_override("font_outline_color",Color("18252e"))
 fps_label.add_theme_constant_override("outline_size",2)
 $HUD.add_child(fps_label)
 hud_help_label=Label.new();hud_help_label.theme=preload("res://scripts/visuals/art_direction.gd").theme();hud_help_label.position=Vector2(14,478);hud_help_label.text="Esc: сумка · P: меню\nShift: перекат · F: парирование\nR: держать щит";hud_help_label.add_theme_font_size_override("font_size",10);hud_help_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;$HUD.add_child(hud_help_label)
 $HUD/Panel.offset_left=570
 $HUD/Panel.offset_right=946
 $HUD/Panel.offset_bottom=78
 $HUD/Panel.theme = preload("res://scripts/visuals/art_direction.gd").theme()
 $HUD/Panel/Label.add_theme_font_size_override("font_size",12)
 $HUD/Panel/Label.clip_text=true
 $HUD/Panel/Label.max_lines_visible=3
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
 combat_zone = Node2D.new()
 combat_zone.name = "CombatZone"
 combat_zone.set_script(preload("res://scripts/combat_zone.gd"))
 add_child(combat_zone)
 storage = Node2D.new()
 storage.name = "Storage"
 storage.set_script(preload("res://scripts/storage_service.gd"))
 add_child(storage)
 exploration = Node.new()
 exploration.name = "Exploration"
 exploration.set_script(preload("res://scripts/exploration.gd"))
 add_child(exploration)
 equipment_service=Node.new();equipment_service.set_script(preload("res://scripts/equipment_service.gd"));add_child(equipment_service)
 survival=Node2D.new();survival.name="Survival";survival.set_script(preload("res://scripts/survival_service.gd"));add_child(survival)
 npcs=Node.new()
 npcs.name="Residents"
 npcs.set_script(preload("res://scripts/residents.gd"))
 add_child(npcs)
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
 resources_ui.theme=preload("res://scripts/visuals/art_direction.gd").theme()
 resources_ui.main = self
 resources_ui.position = Vector2(14, 14)
 $HUD.add_child(resources_ui)
 boss_ui = Control.new()
 boss_ui.set_script(preload("res://scripts/boss_ui.gd"))
 boss_ui.theme=preload("res://scripts/visuals/art_direction.gd").theme()
 boss_ui.main = self
 $HUD.add_child(boss_ui)
 altar=Node2D.new();altar.name="BossAltar";altar.set_script(preload("res://scripts/boss_altar.gd"));add_child(altar)
 encounter.ensure_altar()
 _create_network_ui()
 if not has_meta("combat_test") and not GameApp.selected_world.is_empty() and not GameApp.new_game and not FileAccess.file_exists(saves.save_path) and not FileAccess.file_exists(saves.save_path+".bak"):
  GameApp.menu_error="Файл выбранного мира не найден. Другие миры сохранены."
  get_tree().call_deferred("change_scene_to_file","res://scenes/menu.tscn")
  return
 saves.startup()
 if not GameApp.selected_world.is_empty(): saves.new_button.hide()
 npcs.sync()
 if not GameApp.selected_world.is_empty() and not has_meta("combat_test"):
  if saves.write_blocked:
   GameApp.menu_error=saves.status
   get_tree().call_deferred("change_scene_to_file","res://scenes/menu.tscn")
   return
  if GameApp.new_game:
   equipment_service.starter(1)
   exploration.initialize_loot()
   if not saves.save_now():
    GameApp.menu_error=saves.status
    get_tree().call_deferred("change_scene_to_file","res://scenes/menu.tscn")
    return
  GameApp.new_game=false
  GameApp.touch_world()
 pause_ui=CanvasLayer.new()
 pause_ui.set_script(preload("res://scripts/ui/pause_menu.gd"))
 add_child(pause_ui)
 network_row.reparent(pause_ui);network_row.position=Vector2(14,490)
 network_status.reparent(pause_ui);network_status.position=Vector2(14,524);network_status.hide()
 _arena_button()
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
 if id==1 and not GameApp.selected_character.is_empty(): body.appearance=preload("res://data/appearance.gd").clean(GameApp.selected_character.appearance)
 if id == 1 and is_instance_valid(saves):
  body.profile_id = saves.profile_id
 $Players.add_child(body)
 items.inventory_for(id)
 body.position = position_value
 body.get_node("Camera2D").enabled = false
 body.set_physics_process(not network.active or multiplayer.is_server())
 # Clients already interpolate authoritative snapshots in Network._process.
 body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON if body.is_physics_processing() else Node.PHYSICS_INTERPOLATION_MODE_OFF
 body.get_node("Camera2D").process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS if body.is_physics_processing() else Camera2D.CAMERA2D_PROCESS_IDLE
 body.reset_physics_interpolation()
 # Team membership never recolors selected skin/hair.
 body.modulate = Color.WHITE # Selected skin and hair colors stay identical in co-op.

func select_local_player(id: int) -> void:
 player = $Players.get_node(str(id))
 for body in $Players.get_children():
  body.get_node("Camera2D").enabled = body == player
 var camera: Camera2D = player.get_node("Camera2D")
 camera.limit_left = 0
 camera.limit_right = world.world_width * 16
 camera.limit_top = 0
 camera.limit_bottom = world.world_depth * 16
 player.reset_physics_interpolation()
 camera.align()
 camera.reset_smoothing()
 camera.reset_physics_interpolation()
 if is_instance_valid(interaction):
  interaction.player = player

func remove_player(id: int) -> void:
 survival.cancel_helper(id);survival.cancel_target(id);survival.intents.erase(id)
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
 network_row=panel
 panel.hide()
 $HUD.add_child(panel)
 var address := LineEdit.new()
 address.placeholder_text = "IP хоста"
 address.text = "127.0.0.1"
 address.custom_minimum_size.x = 180
 panel.add_child(address)
 var host := Button.new()
 host.text = "Создать сервер"
 panel.add_child(host)
 host.pressed.connect(func():
  if network.host_game()==OK:get_tree().paused=false
  network_status.text=network.status
  get_viewport().gui_release_focus())
 var join := Button.new()
 join.text = "Подключиться"
 panel.add_child(join)
 join.pressed.connect(func():
  if network.join_game(address.text)==OK:get_tree().paused=false
  network_status.text=network.status
  get_viewport().gui_release_focus())
 var leave := Button.new()
 leave.text = "Отключиться"
 panel.add_child(leave)
 leave.pressed.connect(func():
  await network.stop()
  if pause_open:get_tree().paused=true
  network_status.text=network.status
  get_viewport().gui_release_focus())
 var status_label := Label.new()
 status_label.position = Vector2(14, 508)
 $HUD.add_child(status_label)
 network_status = status_label

var network_row:HBoxContainer
var network_status: Label

func _physics_process(_delta: float) -> void:
 if is_instance_valid(network_status):
  network_status.text = network.status
  if network.active and network.connected:
   network_status.text += " · В мире: %d/4" % $Players.get_child_count()
 if not is_instance_valid(player):
  return
 var typing := get_viewport().gui_get_focus_owner() is LineEdit or ui_blocked()
 network.block_local(not typing and not inventory_ui.opened and Input.is_physical_key_pressed(KEY_R))
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


func ui_blocked() -> bool:
 return pause_open or input_latched or (is_instance_valid(altar) and altar.opened) or (is_instance_valid(player) and player.dead) or (is_instance_valid(npcs) and npcs.opened)

func _process(delta: float) -> void:
 if is_instance_valid(saves) and is_instance_valid(saves.save_button):saves.save_button.get_parent().hide();saves.save_label.hide()
 if is_instance_valid(network_row):network_row.visible=pause_open and not has_meta("combat_test")
 if pause_open and not network.active and not network.stopping:get_tree().paused=true
 if input_latched and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): input_latched=false
 fps_clock += delta
 if fps_clock >= 0.5:
  fps_clock = fmod(fps_clock,0.5)
  fps_label.text = "%d FPS · %s" % [Engine.get_frames_per_second(),"без лимита" if Engine.max_fps==0 else "лимит %d" % Engine.max_fps]
 presentation_clock += delta
 if delta > 0 and presentation_clock < 1.0/30: return
 presentation_clock = fmod(presentation_clock,1.0/30)
 if not is_instance_valid(player) or world.heights.is_empty():
  return
 var column := clampi(floori(player.position.x / 16.0), 0, world.world_width - 1)
 var depth: float = player.position.y / 16.0 - world.heights[column]
 var underground := clampf((depth - 2.0) / 13.0, 0.0, 1.0)
 var daylight := Daylight.sample(combat.world_time)
 var cave_color := Color("172331")
 if world.generator_version >= 2:
  cave_color = preload("res://data/world_regions.gd").AMBIENT.roots.lerp(preload("res://data/world_regions.gd").AMBIENT.deep,smoothstep(preload("res://data/world_regions.gd").deep_start(world)-6,preload("res://data/world_regions.gd").deep_start(world)+6,player.position.y/16.0))
 ambient.color = daylight.ambient.lerp(cave_color,underground)
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

func _arena_button() -> void:
 if has_meta("combat_test"): return
 var button := Button.new()
 button.text = "Проверка боя"
 button.tooltip_text = "Сохранить свой мир и открыть отдельную временную арену"
 button.position = Vector2(790,106)
 button.theme = preload("res://scripts/visuals/art_direction.gd").theme()
 button.focus_mode = Control.FOCUS_NONE
 $HUD.add_child(button)
 button.pressed.connect(func():
  if network.active:
   network.status = "Перед ареной выйдите из сетевой игры"
   return
  if not saves.save_now(): return
  get_tree().change_scene_to_file("res://scenes/combat_arena.tscn"))
