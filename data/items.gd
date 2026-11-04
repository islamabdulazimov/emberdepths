extends RefCounted
# Item IDs are independent of terrain IDs; recipes live in recipes.gd.
const STACK_LIMIT := 99
const DEFINITIONS := {
 "dirt": {"name": "Земля", "kind": "solid", "block": 1, "atlas": Vector2i(1, 0)},
 "stone": {"name": "Камень", "kind": "solid", "block": 2, "atlas": Vector2i(2, 0)},
 "turf": {"name": "Дёрн", "kind": "solid", "block": 0, "atlas": Vector2i(0, 0)},
 "emberstone": {"name": "Искрокамень", "kind": "solid", "block": 3, "icon": "res://assets/icons/emberstone.svg"},
 "stone_pick": {"name": "Каменная кирка", "kind": "tool", "stack": 1, "mine_factor": 0.5, "icon": "res://assets/icons/pick.svg"},
 "stone_axe": {"name": "Каменный топор", "kind": "axe", "stack": 1, "chop_time": 1.6, "icon": "res://assets/icons/axe.svg"},
 "wood": {"name": "Древесина", "kind": "material", "icon": "res://assets/icons/wood.svg"},
 "wood_block": {"name": "Доски", "kind": "solid", "block": 4, "icon": "res://assets/icons/planks.svg"},
 "spark_balm": {"name": "Искровой бальзам", "kind": "consumable", "stack": 20, "heal": 30, "use_time": 1.0, "cooldown": 6.0, "interrupt_delay": 0.6, "icon": "res://assets/icons/balm.svg"},
 "stone_blade": {"name": "Каменный клинок", "kind": "weapon", "stack": 1, "swing_time": 0.45, "stamina_cost": 18.0, "damage": 18, "poise_damage": 18, "reach": 32.0, "icon": "res://assets/icons/blade.svg"},
 "torch": {"name": "Искровой факел", "kind": "torch", "icon": "res://assets/icons/torch.svg"},
 "dirt_wall": {"name": "Земляная стена", "kind": "wall", "wall": 1, "icon": "res://assets/icons/dirt_wall.svg"},
 "stone_wall": {"name": "Каменная стена", "kind": "wall", "wall": 2, "icon": "res://assets/icons/stone_wall.svg"},
}
static var icon_cache: Dictionary = {}

static func stack_limit(item_id: String) -> int:
 return int(DEFINITIONS.get(item_id, {}).get("stack", STACK_LIMIT))

static func icon(item_id: String) -> Texture2D:
 if not DEFINITIONS.has(item_id):
  return null
 if not icon_cache.has(item_id):
  var definition: Dictionary = DEFINITIONS[item_id]
  if definition.has("icon"):
   icon_cache[item_id] = load(definition.icon)
  else:
   var texture := AtlasTexture.new()
   texture.atlas = preload("res://assets/terrain.png")
   texture.region = Rect2(Vector2(definition.atlas) * 16.0, Vector2(16, 16))
   icon_cache[item_id] = texture
 return icon_cache[item_id]
