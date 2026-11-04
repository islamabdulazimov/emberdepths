extends Node2D
static var light_texture: Texture2D
var clock := 0.0
var light: PointLight2D

func _ready() -> void:
 if light_texture == null:
  var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
  for y in range(128):
   for x in range(128):
    var distance := Vector2(x-63.5,y-63.5).length()/64
    image.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-distance),1.4)))
  light_texture = ImageTexture.create_from_image(image)
 clock = position.x*0.071+position.y*0.037
 light = PointLight2D.new()
 light.texture = light_texture
 light.texture_scale = 1.5
 light.color = Color("ffcf88")
 light.energy = 1.35
 add_child(light)
 z_index = 1
func _process(delta: float) -> void:
 clock += delta
 light.energy = 1.35+sin(clock*5.1)*0.035+sin(clock*11.3)*0.025
 queue_redraw()
func _draw() -> void:
 var frame := floori(clock*9)
 var bend := posmod(frame*7,3)-1
 var height := 5+posmod(frame,3)
 draw_rect(Rect2(-2,-1,4,9),Color("18252e"))
 draw_rect(Rect2(-1,0,2,7),Color("bd8058"))
 draw_rect(Rect2(-3,-1,6,2),Color("455d68"))
 draw_rect(Rect2(-2,-height,4,height),Color("bd8058"))
 draw_rect(Rect2(-1+bend,-height-1,2,height-1),Color("f2b36e"))
 draw_rect(Rect2(0,-4,1,4),Color("f4e2b6"))
 var rise := fposmod(clock*0.7,1)
 draw_rect(Rect2(roundf(sin(clock*2)*2),roundf(-9-rise*8),1,1),Color(0.94,0.72,0.44,(1-rise)*0.7))
