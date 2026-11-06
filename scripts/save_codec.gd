extends RefCounted
# JSON encodes only data, never Godot Objects, scripts or resource paths.
var error := ""
var nodes := 0

func encode(value: Variant) -> Variant:
 if value is float:
  return {"real": value}
 if value is Vector2:
  return {"v2": [value.x, value.y]}
 if value is Vector2i:
  return {"cell": [value.x, value.y]}
 if value is Dictionary:
  var entries: Array = []
  for key in value:
   entries.append([encode(key), encode(value[key])])
  return {"map": entries}
 if value is Array:
  var result: Array = []
  for item in value:
   result.append(encode(item))
  return result
 return value

func decode(value: Variant, depth: int = 0) -> Variant:
 nodes += 1
 if depth > 24 or nodes > 4000000:
  error = "Слишком сложное сохранение"
  return null
 if value is Dictionary:
  if value.size() != 1:
   error = "Неверный тип данных"
   return null
  if value.has("real"):
   if not number(value.real):
    error = "Неверное вещественное число"
    return null
   return float(value.real)
  if value.has("v2") or value.has("cell"):
   var raw: Variant = value.get("v2", value.get("cell"))
   if not raw is Array or raw.size() != 2 or not number(raw[0]) or not number(raw[1]):
    error = "Неверные координаты"
    return null
   if value.has("cell"):
    if raw[0] != floor(raw[0]) or raw[1] != floor(raw[1]) or absf(raw[0]) > 100000 or absf(raw[1]) > 100000:
     error = "Неверная клетка"
     return null
    return Vector2i(int(raw[0]), int(raw[1]))
   return Vector2(float(raw[0]), float(raw[1]))
  if not value.has("map") or not value.map is Array:
   error = "Неизвестный тип данных"
   return null
  var result: Dictionary = {}
  for entry in value.map:
   if not entry is Array or entry.size() != 2:
    error = "Неверная запись"
    return null
   var key: Variant = decode(entry[0], depth + 1)
   if not (key is String or key is int or key is Vector2i) or result.has(key):
    error = "Неверный или повторный ключ"
    return null
   result[key] = decode(entry[1], depth + 1)
  return result
 if value is Array:
  var result: Array = []
  for item in value:
   result.append(decode(item, depth + 1))
  return result
 if value is float:
  if not is_finite(value) or absf(value) > 1e12:
   error = "Неверное число"
   return null
  return int(value) if value == floor(value) else value
 if value is String or value is int or value is bool or value == null:
  return value
 error = "Недопустимые данные"
 return null

static func number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 1e12
