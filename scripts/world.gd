extends Node2D
const Blocks = preload("res://data/blocks.gd")
@export var world_seed: int = 72419
@export var world_width: int = 192
@export var world_depth: int = 72
var solid: TileMapLayer
var walls: TileMapLayer
var heights: PackedInt32Array = []

func _ready() -> void:
 generate()

func generate() -> void:
 heights.clear()
 var tiles := TileSet.new()
 tiles.tile_size = Vector2i(16, 16)
 tiles.add_physics_layer()
 tiles.set_physics_layer_collision_layer(0, 1)
 var atlas := TileSetAtlasSource.new()
 atlas.texture = preload("res://assets/terrain.png")
 atlas.texture_region_size = Vector2i(16, 16)
 tiles.add_source(atlas, 0)
 for id in Blocks.DEFINITIONS:
  var cell: Vector2i = Blocks.DEFINITIONS[id].atlas
  atlas.create_tile(cell)
  var tile := atlas.get_tile_data(cell, 0)
  tile.set_collision_polygons_count(0, 1)
  tile.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8,-8), Vector2(8,-8), Vector2(8,8), Vector2(-8,8)]))
 walls = TileMapLayer.new()
 walls.name = "BackgroundWalls"
 walls.tile_set = tiles
 walls.collision_enabled = false
 walls.modulate = Color(0.38, 0.40, 0.49)
 add_child(walls)
 solid = TileMapLayer.new()
 solid.name = "SolidBlocks"
 solid.tile_set = tiles
 add_child(solid)
 var surface := FastNoiseLite.new()
 surface.seed = world_seed
 surface.frequency = 0.035
 var caves := FastNoiseLite.new()
 caves.seed = world_seed + 1
 caves.frequency = 0.075
 for x in range(world_width):
  var top := 22 + roundi(surface.get_noise_1d(x) * 9.0)
  # A safe, flat landing area for up to four future players.
  if absi(x - world_width / 2) < 8:
   top = 22
  heights.append(top)
  for y in range(top, world_depth):
   var id: int = Blocks.GRASS if y == top else (Blocks.DIRT if y < top + 6 else Blocks.STONE)
   walls.set_cell(Vector2i(x, y), 0, Vector2i(2, 0))
   var is_cave := y > top + 7 and y < world_depth - 2 and absf(caves.get_noise_2d(x, y)) < 0.105
   if not is_cave:
    solid.set_cell(Vector2i(x, y), 0, Blocks.DEFINITIONS[id].atlas)
 solid.update_internals()

func spawn_position() -> Vector2:
 return Vector2((world_width / 2) * 16 + 8, 22 * 16 - 24)

# Only this boundary mutates terrain; the future host will validate requests here.
const REACH := 80.0
var changes: Dictionary = {} # Vector2i -> stable block ID; -1 means mined air.

func cell_at(global_point: Vector2) -> Vector2i:
 return solid.local_to_map(solid.to_local(global_point))

func cell_center(cell: Vector2i) -> Vector2:
 return solid.to_global(solid.map_to_local(cell))

func block_at(cell: Vector2i) -> int:
 if solid.get_cell_source_id(cell) == -1:
  return -1
 var atlas := solid.get_cell_atlas_coords(cell)
 for id in Blocks.DEFINITIONS:
  if Blocks.DEFINITIONS[id].atlas == atlas:
   return id
 return -1

func interaction_status(actor: CharacterBody2D, cell: Vector2i, placing: bool, bodies: Array) -> String:
 if cell.x < 0 or cell.x >= world_width or cell.y < 0 or cell.y >= world_depth:
  return "За границей мира"
 if actor.global_position.distance_to(cell_center(cell)) > REACH:
  return "Слишком далеко"
 if not placing:
  return "Можно добыть" if block_at(cell) != -1 else "Пустая клетка"
 if block_at(cell) != -1:
  return "Клетка занята"
 var area := Rect2(cell_center(cell) - Vector2(8, 8), Vector2(16, 16))
 for body in bodies:
  var collider: CollisionShape2D = body.get_node("Collision")
  var body_area: Rect2 = collider.global_transform * collider.shape.get_rect()
  if area.intersects(body_area):
   return "Мешает персонаж"
 # Blocks must attach to terrain or an existing background wall.
 var anchored := walls.get_cell_source_id(cell) != -1
 for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
  if block_at(cell + offset) != -1:
   anchored = true
 return "Можно построить" if anchored else "Нет опоры"

func request_edit(actor: CharacterBody2D, cell: Vector2i, block_id: int, bodies: Array) -> bool:
 if block_id != -1 and not Blocks.DEFINITIONS.has(block_id):
  return false
 var expected := "Можно построить" if block_id != -1 else "Можно добыть"
 if interaction_status(actor, cell, block_id != -1, bodies) != expected:
  return false
 if block_id == -1:
  solid.erase_cell(cell)
 else:
  solid.set_cell(cell, 0, Blocks.DEFINITIONS[block_id].atlas)
 changes[cell] = block_id
 return true
