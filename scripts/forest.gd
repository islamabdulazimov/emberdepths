extends Node2D
const Trees = preload("res://data/trees.gd")
const Art = preload("res://scripts/visuals/tree_art.gd")
var world: Node2D
var rustle: AudioStreamPlayer
var sound_gain := 0.0

func _ready() -> void:
 world = get_parent()
 z_index = -1
 rustle = AudioStreamPlayer.new()
 rustle.name = "Leaves"
 var stream: AudioStreamWAV = preload("res://assets/audio/leaf_rustle.wav").duplicate()
 stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
 stream.loop_begin = 0
 stream.loop_end = stream.data.size() / 2
 rustle.stream = stream
 rustle.volume_db = -80
 add_child(rustle)
 rustle.play()

func _process(delta: float) -> void:
 var main := world.get_parent()
 var target := 0.0
 var listener = main.get("player")
 if is_instance_valid(listener) and not listener.dead:
  target = Trees.sound_level(world.trees, listener.position)
 sound_gain = lerpf(sound_gain, target, 1.0 - exp(-5.0 * delta))
 rustle.volume_db = maxf(-80, Trees.MAX_VOLUME_DB + linear_to_db(maxf(0.0001, sound_gain)))
 queue_redraw()

func _draw() -> void:
 var main := world.get_parent()
 var combat = main.get("combat")
 if not is_instance_valid(combat): return
 var visible_area := (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(160)
 for record in world.trees:
  if not record.active: continue
  var root := Vector2(record.cell.x * 16 + 8, record.cell.y * 16)
  if not visible_area.has_point(root): continue
  draw_set_transform(root)
  Art.draw_tree(self, record, combat.world_time)
 draw_set_transform_matrix(Transform2D.IDENTITY)

func _exit_tree() -> void:
 if is_instance_valid(rustle):
  rustle.stop()
  rustle.stream = null
