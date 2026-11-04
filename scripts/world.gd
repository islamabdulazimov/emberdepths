extends Node2D
const Blocks = preload("res://data/blocks.gd")
const Structures = preload("res://data/structures.gd")
const Door = preload("res://scripts/door.gd")
var doors: Dictionary = {} # Bottom cell -> StaticBody2D.
var door_cells: Dictionary = {} # All occupied cells -> bottom cell.
@export var world_seed: int = 72419
@export var world_width: int = 192
@export var world_depth: int = 72
var solid: TileMapLayer
var walls: TileMapLayer
var wall_changes: Dictionary = {}
var torches: Dictionary = {}
const Torch = preload("res://scripts/torch.gd")
var heights: PackedInt32Array = []
const Trees = preload("res://data/trees.gd")
var trees: Array = []
var detail: Node2D
var forest: Node2D

func _ready() -> void:
 generate()

func generate() -> void:
 var effects = get_parent().get("effects")
 if is_instance_valid(effects): effects.clear()
 var storage = get_parent().get("storage")
 if is_instance_valid(storage): storage.clear()
 for anchor in doors.keys(): apply_door(anchor,-1)
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
 for source_id in Blocks.TEXTURES:
  var atlas := TileSetAtlasSource.new()
  atlas.texture = Blocks.TEXTURES[source_id]
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
 trees = Trees.generate(self)
 if is_instance_valid(forest): forest.falling.clear()
 if not is_instance_valid(forest):
  forest = Node2D.new()
  forest.name = "Forest"
  forest.set_script(preload("res://scripts/forest.gd"))
  add_child(forest)
 if is_instance_valid(detail): move_child(detail,-1)
 else:
  detail = Node2D.new()
  detail.name = "SurfaceDetails"
  detail.set_script(preload("res://scripts/visuals/world_detail.gd"))
  add_child(detail)

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
 if combat_edit_locked(cell): return "Арена закрыта для строительства и добычи"
 if actor.global_position.distance_to(cell_center(cell)) > REACH:
  return "Слишком далеко"
 if not placing:
  return "Можно добыть" if block_at(cell) != -1 else "Пустая клетка"
 if block_at(cell) != -1:
  return "Клетка занята"
 if door_at(cell) != null: return "Здесь дверной проём"
 if storage_at(cell) != null: return "Здесь сундук"
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
 if block_id == -1:
  for tree in trees:
   if tree.cell == cell: tree.active = false

func tree_snapshot() -> Array:
 return trees.duplicate(true)

func restore_trees(records: Array) -> void:
 if is_instance_valid(forest): forest.falling.clear()
 trees = records.duplicate(true)
 for tree in trees:
  # Never restore a floating tree, including from old terrain-only saves.
  if block_at(tree.cell) == -1: tree.active = false

func tree_at(cell: Vector2i) -> int:
 for index in range(trees.size()):
  var tree: Dictionary = trees[index]
  if tree.active and cell.x == tree.cell.x and cell.y < tree.cell.y and cell.y >= tree.cell.y - tree.height:
   return index
 return -1

# Trusted host/replication boundary. Keep records in place so IDs stay stable.
func fell_tree(index: int, direction: int = 1) -> bool:
 if index < 0 or index >= trees.size() or not trees[index].active: return false
 if is_instance_valid(forest): forest.animate_fall(trees[index], direction)
 trees[index].active = false
 return true


func in_reach(actor: CharacterBody2D, cell: Vector2i) -> bool:
 return cell.x >= 0 and cell.x < world_width and cell.y >= 0 and cell.y < world_depth and actor.global_position.distance_to(cell_center(cell)) <= REACH

func wall_at(cell: Vector2i) -> int:
 var source := walls.get_cell_source_id(cell)
 if source == -1: return -1
 for id in Blocks.WALLS:
  var definition: Dictionary = Blocks.WALLS[id]
  if source == definition.source and walls.get_cell_atlas_coords(cell) == definition.atlas: return id
 return -1

func has_support(cell: Vector2i) -> bool:
 if wall_at(cell) != -1:
  return true
 for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
  if block_at(cell + offset) != -1:
   return true
 return false

func decoration_status(actor: CharacterBody2D, cell: Vector2i, kind: String, placing: bool) -> String:
 if combat_edit_locked(cell): return "Арена закрыта для строительства и добычи"
 if not in_reach(actor, cell):
  return "Вне досягаемости"
 if kind == "torch":
  if not placing:
   return "Можно снять факел" if torches.has(cell) else "Здесь нет факела"
  if torches.has(cell):
   return "Факел уже установлен"
  if door_at(cell) != null: return "Здесь дверной проём"
  if storage_at(cell) != null: return "Здесь сундук"
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
   var definition: Dictionary = Blocks.WALLS[value]
   walls.set_cell(cell,int(definition.source),definition.atlas)
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


func safe_spawn_position(preferred_column: int = -1) -> Vector2:
 var center: int = world_width / 2 if preferred_column < 0 else preferred_column
 for distance in range(24):
  for sign_value in [1, -1]:
   var column: int = center + distance * sign_value
   if column < 0 or column >= world_width:
    continue
   for floor_y in range(2, world_depth):
    if block_at(Vector2i(column, floor_y)) != -1 and block_at(Vector2i(column, floor_y - 1)) == -1 and block_at(Vector2i(column, floor_y - 2)) == -1:
     var at := Vector2(column * 16 + 8, floor_y * 16 - 10)
     if character_fits(at): return at
 return Vector2(world_width * 8, -32)


func character_fits(at: Vector2) -> bool:
 var player_area := Rect2(at + Vector2(-5,-18),Vector2(10,28))
 for anchor in doors:
  if not doors[anchor].opened and door_area(anchor).intersects(player_area): return false
 var top_left := cell_at(at + Vector2(-5, -18))
 var bottom_right := cell_at(at + Vector2(4.99, 9.99))
 for x in range(top_left.x, bottom_right.x + 1):
  for y in range(top_left.y, bottom_right.y + 1):
   if block_at(Vector2i(x, y)) != -1:
    return false
 return at.x >= 5 and at.x <= world_width * 16 - 5 and at.y >= -64 and at.y <= world_depth * 16

func door_at(cell: Vector2i) -> StaticBody2D:
 return doors.get(door_cells.get(cell))

func door_area(anchor: Vector2i) -> Rect2:
 return Rect2(cell_center(anchor) - Vector2(8,8+(Structures.DOOR_HEIGHT-1)*16),Vector2(16,Structures.DOOR_HEIGHT*16))

func area_occupied(area: Rect2, bodies: Array) -> bool:
 for body in bodies:
  if body.get("dead") == true: continue
  for child in body.get_children():
   if child is CollisionShape2D and not child.disabled and child.shape != null:
    if area.intersects(child.global_transform * child.shape.get_rect()): return true
 return false

func door_placement_status(actor: CharacterBody2D, anchor: Vector2i, bodies: Array) -> String:
 for part in Structures.door_cells(anchor):
  if combat_edit_locked(part): return "Арена закрыта для строительства и добычи"
 if doors.size() >= Structures.MAX_DOORS: return "Слишком много дверей"
 if anchor.y < Structures.DOOR_HEIGHT-1 or anchor.y >= world_depth-1 or anchor.x < 0 or anchor.x >= world_width: return "За границей мира"
 for cell in Structures.door_cells(anchor):
  if not in_reach(actor,cell): return "Дверь вне досягаемости"
  if block_at(cell) != -1 or door_at(cell) != null or torches.has(cell) or storage_at(cell) != null: return "Нужен свободный проём 1×3"
 if block_at(anchor+Vector2i.DOWN) == -1: return "Нужен твёрдый пол под дверью"
 if area_occupied(door_area(anchor),bodies): return "В проёме персонаж или противник"
 return "Можно поставить дверь"

func door_snapshot() -> Dictionary:
 var result: Dictionary = {}
 for anchor in doors: result[anchor] = bool(doors[anchor].opened)
 return result

# Trusted snapshot/replication boundary; gameplay validation lives in ItemService.
func apply_door(anchor: Vector2i, value: int) -> void:
 if value == -1:
  if not doors.has(anchor): return
  remove_child(doors[anchor])
  doors[anchor].queue_free()
  doors.erase(anchor)
  for cell in Structures.door_cells(anchor): door_cells.erase(cell)
  return
 if not doors.has(anchor):
  var door := StaticBody2D.new()
  door.set_script(Door)
  door.anchor = anchor
  door.opened = value == 1
  door.position = to_local(cell_center(anchor))
  add_child(door)
  doors[anchor] = door
  for cell in Structures.door_cells(anchor): door_cells[cell] = anchor
 else: doors[anchor].set_open(value == 1)

func restore_doors(data: Dictionary) -> void:
 for anchor in doors.keys(): apply_door(anchor,-1)
 for anchor in data: apply_door(anchor,1 if data[anchor] else 0)

func storage_at(cell: Vector2i) -> Node2D:
 var service = get_parent().get("storage")
 return service.at_cell(cell) if is_instance_valid(service) else null

func combat_edit_locked(cell: Vector2i) -> bool:
 var zone = get_parent().get("combat_zone")
 return is_instance_valid(zone) and zone.blocks_edit(cell)
