extends Control
const Daylight = preload("res://data/daylight.gd")
var main: Node2D
var underground := 0.0
var stars: Array[Vector3] = []

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var rng := RandomNumberGenerator.new()
 rng.seed = 79463
 for i in range(72):
  stars.append(Vector3(rng.randf_range(0.02, 0.98), rng.randf_range(0.04, 0.73), rng.randf_range(0.45, 1.0)))

func _process(_delta: float) -> void:
 size = get_viewport_rect().size
 queue_redraw()

func _draw() -> void:
 if not is_instance_valid(main.combat): return
 var state := Daylight.sample(main.combat.world_time)
 var cave := Color("172331")
 for y in range(0, ceili(size.y), 4):
  var color: Color = state.top.lerp(state.horizon, pow(clampf(float(y) / size.y, 0, 1), 1.3)).lerp(cave, underground)
  draw_rect(Rect2(0, y, size.x, 4), color)
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

func _disc(at: Vector2, radius: int, color: Color) -> void:
 # Pixel steps rather than antialiased vector circles.
 for y in range(-radius, radius, 2):
  var half_width := floori(sqrt(maxf(0, radius * radius - (y + 1) * (y + 1))) / 2) * 2
  draw_rect(Rect2(at + Vector2(-half_width,y), Vector2(half_width * 2,2)),color)
