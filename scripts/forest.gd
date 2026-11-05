extends Node2D
const Trees = preload("res://data/trees.gd")
const Art = preload("res://scripts/visuals/tree_art.gd")
var world: Node2D
var rustle: AudioStreamPlayer
var redraw_clock := 0.0
var sound_clock := 0.0
var listener_gain := 0.0
var sound_gain := 0.0
var falling: Array = []

func animate_fall(record: Dictionary, direction: int) -> void:
 var effects = world.get_parent().get("effects")
 if is_instance_valid(effects): effects.burst("leaf",Vector2(record.cell.x*16+8,record.cell.y*16-record.height*12))
 falling.append({"tree": record.duplicate(true),"direction": 1 if direction >= 0 else -1,"age": 0.0})

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
 for i in range(falling.size()-1,-1,-1):
  falling[i].age += delta
  if falling[i].age >= 1.0: falling.remove_at(i)
 var main := world.get_parent()
 sound_clock += delta
 var target := listener_gain
 var listener = main.get("player")
 if sound_clock >= 0.1:
  sound_clock = fmod(sound_clock,0.1)
  listener_gain = Trees.sound_level(world.trees,listener.position) if is_instance_valid(listener) and not listener.dead else 0.0
  target = listener_gain
 sound_gain = lerpf(sound_gain, target, 1.0 - exp(-5.0 * delta))
 rustle.volume_db = maxf(-80, Trees.MAX_VOLUME_DB + linear_to_db(maxf(0.0001, sound_gain)))
 redraw_clock += delta
 if redraw_clock >= 1.0/60 or not falling.is_empty():
  redraw_clock = fmod(redraw_clock,1.0/60)
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
 for entry in falling:
  var record: Dictionary = entry.tree
  var root := Vector2(record.cell.x * 16 + 8,record.cell.y * 16)
  var t: float = clampf((entry.age-0.08)/0.9,0,1)
  draw_set_transform(root,entry.direction * t * t * PI * 0.5)
  Art.draw_tree(self,record,combat.world_time)
 draw_set_transform_matrix(Transform2D.IDENTITY)

func _exit_tree() -> void:
 if is_instance_valid(rustle):
  rustle.stop()
  rustle.stream = null
