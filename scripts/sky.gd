extends Control
const Daylight = preload("res://data/daylight.gd")
var redraw_clock := 0.0
var sky_gradient := Gradient.new()
var sky_texture := GradientTexture2D.new()
var main: Node2D
var underground := 0.0
var stars: Array[Vector3] = []

func _ready() -> void:
 sky_texture.gradient = sky_gradient
 sky_texture.width = 1
 sky_texture.height = 128
 sky_texture.fill_from = Vector2.ZERO
 sky_texture.fill_to = Vector2(0,1)
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var rng := RandomNumberGenerator.new()
 rng.seed = 79463
 for i in range(72):
  stars.append(Vector3(rng.randf_range(0.02, 0.98), rng.randf_range(0.04, 0.73), rng.randf_range(0.45, 1.0)))

func _process(delta: float) -> void:
 redraw_clock += delta
 var resized := size != get_viewport_rect().size
 if redraw_clock < 1.0/30 and not resized: return
 redraw_clock = fmod(redraw_clock,1.0/30)
 size = get_viewport_rect().size
 if is_instance_valid(main.combat):
  var state := Daylight.sample(main.combat.world_time)
  sky_gradient.offsets = PackedFloat32Array([0,0.55,1])
  sky_gradient.colors = PackedColorArray([state.top.lerp(Color("172331"),underground),state.top.lerp(state.horizon,0.46).lerp(Color("172331"),underground),state.horizon.lerp(Color("172331"),underground)])
 queue_redraw()

func _draw() -> void:
 if size.x < 32 or size.y < 32 or not is_instance_valid(main.combat): return
 var state := Daylight.sample(main.combat.world_time)
 draw_texture_rect(sky_texture,Rect2(Vector2.ZERO,size),false)
 var visibility := 1.0 - underground
 for star in stars:
  var sparkle := 0.8 + sin(main.combat.world_time * 1.7 + star.x * 90) * 0.2
  var alpha: float = float(state.stars) * star.z * visibility * sparkle
  if alpha < 0.01: continue
  var at := Vector2(star.x * size.x, star.y * size.y).round()
  draw_rect(Rect2(at, Vector2.ONE * (2 if star.z > 0.8 else 1)), Color(0.89,0.93,1,alpha))
 if state.sun_alpha>0:draw_texture_rect(preload("res://assets/recast/sun.png"),Rect2(Daylight.orbit(state.sun_progress,size).round()-Vector2(20,20),Vector2(40,40)),false,Color(1,1,1,state.sun_alpha*visibility))
 if state.moon_alpha>0:draw_texture_rect(preload("res://assets/recast/moon.png"),Rect2(Daylight.orbit(state.moon_progress,size).round()-Vector2(20,20),Vector2(40,40)),false,Color(1,1,1,state.moon_alpha*visibility))
 for i in range(6):
  var x:=fposmod(i*193.0+main.combat.world_time*(0.7+i*0.09),size.x+180)-90
  var y:=size.y*(0.15+float(i%3)*0.075)
  draw_texture_rect_region(preload("res://assets/recast/clouds.png"),Rect2(Vector2(roundf(x),roundf(y)),Vector2(64,24)),Rect2(i%4*64,0,64,24),Color(1,1,1,visibility*lerpf(0.4,0.1,state.night)))
 for layer in range(3):
  var texture:Texture2D=[preload("res://assets/recast/background_0.png"),preload("res://assets/recast/background_1.png"),preload("res://assets/recast/background_2.png")][layer]
  draw_texture_rect(texture,Rect2(Vector2.ZERO,size),false,Color.WHITE.lerp(Color("7c91aa"),state.night)*Color(1,1,1,visibility*0.82))

func _disc(at: Vector2, radius: int, color: Color) -> void:
 # Pixel steps rather than antialiased vector circles.
 for y in range(-radius, radius, 2):
  var half_width := floori(sqrt(maxf(0, radius * radius - (y + 1) * (y + 1))) / 2) * 2
  draw_rect(Rect2(at + Vector2(-half_width,y), Vector2(half_width * 2,2)),color)
