extends RefCounted
const SLOTS := ["weapon","head","body","legs","shield","ability"]
const LABELS := {"weapon":"Оружие","head":"Шлем","body":"Доспех","legs":"Поножи","shield":"Щит","ability":"Способность"}
const SHIELD := {"hold_seconds":1.2,"recovery":0.45,"move_scale":0.35}
static func empty() -> Dictionary:return {"weapon":"","head":"","body":"","legs":"","shield":"","ability":""}
static func valid(value: Variant) -> bool:
 if not value is Dictionary or value.size()>SLOTS.size():return false
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
