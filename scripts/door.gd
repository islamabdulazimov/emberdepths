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
 var top := -8 - (Structures.DOOR_HEIGHT-1)*16
 var height := Structures.DOOR_HEIGHT*16
 # The leaf folds into the doorway; adjacent world cells remain free.
 draw_rect(Rect2(-8,top,2,height),Color("574539"))
 draw_rect(Rect2(6,top,2,height),Color("574539"))
 draw_rect(Rect2(-8,top,16,2),Color("c09a68"))
 var width := lerpf(12,3,visual_open)
 draw_rect(Rect2(-6,top+2,width,height-2),Color("99734f"))
 for x in range(0,3):
  if x*4 >= width: break
  draw_rect(Rect2(-6+x*4,top+3,1,height-4),Color("c09a68"))
 for y in [top+10,top+height-10]:
  draw_rect(Rect2(-6,y,width,2),Color("4a4d45"))
 draw_rect(Rect2(-8+width,-12,2,3),Color("d7bc77"))
