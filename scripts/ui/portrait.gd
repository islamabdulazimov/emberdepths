extends Control
var appearance: Dictionary = {}
var body: CharacterBody2D
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 body = preload("res://scenes/player.tscn").instantiate()
 body.appearance = preload("res://data/appearance.gd").clean(appearance)
 body.get_node("Camera2D").enabled = false
 body.get_node("Collision").disabled = true
 body.collision_layer = 0
 body.collision_mask = 0
 body.set_physics_process(false)
 body.position = Vector2(40,70)
 body.scale = Vector2(2,2)
 add_child(body)
func update_appearance(value: Dictionary) -> void:
 appearance = value.duplicate()
 if is_instance_valid(body):
  body.appearance = preload("res://data/appearance.gd").clean(value)
  body.queue_redraw()
