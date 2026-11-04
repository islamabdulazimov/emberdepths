extends Node2D
var owner_id := 1
var owner_profile := ""
var contents: Array = []
var clock := 0.0

func _ready() -> void:
 z_index = 3

func _process(delta: float) -> void:
 clock += delta
 queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(-8, -6, 16, 14), Color("584f51"))
 draw_rect(Rect2(-7, -7, 14, 5), Color("a27d5b"))
 draw_rect(Rect2(-7, 0, 14, 6), Color("795a49"))
 draw_rect(Rect2(-5, -6, 2, 13), Color("c6a86f"))
 draw_rect(Rect2(3, -6, 2, 13), Color("c6a86f"))
 draw_rect(Rect2(-1, -2, 3, 4), Color("f1d797"))
 draw_circle(Vector2(0, -13 - sin(clock * 3)), 2, Color("c5e5d2"))
