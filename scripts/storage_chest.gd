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
 draw_texture_rect_region(preload("res://assets/recast/chest.png"),Rect2(-16,-24,32,32),Rect2(clampi(roundi(lid*5),0,5)*32,0,32,32))
