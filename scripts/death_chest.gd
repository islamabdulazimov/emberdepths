extends Node2D
var equipment:Dictionary={}
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
 draw_texture_rect_region(preload("res://assets/recast/chest.png"),Rect2(-10,-12,20,20),Rect2(0,0,32,32),Color("b1c4c3"))
 var at := Vector2(0,roundf(-15-sin(clock*2)*1.5))
 var color := Color("88aaa9")
 draw_line(at+Vector2(0,-3),at+Vector2(3,0),color,1)
 draw_line(at+Vector2(3,0),at+Vector2(0,3),color,1)
 draw_line(at+Vector2(0,3),at+Vector2(-3,0),color,1)
 draw_line(at+Vector2(-3,0),at+Vector2(0,-3),color,1)
 for i in range(2):
  var t := fposmod(clock*0.3+i*0.5,1)
  draw_rect(Rect2(-4+i*7,-8-t*12,1,2),Color(0.53,0.67,0.66,(1-t)*0.4))
