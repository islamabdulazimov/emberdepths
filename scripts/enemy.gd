extends CharacterBody2D
var kind := "ashling"
var health := 45
var max_health := 45
var base_health := 45
var scaling_players := 1
var anchor := Vector2.ZERO
var grace := 0.0
var hurt_flash := 0.0
var hit_stun := 0.0
var clock := 0.0
var night := false
var visual_health := -1

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
 if visual_health >= 0 and health < visual_health:
  var main := get_parent().get_parent()
  if is_instance_valid(main.get("effects")): main.effects.burst("hurt",position+Vector2(0,-6))
 visual_health = health
 clock += delta
 hurt_flash = maxf(0.0, hurt_flash - delta)
 queue_redraw()

func _draw() -> void:
 var art = preload("res://scripts/visuals/enemy_art.gd")
 if kind == "spirit": art.draw_spirit(self,clock,velocity,hurt_flash)
 else: art.draw_ashling(self,clock,velocity,hurt_flash,night)
 draw_rect(Rect2(-8,-23,16,2),Color("18252e"))
 draw_rect(Rect2(-8,-23,16*float(health)/max_health,2),Color("bd8058") if kind == "ashling" else Color("88aaa9"))
