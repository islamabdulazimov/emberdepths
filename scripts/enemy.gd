extends CharacterBody2D
var kind := "ashling"
var health := 45
var max_health := 45
var anchor := Vector2.ZERO
var grace := 0.0
var hurt_flash := 0.0
var hit_stun := 0.0
var clock := 0.0
var night := false

func _ready() -> void:
 collision_layer = 8
 collision_mask = 0 if kind == "spirit" else 1
 var collider := CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 shape.size = Vector2(14, 12)
 collider.shape = shape
 collider.position = Vector2(0, -6)
 add_child(collider)
 z_index = 3

func _process(delta: float) -> void:
 clock += delta
 hurt_flash = maxf(0.0, hurt_flash - delta)
 queue_redraw()

func _draw() -> void:
 if kind == "spirit":
  var shift := sin(clock * 6.0) * 1.5
  draw_colored_polygon(PackedVector2Array([Vector2(-7,-6), Vector2(-4,-14), Vector2(3,-16), Vector2(7,-9), Vector2(4,1), Vector2(0,-2), Vector2(-4,1)]), Color("abd7d1") if hurt_flash <= 0 else Color.WHITE)
  draw_rect(Rect2(-4, -10 + shift, 2, 3), Color("304b63"))
  draw_rect(Rect2(2, -10 + shift, 2, 3), Color("304b63"))
  for i in range(3):
   draw_rect(Rect2(-3 + i * 3, 2 + shift + i, 2, 3), Color(0.55, 0.78, 0.8, 0.3))
 else:
  var body_color := Color("667167") if hurt_flash <= 0 else Color("e0b09c")
  draw_colored_polygon(PackedVector2Array([Vector2(-8,0),Vector2(-8,-6),Vector2(-5,-12),Vector2(3,-14),Vector2(8,-7),Vector2(8,0)]), body_color)
  draw_rect(Rect2(-5, -12, 3, 7), Color("8a9180"))
  draw_rect(Rect2(0, -11, 2, 5), Color("424f50"))
  var look := 1 if velocity.x >= 0 else -1
  draw_rect(Rect2(look * 4 - 1, -8, 3, 2), Color("f2ad66") if night else Color("d8cc8a"))
  for i in range(3):
   draw_rect(Rect2(-6 + i * 5, -1, 2, 3 + sin(clock * 14 + i) * 1.5), Color("3a494a"))
 draw_rect(Rect2(-8, -21, 16, 2), Color("413946"))
 draw_rect(Rect2(-8, -21, 16 * float(health) / max_health, 2), Color("e49979") if kind == "ashling" else Color("a4deda"))
