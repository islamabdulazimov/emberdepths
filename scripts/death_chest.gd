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
 var at := Vector2(0,roundf(-15-sin(clock*2)*1.5))
 var color := Color("88aaa9")
 draw_line(at+Vector2(0,-3),at+Vector2(3,0),color,1)
 draw_line(at+Vector2(3,0),at+Vector2(0,3),color,1)
 draw_line(at+Vector2(0,3),at+Vector2(-3,0),color,1)
 draw_line(at+Vector2(-3,0),at+Vector2(0,-3),color,1)
 for i in range(2):
  var t := fposmod(clock*0.3+i*0.5,1)
  draw_rect(Rect2(-4+i*7,-8-t*12,1,2),Color(0.53,0.67,0.66,(1-t)*0.4))
