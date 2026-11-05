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
 if state.sun_alpha > 0:
  var at := Daylight.orbit(state.sun_progress, size).round()
  var alpha: float = state.sun_alpha * visibility
  _disc(at, 20, Color(1,0.79,0.47,0.06 * alpha))
  _disc(at, 15, Color(1,0.83,0.51,0.12 * alpha))
  _disc(at, 11, Color(1,0.84,0.54,alpha))
  _disc(at + Vector2(-1,-1), 8, Color(1,0.94,0.73,alpha))
 if state.moon_alpha > 0:
  var at := Daylight.orbit(state.moon_progress, size).round()
  var alpha: float = state.moon_alpha * visibility
  _disc(at, 18, Color(0.68,0.82,0.98,0.06 * alpha))
  _disc(at, 10, Color(0.82,0.89,0.88,alpha))
  _disc(at + Vector2(3,-1), 8, Color(0.56,0.66,0.73,alpha))
  draw_rect(Rect2(at + Vector2(-5,-4),Vector2(3,3)),Color(0.65,0.75,0.77,alpha))
  draw_rect(Rect2(at + Vector2(-3,3),Vector2(2,2)),Color(0.65,0.75,0.77,alpha))

 # Slow cloud shelves and distant basalt spires use the shared world time too.
 for i in range(6):
  var x := fposmod(i*193.0+main.combat.world_time*(0.7+i*0.09),size.x+180)-90
  var y := size.y*(0.16+float(i%3)*0.075)
  var cloud: Color = state.horizon.lerp(Color("e1dec2"),0.25)
  cloud.a = visibility*lerpf(0.30,0.08,state.night)
  draw_rect(Rect2(roundf(x),roundf(y),66+i%3*14,4),cloud)
  draw_rect(Rect2(roundf(x+12),roundf(y-3),37+i%2*9,3),cloud)
 for layer in range(3):
  var ridge := PackedVector2Array([Vector2(0,size.y)])
  var base := size.y*(0.71+layer*0.085)
  for i in range(18):
   var x := float(i)/17*size.x
   var height := float(posmod(i*37+layer*71,43))+12
   ridge.append(Vector2(x,base-height))
   if i%3 == 0:
    ridge.append(Vector2(x+4,base-height-13))
    ridge.append(Vector2(x+10,base-height-13))
  ridge.append(size)
  var color: Color = state.horizon.lerp(Color("293b46"),0.3+layer*0.15)
  color.a = visibility*0.7
  draw_colored_polygon(ridge,color)

 # Weathered spans on the far horizon. Original, purely background architecture.
 var ruin: Color = state.horizon.lerp(Color("293b46"),0.43)
 ruin.a = visibility*0.55
 for i in range(4):
  var x := floorf(size.x*(0.12+i*0.24))
  var y := floorf(size.y*(0.62+float(i%2)*0.055))
  draw_rect(Rect2(x,y,5,38),ruin)
  draw_rect(Rect2(x+29,y+4,7,34),ruin)
  draw_rect(Rect2(x-2,y-5,40,5),ruin)
  draw_rect(Rect2(x+5,y,5,5),ruin)
  draw_rect(Rect2(x+24,y+1,5,5),ruin)
  draw_rect(Rect2(x-1,y-11,8,6),ruin)

func _disc(at: Vector2, radius: int, color: Color) -> void:
 # Pixel steps rather than antialiased vector circles.
 for y in range(-radius, radius, 2):
  var half_width := floori(sqrt(maxf(0, radius * radius - (y + 1) * (y + 1))) / 2) * 2
  draw_rect(Rect2(at + Vector2(-half_width,y), Vector2(half_width * 2,2)),color)
