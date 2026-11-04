extends RefCounted
const MIN_HEIGHT := 5
const MAX_HEIGHT := 8
const FORMS := 3
const SOUND_RADIUS := 192.0
const MAX_VOLUME_DB := -18.0

static func generate(world: Node2D) -> Array:
 var result: Array = []
 var rng := RandomNumberGenerator.new()
 rng.seed = world.world_seed ^ 0x4a71b
 var column := rng.randi_range(4, 8)
 while column < world.world_width - 4:
  var ground := Vector2i(column, world.heights[column])
  var height := rng.randi_range(MIN_HEIGHT, MAX_HEIGHT)
  var form := rng.randi_range(0, FORMS - 1)
  var seed_value := rng.randi_range(0, 2147483647)
  # Keep all four spawn positions and the immediate landing area clear.
  var suitable: bool = absi(column - world.world_width / 2) >= 11 and ground.y >= height + 2 and world.block_at(ground) in [0, 1]
  for x in range(column - 3, column + 4):
   for y in range(ground.y - height - 2, ground.y):
    # Trunk corridor and the higher canopy must not intersect hills.
    if (absi(x - column) <= 1 or y < ground.y - height + 3) and world.block_at(Vector2i(x,y)) != -1:
     suitable = false
  if suitable:
   result.append({"cell": ground, "height": height, "form": form, "seed": seed_value, "active": true})
  column += rng.randi_range(6, 10)
 return result

static func wind(record: Dictionary, time: float) -> float:
 var phase := float(posmod(int(record.seed), 6283)) / 1000.0
 return sin(time * (0.8 + float(posmod(int(record.seed), 7)) * 0.045) + phase) * 1.2 + sin(time * 1.9 + phase * 2.7) * 0.45

static func sound_level(records: Array, listener: Vector2) -> float:
 var silence := 1.0
 for record in records:
  if not record.active: continue
  var root := Vector2(record.cell.x * 16 + 8, record.cell.y * 16)
  var nearest := Vector2(root.x, clampf(listener.y, root.y - record.height * 16, root.y))
  var closeness := 1.0 - smoothstep(24.0, SOUND_RADIUS, listener.distance_to(nearest))
  closeness *= 1.0 - smoothstep(24.0, 64.0, listener.y - root.y)
  silence *= 1.0 - closeness * 0.65
 return clampf(1.0 - silence, 0, 1)
