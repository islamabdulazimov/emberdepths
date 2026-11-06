extends Control
var appearance: Dictionary = {}
var body: CharacterBody2D
var preview_mode:="idle"
var preview_clock:=0.0
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
 body.set_physics_process(false)
 body.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
 body.get_node("Camera2D").enabled=false
func update_appearance(value: Dictionary) -> void:
 appearance = value.duplicate()
 if is_instance_valid(body):
  body.appearance = preload("res://data/appearance.gd").clean(value)
  body.queue_redraw()

func set_preview(value:String) -> void:
 if value not in ["idle","run","attack"]:return
 preview_mode=value;preview_clock=0
 if is_instance_valid(body):body.fighter.reset()
func _process(delta:float) -> void:
 if not is_instance_valid(body):return
 preview_clock+=delta
 body.velocity=Vector2(115,0) if preview_mode=="run" else Vector2.ZERO
 if preview_mode=="attack":
  var phase:=fposmod(preview_clock,.9)
  if phase<.47:
   body.fighter.mode="attack";body.fighter.elapsed=phase;body.fighter.duration=.47;body.held_item="wood_sword"
  else:body.fighter.reset()
 elif body.fighter.mode!="idle":body.fighter.reset()
