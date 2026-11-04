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
