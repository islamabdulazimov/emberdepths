extends RefCounted
# One provisional difficulty. No hunger, thirst or selectable modes.
const MAX_HEALTH := 100
const HURT_IMMUNITY := 0.9
const RESPAWN_DELAY := 1.8
const RESPAWN_IMMUNITY := 3.0
const REGEN_DELAY := 12.0
const REGEN_RATE := 3.0
const DAY_SECONDS := 180.0
const NIGHT_SECONDS := 60.0
const CYCLE_SECONDS := DAY_SECONDS + NIGHT_SECONDS
const SPIRIT_RADIUS := 160.0
const ENEMIES := {
 "ashling": {"name": "Пепельник", "health": 45, "day_speed": 34.0, "night_speed": 65.0, "day_damage": 14, "night_damage": 22, "loot": "emberstone"},
 "spirit": {"name": "Дух сундука", "health": 2, "day_speed": 70.0, "night_speed": 70.0, "day_damage": 12, "night_damage": 12, "loot": ""},
}
