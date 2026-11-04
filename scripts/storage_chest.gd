extends Node2D
var inventory = preload("res://scripts/inventory.gd").new()
var anchor := Vector2i.ZERO
var revision := 0
var known_empty := true
var opened := false
var lid := 0.0

func _ready() -> void:
 z_index = 1
 lid = 1.0 if opened else 0.0

func _process(delta: float) -> void:
 lid = lerpf(lid,1.0 if opened else 0.0,1-exp(-18*delta))
 queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(-16,-6,32,14),Color("303b43"))
 draw_rect(Rect2(-15,-5,30,12),Color("98734f"))
 draw_rect(Rect2(-13,3,26,2),Color("644c3d"))
 var lift := roundf(lid*5)
 draw_rect(Rect2(-16,-8-lift,32,5),Color("ba9468"))
 draw_rect(Rect2(-15,-8-lift,30,1),Color("d6b581"))
 for x in [-13,10]:
  draw_rect(Rect2(x,-7-lift,3,5),Color("78969a"))
  draw_rect(Rect2(x,-3,3,10),Color("57757c"))
 draw_rect(Rect2(-2,-2,4,5),Color("9bb4b2"))
