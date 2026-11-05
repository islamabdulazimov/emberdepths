extends Node2D
# Retained draw commands: rebuilt only when visible terrain changes.
var rectangles: Array = []
var lines: Array = []
func _draw() -> void:
 for mark in rectangles: draw_rect(mark[0],mark[1])
 for mark in lines: draw_line(mark[0],mark[1],mark[2],1)
