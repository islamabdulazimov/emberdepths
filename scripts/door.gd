extends StaticBody2D
const Structures = preload("res://data/structures.gd")
var anchor := Vector2i.ZERO
var opened := false
var visual_open := 0.0
var ready_at := 0
var collider: CollisionShape2D

func _ready() -> void:
 collision_layer = 1
 collision_mask = 0
 z_index = 1
 collider = CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 shape.size = Vector2(12,Structures.DOOR_HEIGHT*16)
 collider.shape = shape
 collider.position = Vector2(0,-(Structures.DOOR_HEIGHT-1)*8)
 collider.disabled = opened
 add_child(collider)
 visual_open = 1.0 if opened else 0.0

func set_open(value: bool) -> void:
 opened = value
 collider.set_deferred("disabled",opened)
 queue_redraw()

func _process(delta: float) -> void:
 visual_open = lerpf(visual_open,1.0 if opened else 0.0,1-exp(-20*delta))
 queue_redraw()

func _draw() -> void:
 draw_texture_rect_region(preload("res://assets/recast/door.png"),Rect2(-8,-40,16,48),Rect2(clampi(roundi(visual_open*5),0,5)*16,0,16,48))
