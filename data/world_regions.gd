extends RefCounted
const WIDTH := 384
const DEPTH := 160
const NAMES := {"surface":"Поверхность","roots":"Корневые пещеры","deep":"Глубокие полости"}
const AMBIENT := {"roots":Color("40564b"),"deep":Color("223043")}
const SAFE_RADIUS := 320.0
const ACTIVE_RADIUS := 640.0
const MAX_ENEMIES := 12
static func at(world: Node2D, cell: Vector2i) -> String:
 var top: int = world.heights[clampi(cell.x,0,world.world_width-1)] if not world.heights.is_empty() else 22
 return "surface" if cell.y < top+7 else ("roots" if cell.y < deep_start(world) else "deep")
static func safe(world: Node2D, at_position: Vector2) -> bool:
 return at_position.distance_to(world.spawn_position()) < SAFE_RADIUS

static func deep_start(world: Node2D) -> int:
 return world.world_depth/2 if world.generator_version >= 3 else 84
