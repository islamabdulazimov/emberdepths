extends CharacterBody2D
const Items = preload("res://data/items.gd")
var item_id := "dirt"
var count := 1
var age := 0.0
var visual_time := 0.0
var atlas := AtlasTexture.new()

func _ready() -> void:
 collision_layer = 4
 collision_mask = 1
 var collider := CollisionShape2D.new()
 var shape := CircleShape2D.new()
 shape.radius = 3.0
 collider.shape = shape
 add_child(collider)
 atlas.atlas = preload("res://assets/terrain.png")
 atlas.region = Rect2(Vector2(Items.DEFINITIONS[item_id].atlas) * 16.0, Vector2(16, 16))
 z_index = 2

func _process(delta: float) -> void:
 visual_time += delta
 queue_redraw()

func _draw() -> void:
 draw_circle(Vector2.ZERO, 5.5, Color(0.95, 0.83, 0.55, 0.25))
 draw_texture_rect(atlas, Rect2(Vector2(-4, -5 + sin(visual_time * 4.0)), Vector2(8, 8)), false)
