extends CharacterBody2D
const Items = preload("res://data/items.gd")
var item_id := "dirt"
var count := 1
var age := 0.0
var visual_time := 0.0
var icon: Texture2D

func _ready() -> void:
 collision_layer = 4
 collision_mask = 1
 var collider := CollisionShape2D.new()
 var shape := CircleShape2D.new()
 shape.radius = 3.0
 collider.shape = shape
 add_child(collider)
 icon = Items.icon(item_id)
 z_index = 2

func _process(delta: float) -> void:
 visual_time += delta
 queue_redraw()

func _draw() -> void:
 var phase := visual_time*3.5+float(item_id.hash()%31)
 var bob := roundf(sin(phase))
 draw_rect(Rect2(-4,3,8,1),Color(0.05,0.10,0.13,0.22))
 draw_texture_rect(icon,Rect2(Vector2(-4,-5+bob),Vector2(8,8)),false)
 var sparkle := fposmod(phase*0.22,1.0)
 if sparkle < 0.35:
  var color := Color("e1dec2")
  color.a = sin(sparkle/0.35*PI)*0.7
  draw_line(Vector2(5,-7+bob),Vector2(5,-3+bob),color,1)
  draw_line(Vector2(3,-5+bob),Vector2(7,-5+bob),color,1)
