extends RefCounted
const Rules = preload("res://data/combat_rules.gd")
var max_health := Rules.MAX_HEALTH
var health := Rules.MAX_HEALTH
var max_mana := Rules.MAX_MANA
var mana := Rules.MAX_MANA
var max_stamina := Rules.MAX_STAMINA
var stamina := Rules.MAX_STAMINA
var recovery_delay := 0.0
var continuous_uses: Dictionary = {}

func spend_stamina(amount: float) -> bool:
 if not is_finite(amount) or amount < 0 or stamina < amount:
  return false
 stamina -= amount
 recovery_delay = Rules.STAMINA_REGEN_DELAY
 return true

func spend_mana(amount: int) -> bool:
 if amount < 0 or mana < amount:
  return false
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

func set_continuous_use(action: String, active: bool) -> void:
 if active: continuous_uses[action] = true
 else: continuous_uses.erase(action)

func tick(delta: float) -> bool:
 if not continuous_uses.is_empty():
  return false
 var available := maxf(0.0, delta - recovery_delay)
 recovery_delay = maxf(0.0, recovery_delay - delta)
 var before := stamina
 stamina = minf(max_stamina, stamina + Rules.STAMINA_REGEN_RATE * available)
 return stamina != before

func reset_full() -> void:
 health = max_health
 mana = max_mana
 stamina = max_stamina
 recovery_delay = 0
 continuous_uses.clear()

func apply(data: Dictionary) -> void:
 max_health = int(data.get("max_health", Rules.MAX_HEALTH))
 max_mana = int(data.get("max_mana", Rules.MAX_MANA))
 max_stamina = float(data.get("max_stamina", Rules.MAX_STAMINA))
 health = int(data.health)
 mana = int(data.get("mana", max_mana))
 stamina = float(data.get("stamina", max_stamina))
 recovery_delay = float(data.get("stamina_delay", 0))
 continuous_uses.clear()

func snapshot() -> Dictionary:
 return {"health": health, "max_health": max_health, "mana": mana, "max_mana": max_mana, "stamina": stamina, "max_stamina": max_stamina, "stamina_delay": recovery_delay}
