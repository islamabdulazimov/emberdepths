extends RefCounted
const SKINS := [Color("f0cdb0"),Color("d5ab8b"),Color("b98165"),Color("825642"),Color("4b332b")]
const DEFAULT := {"gender":"male","hair":"short","skin":1}
static func valid(value: Variant) -> bool:
 return value is Dictionary and value.get("gender","") in ["male","female"] and value.get("hair","") in ["short","long"] and (value.get("skin",-1) is int or value.get("skin",-1) is float) and is_finite(float(value.skin)) and float(value.skin) == floor(float(value.skin)) and value.skin >= 0 and value.skin < SKINS.size()
static func clean(value: Variant) -> Dictionary:
 var result: Dictionary = value.duplicate(true) if valid(value) else DEFAULT.duplicate()
 result.skin = int(result.skin)
 return result
static func color(value: Dictionary) -> Color: return SKINS[int(clean(value).skin)]
static func describe(value: Dictionary) -> String:
 var a := clean(value)
 return ("Женщина" if a.gender == "female" else "Мужчина")+" · "+("длинные" if a.hair == "long" else "короткие")+" волосы · оттенок %d/5" % (a.skin+1)
