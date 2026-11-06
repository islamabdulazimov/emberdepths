extends RefCounted
const SLOTS := ["weapon","head","body","legs","shield"]
const LABELS := {"weapon":"Оружие","head":"Шлем","body":"Доспех","legs":"Поножи","shield":"Щит"}
const SHIELD := {"stamina_factor":1.2,"minimum_cost":8.0,"damage_fraction":0.25,"break_recovery":0.65,"move_scale":0.35}
static func empty() -> Dictionary:return {"weapon":"","head":"","body":"","legs":"","shield":""}
static func valid(value: Variant) -> bool:
 if not value is Dictionary or value.size()>5:return false
 for slot in value:
  if slot not in SLOTS or not value[slot] is String:return false
  if value[slot]!="" and preload("res://data/items.gd").DEFINITIONS.get(value[slot],{}).get("equip_slot","")!=slot:return false
 return true
static func clean(value: Variant) -> Dictionary:
 var result:=empty()
 if valid(value):result.merge(value,true)
 return result
static func armor(value: Dictionary) -> int:
 var result:=0
 for slot in ["head","body","legs"]:result+=int(preload("res://data/items.gd").DEFINITIONS.get(value.get(slot,""),{}).get("armor",0))
 return result
