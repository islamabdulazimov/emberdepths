extends RefCounted
const DEFINITIONS := {
 "seamling":{"name":"Шовник","visual_height":30,"health":36,"speed":44.0,"damage":16,"loot":"wood","size":Vector2(16,26),"windup":0.60,"active":0.18,"recovery":0.85,"reach":38.0,"detect":46.0,"dash":130.0},
 "hollowbeak":{"name":"Гулоклюв","visual_height":25,"health":48,"speed":25.0,"damage":18,"loot":"stone","size":Vector2(20,18),"windup":0.90,"active":0.22,"recovery":1.0,"reach":112.0,"detect":116.0,"dash":0.0},
 "ashweaver":{"name":"Пеплопряд","visual_height":17,"health":32,"speed":48.0,"damage":15,"loot":"emberstone","size":Vector2(18,12),"windup":0.65,"active":0.24,"recovery":1.10,"reach":26.0,"detect":144.0,"dash":220.0},
 "void_collector":{"name":"Сборщик пустот","visual_height":30,"health":60,"speed":20.0,"damage":23,"loot":"emberstone","size":Vector2(28,20),"windup":0.95,"active":0.16,"recovery":1.25,"reach":42.0,"detect":48.0,"dash":0.0},
}
static func rules() -> Dictionary:
 var result := {}
 for id in DEFINITIONS:
  var d: Dictionary = DEFINITIONS[id]
  result[id] = {"name":d.name,"health":d.health,"day_speed":d.speed,"night_speed":d.speed,"day_damage":d.damage,"night_damage":d.damage,"loot":d.loot}
 return result
static func definition(kind: String) -> Dictionary: return DEFINITIONS.get(kind,{})
