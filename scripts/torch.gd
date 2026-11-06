extends Node2D
static var light_texture: Texture2D
var clock := 0.0
var base_energy := 0.85
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
 light.energy = base_energy
 add_child(light)
 z_index = 1
func _process(delta: float) -> void:
 clock += delta
 var factor:=1.0
 var main:=get_parent().get_parent()
 if is_instance_valid(main.get("combat")):
  var night:float=preload("res://data/daylight.gd").sample(main.combat.world_time).night
  var column:=clampi(floori(global_position.x/16),0,main.world.world_width-1)
  var depth:float=global_position.y/16-main.world.heights[column]
  factor=lerpf(0.08,1.0,maxf(night,smoothstep(2,15,depth)))
 light.energy=(base_energy+sin(clock*5.1)*0.025+sin(clock*11.3)*0.015)*factor
 queue_redraw()
func _draw() -> void:
 draw_texture_rect_region(preload("res://assets/recast/torch.png"),Rect2(-8,-15,16,24),Rect2(int(clock*10)%8*16,0,16,24))
