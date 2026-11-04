extends Node2D
const Blocks = preload("res://data/blocks.gd")
@export var world_seed: int = 72419
@export var world_width: int = 192
@export var world_depth: int = 72
var solid: TileMapLayer
var walls: TileMapLayer
var wall_changes: Dictionary = {}
var torches: Dictionary = {}
const Torch = preload("res://scripts/torch.gd")
var heights: PackedInt32Array = []

func _ready() -> void:
 generate()

func generate() -> void:
 heights.clear()
 changes.clear()
 wall_changes.clear()
 for cell in torches.keys():
  apply_decoration("torch", cell, -1)
 if is_instance_valid(solid):
  remove_child(solid)
  solid.queue_free()
 if is_instance_valid(walls):
  remove_child(walls)
  walls.queue_free()
 var tiles := TileSet.new()
 tiles.tile_size = Vector2i(16, 16)
 tiles.add_physics_layer()
 tiles.set_physics_layer_collision_layer(0, 1)
 for source_id in [0, 1]:
  var atlas := TileSetAtlasSource.new()
  atlas.texture = preload("res://assets/terrain.png") if source_id == 0 else preload("res://assets/icons/emberstone.svg")
  atlas.texture_region_size = Vector2i(16, 16)
  tiles.add_source(atlas, source_id)
  for id in Blocks.DEFINITIONS:
   var definition: Dictionary = Blocks.DEFINITIONS[id]
   if int(definition.get("source", 0)) != source_id:
    continue
   var cell: Vector2i = definition.atlas
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
   # Small fuel deposits reachable during the first descent.
   if y >= top + 3 and y < world_depth - 2 and posmod(x * 31 + y * 17 + world_seed, 47) < 3:
    id = Blocks.EMBERSTONE
   if x == world_width / 2 + 3 and y in [25, 26]:
    id = Blocks.EMBERSTONE
   walls.set_cell(Vector2i(x, y), 0, Vector2i(2, 0))
   var is_cave := y > top + 7 and y < world_depth - 2 and absf(caves.get_noise_2d(x, y)) < 0.105
   if not is_cave:
    solid.set_cell(Vector2i(x, y), int(Blocks.DEFINITIONS[id].get("source", 0)), Blocks.DEFINITIONS[id].atlas)
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
  if Blocks.DEFINITIONS[id].atlas == atlas and int(Blocks.DEFINITIONS[id].get("source", 0)) == solid.get_cell_source_id(cell):
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
 apply_edit(cell, block_id)
 return true

# Trusted replication/snapshot path; clients never invoke it on the host via RPC.
func apply_edit(cell: Vector2i, block_id: int) -> void:
 if block_id == -1:
  solid.erase_cell(cell)
 else:
  solid.set_cell(cell, int(Blocks.DEFINITIONS[block_id].get("source", 0)), Blocks.DEFINITIONS[block_id].atlas)
 changes[cell] = block_id


func in_reach(actor: CharacterBody2D, cell: Vector2i) -> bool:
 return cell.x >= 0 and cell.x < world_width and cell.y >= 0 and cell.y < world_depth and actor.global_position.distance_to(cell_center(cell)) <= REACH

func wall_at(cell: Vector2i) -> int:
 return -1 if walls.get_cell_source_id(cell) == -1 else walls.get_cell_atlas_coords(cell).x

func has_support(cell: Vector2i) -> bool:
 if wall_at(cell) != -1:
  return true
 for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
  if block_at(cell + offset) != -1:
   return true
 return false

func decoration_status(actor: CharacterBody2D, cell: Vector2i, kind: String, placing: bool) -> String:
 if not in_reach(actor, cell):
  return "Вне досягаемости"
 if kind == "torch":
  if not placing:
   return "Можно снять факел" if torches.has(cell) else "Здесь нет факела"
  if torches.has(cell):
   return "Факел уже установлен"
  if block_at(cell) != -1:
   return "Клетка занята"
  return "Можно поставить факел" if has_support(cell) else "Нет опоры"
 if kind == "wall":
  if not placing:
   if block_at(cell) != -1:
    return "Сначала убери твёрдый блок"
   return "Можно снять стену" if wall_at(cell) != -1 else "Здесь нет стены"
  if wall_at(cell) != -1:
   return "Стена уже есть"
  var anchored := block_at(cell) != -1 or has_support(cell)
  for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
   if wall_at(cell + offset) != -1:
    anchored = true
  return "Можно поставить стену" if anchored else "Нет опоры"
 return "Неизвестный слой"

func apply_decoration(kind: String, cell: Vector2i, value: int) -> void:
 if kind == "wall":
  if value == -1:
   walls.erase_cell(cell)
  else:
   walls.set_cell(cell, 0, Vector2i(value, 0))
  wall_changes[cell] = value
 elif kind == "torch":
  if value == -1 and torches.has(cell):
   remove_child(torches[cell])
   torches[cell].queue_free()
   torches.erase(cell)
  elif value != -1 and not torches.has(cell):
   var torch := Node2D.new()
   torch.set_script(Torch)
   torch.position = to_local(cell_center(cell))
   add_child(torch)
   torches[cell] = torch


func safe_spawn_position() -> Vector2:
 var center := world_width / 2
 for distance in range(24):
  for sign_value in [1, -1]:
   var column: int = center + distance * sign_value
   if column < 0 or column >= world_width:
    continue
   for floor_y in range(2, world_depth):
    if block_at(Vector2i(column, floor_y)) != -1 and block_at(Vector2i(column, floor_y - 1)) == -1 and block_at(Vector2i(column, floor_y - 2)) == -1:
     return Vector2(column * 16 + 8, floor_y * 16 - 10)
 return Vector2(world_width * 8, -32)
