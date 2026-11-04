extends RefCounted
const DOOR_HEIGHT := 3
const MAX_DOORS := 512
const DOOR_REMOVE_TIME := 0.8
const DOOR_TOGGLE_DELAY := 0.25

static func door_cells(anchor: Vector2i) -> Array[Vector2i]:
 var cells: Array[Vector2i] = []
 for offset in range(DOOR_HEIGHT): cells.append(anchor + Vector2i(0,-offset))
 return cells
