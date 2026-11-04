extends Node2D
static var light_texture: Texture2D
var clock := 0.0
var light: PointLight2D

func _ready() -> void:
 if light_texture == null:
  var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
  for y in range(128):
   for x in range(128):
    var distance := Vector2(x - 63.5, y - 63.5).length() / 64.0
    var strength := pow(maxf(0.0, 1.0 - distance), 1.4)
    image.set_pixel(x, y, Color(1, 1, 1, strength))
  light_texture = ImageTexture.create_from_image(image)
 light = PointLight2D.new()
 light.texture = light_texture
 light.texture_scale = 1.5
 light.color = Color("ffcf88")
 light.energy = 1.35
 add_child(light)
 z_index = 1

func _process(delta: float) -> void:
 clock += delta
 light.energy = 1.35 + sin(clock * 7.0) * 0.045
 queue_redraw()

func _draw() -> void:
 draw_texture_rect(preload("res://data/items.gd").icon("torch"), Rect2(-8, -8, 16, 16), false)
