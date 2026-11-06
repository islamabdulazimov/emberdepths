extends RefCounted
# Cosmetic only. None of these fields participate in combat or collision logic.
const SKINS := [Color("e2c3a5"),Color("ca9e7e"),Color("ac795c"),Color("77503f"),Color("45302b")]
const BUILDS := ["slim","normal","sturdy"]
const BUILD_NAMES := ["Стройное","Обычное","Крепкое"]
const HAIRS := ["short","short_swept","short_curls","long","long_braid","long_tail"]
const HAIR_NAMES := ["Короткая","Короткая набок","Короткие кудри","Длинные распущенные","Длинная коса","Длинный хвост"]
const HAIR_COLORS := [Color("5b6070"),Color("a87954"),Color("bf7450"),Color("e4c27e"),Color("c1d0ce"),Color("353d4b")]
const HAIR_COLOR_NAMES := ["Тёмные","Каштановые","Медные","Светлые","Серебристые","Чёрные"]
const DEFAULT := {"gender":"male","build":"normal","hair":"short","hair_color":0,"skin":1}
static func index(value:Variant,limit:int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<limit
static func valid(value:Variant) -> bool:
 return value is Dictionary and value.get("gender","") in ["male","female"] and value.get("build","normal") in BUILDS and value.get("hair","") in HAIRS and index(value.get("hair_color",0),HAIR_COLORS.size()) and index(value.get("skin",-1),SKINS.size())
static func clean(value:Variant) -> Dictionary:
 if not valid(value):return DEFAULT.duplicate()
 return {"gender":value.gender,"build":value.get("build","normal"),"hair":value.hair,"hair_color":int(value.get("hair_color",0)),"skin":int(value.skin)}
static func color(value:Dictionary) -> Color:return SKINS[clean(value).skin]
static func describe(value:Dictionary) -> String:
 var a:=clean(value)
 return ("Женщина" if a.gender=="female" else "Мужчина")+" · "+BUILD_NAMES[BUILDS.find(a.build)]+"\n"+HAIR_NAMES[HAIRS.find(a.hair)]+" · "+HAIR_COLOR_NAMES[a.hair_color]+" · кожа %d/5"%(a.skin+1)
