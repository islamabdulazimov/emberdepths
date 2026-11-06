extends RefCounted
const Rules = preload("res://data/combat_rules.gd")
var max_health := Rules.MAX_HEALTH
var health := Rules.MAX_HEALTH
var max_mana := Rules.MAX_MANA
var mana := Rules.MAX_MANA

func spend_mana(amount: int) -> bool:
 if amount < 0 or mana < amount: return false
 mana -= amount
 return true

func restore_mana(amount: int) -> int:
 var restored := mini(maxi(amount, 0), max_mana - mana)
 mana += restored
 return restored

func heal(amount: int) -> int:
 var restored := mini(maxi(amount, 0), max_health - health)
 health += restored
 return restored

func reset_full() -> void:
 health = max_health
 mana = max_mana

func apply(data: Dictionary) -> void:
 # Legacy stamina fields are deliberately ignored, never re-emitted.
 max_health = int(data.get("max_health", Rules.MAX_HEALTH))
 max_mana = int(data.get("max_mana", Rules.MAX_MANA))
 health = int(data.health)
 mana = int(data.get("mana", max_mana))

func snapshot() -> Dictionary:
 return {"health": health, "max_health": max_health, "mana": mana, "max_mana": max_mana}
