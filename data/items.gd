extends RefCounted
# Item IDs are independent of terrain IDs; tools and recipes can extend this table.
const STACK_LIMIT := 99
const DEFINITIONS := {
 "dirt": {"name": "Земля", "block": 1, "atlas": Vector2i(1, 0)},
 "stone": {"name": "Камень", "block": 2, "atlas": Vector2i(2, 0)},
 "turf": {"name": "Дёрн", "block": 0, "atlas": Vector2i(0, 0)},
}
