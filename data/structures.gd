extends RefCounted
const DOOR_HEIGHT := 3
const MAX_DOORS := 512
const DOOR_REMOVE_TIME := 0.8
const DOOR_TOGGLE_DELAY := 0.25
const CHEST_WIDTH := 2
const MAX_CHESTS := 128
const CHEST_REMOVE_TIME := 0.8

static func chest_cells(anchor: Vector2i) -> Array[Vector2i]:
 var cells: Array[Vector2i] = []
 for offset in range(CHEST_WIDTH): cells.append(anchor + Vector2i(offset,0))
 return cells

static func door_cells(anchor: Vector2i) -> Array[Vector2i]:
 var cells: Array[Vector2i] = []
 for offset in range(DOOR_HEIGHT): cells.append(anchor + Vector2i(0,-offset))
 return cells
