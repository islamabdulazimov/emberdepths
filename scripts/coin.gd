extends CharacterBody2D
var amount:=1
var age:=0.0
var clock:=0.0
func _ready() -> void:
 collision_layer=4;collision_mask=1;z_index=4
 var collider:=CollisionShape2D.new();var shape:=CircleShape2D.new();shape.radius=3;collider.shape=shape;add_child(collider)
func _process(delta:float) -> void:
 clock+=delta;queue_redraw()
func _draw() -> void:
 var bob:=roundf(sin(clock*3.0))
 draw_rect(Rect2(-5,3,10,1),Color(0.05,0.08,0.1,.3))
 draw_texture_rect(preload("res://assets/recast/coin.png"),Rect2(-6,-8+bob,12,12),false)
