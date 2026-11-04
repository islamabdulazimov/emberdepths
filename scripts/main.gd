extends Node2D
const PlayerScene = preload("res://scenes/player.tscn")
var player: CharacterBody2D
@onready var world = $World

func _ready() -> void:
 RenderingServer.set_default_clear_color(Color("8aabb0"))
 _bind_key("move_left", KEY_A)
 _bind_key("move_right", KEY_D)
 _bind_key("jump", KEY_SPACE)
 # Player IDs will be peer IDs, with a maximum of four connected players.
 player = PlayerScene.instantiate()
 player.name = "1"
 $Players.add_child(player)
 player.position = world.spawn_position()
 var camera: Camera2D = player.get_node("Camera2D")
 camera.limit_left = 0
 camera.limit_right = world.world_width * 16
 camera.limit_top = 0
 camera.limit_bottom = world.world_depth * 16
 camera.reset_smoothing()
 var interaction := Node2D.new()
 interaction.set_script(preload("res://scripts/interaction.gd"))
 interaction.world = world
 interaction.player = player
 interaction.bodies = $Players
 interaction.label = $HUD/Panel/Label
 interaction.z_index = 5
 add_child(interaction)

func _physics_process(_delta: float) -> void:
 player.submit_command(Input.get_axis("move_left", "move_right"), Input.is_action_just_pressed("jump"))
 # Temporary world borders. Later these become streaming boundaries.
 player.position.x = clampf(player.position.x, 6.0, world.world_width * 16.0 - 6.0)
 if player.position.y > world.world_depth * 16 + 64:
  player.position = world.spawn_position()
  player.velocity = Vector2.ZERO

func _bind_key(action: String, code: Key) -> void:
 if not InputMap.has_action(action):
  InputMap.add_action(action)
 var event := InputEventKey.new()
 event.physical_keycode = code
 if not InputMap.action_has_event(action, event):
  InputMap.action_add_event(action, event)
