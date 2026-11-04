extends RefCounted
# Stable IDs are reserved for future inventory and world save data.
const SIZE := 16
const GRASS := 0
const DIRT := 1
const STONE := 2
const DEFINITIONS := {
 GRASS: {"name": "Дёрн", "atlas": Vector2i(0, 0)},
 DIRT: {"name": "Земля", "atlas": Vector2i(1, 0)},
 STONE: {"name": "Камень", "atlas": Vector2i(2, 0)},
}
