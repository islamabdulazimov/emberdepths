extends RefCounted
# Stable IDs are reserved for future inventory and world save data.
const SIZE := 16
const GRASS := 0
const DIRT := 1
const STONE := 2
const EMBERSTONE := 3
const WOOD := 4
const TEXTURES := {0: preload("res://assets/terrain.svg"), 1: preload("res://assets/icons/emberstone.svg"), 2: preload("res://assets/icons/planks.svg"),3: preload("res://assets/icons/rootwood.svg")}
const WALLS := {
 4: {"item":"wood_wall","source":3,"atlas":Vector2i.ZERO},
 1: {"item": "dirt_wall", "source": 0, "atlas": Vector2i(1,0)},
 2: {"item": "stone_wall", "source": 0, "atlas": Vector2i(2,0)},
 3: {"item": "wood_wall", "source": 2, "atlas": Vector2i(0,0)},
}
const DEFINITIONS := {
 5: {"name":"Древние корни","drop_item":"wood","mine_time":0.65,"source":3,"atlas":Vector2i.ZERO},
 GRASS: {"name": "Дёрн", "drop_item": "turf", "mine_time": 0.3, "atlas": Vector2i(0, 0)},
 DIRT: {"name": "Земля", "drop_item": "dirt", "mine_time": 0.35, "atlas": Vector2i(1, 0)},
 STONE: {"name": "Камень", "drop_item": "stone", "mine_time": 0.65, "atlas": Vector2i(2, 0)},
 EMBERSTONE: {"name": "Искрокамень", "drop_item": "emberstone", "mine_time": 0.8, "source": 1, "atlas": Vector2i(0, 0)},
 WOOD: {"name": "Доски", "drop_item": "wood_block", "mine_time": 0.4, "source": 2, "atlas": Vector2i(0, 0)},
}
