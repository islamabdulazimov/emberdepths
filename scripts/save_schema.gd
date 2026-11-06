extends RefCounted
const Items = preload("res://data/items.gd")
const Blocks = preload("res://data/blocks.gd")
const Rules = preload("res://data/combat_rules.gd")
const Trees = preload("res://data/trees.gd")
const Structures = preload("res://data/structures.gd")

static func integer(value: Variant, low: int, high: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high

static func scalar(value: Variant, low: float, high: float) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func hex_id(value: Variant, size: int) -> bool:
 if not value is String or value.length() != size:
  return false
 for character in value:
  if not character in "0123456789abcdef":
   return false
 return true

static func inventory(value: Variant) -> bool:
 if not value is Array or value.size() != 30:
  return false
 for slot in value:
  if not slot is Dictionary or not slot.has_all(["item", "count"]) or not slot.item is String:
   return false
  if slot.item == "":
   if slot.count != 0:
    return false
  elif not Items.DEFINITIONS.has(slot.item) or not integer(slot.count, 1, Items.stack_limit(slot.item)):
   return false
 return true

static func point(value: Variant, width: int, depth: int) -> bool:
 return value is Vector2 and is_finite(value.x) and is_finite(value.y) and value.x >= -64 and value.x <= width * 16 + 64 and value.y >= -128 and value.y <= depth * 16 + 128

static func velocity(value: Variant) -> bool:
 return value is Vector2 and is_finite(value.x) and is_finite(value.y) and absf(value.x) <= 2000 and absf(value.y) <= 2000

static func cell(value: Variant, width: int, depth: int) -> bool:
 return value is Vector2i and value.x >= 0 and value.x < width and value.y >= 0 and value.y < depth

static func life(value: Variant, width: int, depth: int) -> bool:
 if not value is Dictionary or not value.has_all(["health", "dead", "unclothed", "immunity", "respawn", "position", "velocity", "revision", "last_chest", "since_hurt", "regen_fraction", "knockback", "profile"]):
  return false
 if not scalar(value.get("roll_cooldown",0),0,preload("res://data/battle.gd").ROLL.cooldown) or not scalar(value.get("guard_cooldown",0),0,preload("res://data/equipment.gd").SHIELD.recovery):return false
 if value.has("equipment") and not preload("res://data/equipment.gd").valid(value.equipment):return false
 if value.has("appearance") and not preload("res://data/appearance.gd").valid(value.appearance): return false
 if not integer(value.get("max_health", 100), 1, 1000000) or not integer(value.health, 0, int(value.get("max_health", 100))) or not value.dead is bool or not value.unclothed is bool or value.dead != (value.health == 0):
  return false
 if not integer(value.get("max_mana", 50), 1, 1000000) or not integer(value.get("mana", value.get("max_mana", 50)), 0, int(value.get("max_mana", 50))):
  return false
 if not scalar(value.get("max_stamina", 100.0), 1, 1000000) or not scalar(value.get("stamina", value.get("max_stamina", 100.0)), 0, float(value.get("max_stamina", 100.0))) or not scalar(value.get("stamina_delay", 0.0), 0, 10):
  return false
 if not scalar(value.get("medicine_cooldown",0),0,60) or not scalar(value.get("medicine_progress",0),0,1):
  return false
 if not scalar(value.immunity, 0, 10) or not scalar(value.respawn, -1, 10) or not integer(value.revision, 0, 1000000000):
  return false
 if not point(value.position, width, depth) or not velocity(value.velocity) or not point(value.last_chest, width, depth):
  return false
 return scalar(value.since_hurt, 0, 1e12) and scalar(value.regen_fraction, 0, 1) and scalar(value.knockback, 0, 2) and hex_id(value.profile, 32)

static func validate(value: Variant) -> String:
 if not value is Dictionary or not value.has_all(["format", "generator", "host_profile", "world", "profiles", "drops", "combat", "next_drop"]):
  return "Неполное сохранение"
 if not integer(value.get("combat_rules",1),1,2):return "Неподдерживаемые правила боя"
 if value.format != 1 or value.generator not in [1,2,3]:
  return "Неподдерживаемая версия сохранения или генератора"
 var world: Variant = value.world
 if not world is Dictionary or not world.has_all(["seed", "width", "depth", "blocks", "walls", "torches"]):
  return "Неполный мир"
 if not integer(world.seed, -2147483648, 2147483647) or not integer(world.width, 32, 1024) or not integer(world.depth, 32, 256):
  return "Неверные параметры мира"
 if not world.get("sites",{}) is Dictionary or world.get("sites",{}).size() > 16: return "Неверное состояние руин"
 for site_id in world.get("sites",{}):
  var progress: Variant = world.sites[site_id]
  if not site_id is String or site_id.length() > 64 or not progress is Dictionary or not progress.has_all(["initialized","guards"]) or not progress.initialized is bool or not integer(progress.guards,0,255): return "Неверный прогресс руин"
 if not world.get("storage",{}) is Dictionary: return "Неверные сундуки хранения"
 if not world.get("storage_opened",[]) is Array or world.get("storage_opened",[]).size() > 128: return "Неверные открытые сундуки"
 for anchor in world.get("storage_opened",[]):
  if not anchor is Vector2i or not world.get("storage",{}).has(anchor): return "Открытый сундук отсутствует"
 if int(value.generator) == 2 and (int(world.width) != 384 or int(world.depth) != 160): return "Неверный размер мира генератора 2"
 if int(value.generator) == 3 and Vector2i(world.width,world.depth) not in [Vector2i(512,192),Vector2i(896,256)]: return "Неверный размер нового мира"
 if not world.get("npcs",{}) is Dictionary or world.get("npcs",{}).size()>2:return "Неверные жители"
 for id in world.get("npcs",{}):
  var resident:Variant=world.npcs[id]
  if not preload("res://data/residents.gd").DEFINITIONS.has(id) or not resident is Dictionary or resident.get("id")!=id or not point(resident.get("position"),int(world.width),int(world.depth)) or not point(resident.get("home"),int(world.width),int(world.depth)) or not resident.get("site") is String:return "Неверный житель"
 var width := int(world.width)
 var depth := int(world.depth)
 if not world.blocks is Dictionary or not world.walls is Dictionary or not world.torches is Array or world.blocks.size() > width * depth or world.walls.size() > width * depth or world.torches.size() > 2048:
  return "Слишком большой или неверный журнал мира"
 for position in world.blocks:
  if not cell(position, width, depth) or not integer(world.blocks[position], -1, 2147483647) or (world.blocks[position] != -1 and not Blocks.DEFINITIONS.has(world.blocks[position])):
   return "Неверный блок в журнале"
 for position in world.walls:
  if not cell(position, width, depth) or not integer(world.walls[position], -1, 2147483647) or (world.walls[position] != -1 and not Blocks.WALLS.has(world.walls[position])):
   return "Неверная стена в журнале"
 var torch_cells: Dictionary = {}
 for position in world.torches:
  if not cell(position, width, depth) or torch_cells.has(position):
   return "Неверный факел в журнале"
  torch_cells[position] = true
 var door_occupied: Dictionary = {}
 if world.has("doors"):
  if not world.doors is Dictionary or world.doors.size() > Structures.MAX_DOORS:
   return "Неверный список дверей"
  for anchor in world.doors:
   if not cell(anchor,width,depth) or anchor.y < Structures.DOOR_HEIGHT-1 or anchor.y >= depth-1 or not world.doors[anchor] is bool:
    return "Неверная дверь"
   if world.blocks.get(anchor+Vector2i.DOWN,0) == -1: return "Дверь без опоры"
   for part in Structures.door_cells(anchor):
    if door_occupied.has(part) or torch_cells.has(part) or world.blocks.get(part,-1) != -1: return "Дверь пересекает постройку"
    door_occupied[part] = true
 if world.has("storage"):
  if not world.storage is Dictionary or world.storage.size() > Structures.MAX_CHESTS: return "Неверный список сундуков"
  var storage_cells: Dictionary = {}
  for anchor in world.storage:
   if not cell(anchor,width,depth) or anchor.x+Structures.CHEST_WIDTH > width or anchor.y >= depth-1 or not inventory(world.storage[anchor]): return "Неверный сундук хранения"
   for part in Structures.chest_cells(anchor):
    if storage_cells.has(part) or door_occupied.has(part) or torch_cells.has(part) or world.blocks.get(part,-1) != -1 or world.blocks.get(part+Vector2i.DOWN,0) == -1:
     return "Сундук пересекает постройку или не имеет опоры"
    storage_cells[part] = true
 if world.has("trees"):
  if not world.trees is Array or world.trees.size() > width:
   return "Неверный список деревьев"
  var tree_columns: Dictionary = {}
  for tree in world.trees:
   if not tree is Dictionary or not tree.has_all(["cell", "height", "form", "seed", "active"]):
    return "Неполное дерево"
   if not cell(tree.cell, width, depth) or not integer(tree.height, Trees.MIN_HEIGHT, Trees.MAX_HEIGHT) or not integer(tree.form, 0, Trees.FORMS - 1) or not integer(tree.seed, 0, 2147483647) or not tree.active is bool:
    return "Неверные параметры дерева"
   if tree.cell.y < tree.height + 2 or tree_columns.has(tree.cell.x):
    return "Неверное расположение деревьев"
   tree_columns[tree.cell.x] = true
 if not value.profiles is Dictionary or value.profiles.is_empty() or value.profiles.size() > 64 or not value.profiles.has(value.host_profile):
  return "Неверные персонажи"
 for id in value.profiles:
  var record: Variant = value.profiles[id]
  if not hex_id(id, 32) or not record is Dictionary or not record.has_all(["key_hash", "inventory", "life", "selected"]):
   return "Неверная запись персонажа"
  if not hex_id(record.key_hash, 64) or not inventory(record.inventory) or not life(record.life, width, depth) or record.life.profile != id or not integer(record.selected, 0, 9):
   return "Неверное состояние персонажа"
 if not value.drops is Dictionary or value.drops.size() > 4096 or not integer(value.next_drop, 1, 1000000000):
  return "Неверные выпавшие предметы"
 for id in value.drops:
  var drop: Variant = value.drops[id]
  if not integer(id, 1, int(value.next_drop) - 1) or not drop is Dictionary or not drop.has_all(["item", "count", "position", "velocity", "age"]):
   return "Неполный выпавший предмет"
  if not Items.DEFINITIONS.has(drop.item) or not integer(drop.count, 1, Items.stack_limit(drop.item)) or not point(drop.position, width, depth) or not velocity(drop.velocity) or not scalar(drop.age, 0, 1e12):
   return "Неверный выпавший предмет"
 var combat: Variant = value.combat
 if not combat is Dictionary or not combat.has_all(["time", "entities", "chests", "players", "spawn_timer", "spawn_sequence", "next_entity", "next_chest"]):
  return "Неполное состояние опасностей"
 if not scalar(combat.time, 0, 1e12) or not scalar(combat.spawn_timer, -1, 60) or not integer(combat.spawn_sequence, 0, 1000000000) or not integer(combat.next_entity, 1, 1000000000) or not integer(combat.next_chest, 1, 1000000000):
  return "Неверные часы или спавн"
 if not combat.entities is Dictionary or combat.entities.size() > 256 or not combat.chests is Dictionary or combat.chests.size() > 512 or not combat.players is Dictionary or not combat.players.is_empty():
  return "Неверные существа или сундуки"
 for id in combat.entities:
  var entity: Variant = combat.entities[id]
  if not integer(id, 1, int(combat.next_entity) - 1) or not entity is Dictionary or not entity.has_all(["kind", "position", "velocity", "health", "anchor", "grace", "clock", "hit_stun"]):
   return "Неполное существо"
  if not Rules.ENEMIES.has(entity.kind):
   return "Неизвестное существо"
  if not entity.get("site_guard",false) is bool: return "Неверный страж руин"
  var raw_base: Variant = entity.get("base_health", Rules.ENEMIES[entity.kind].health)
  var raw_players: Variant = entity.get("scaling_players", 1)
  var raw_maximum: Variant = entity.get("max_health", raw_base)
  if not integer(raw_base, 1, 1000000) or not integer(raw_players, 1, 4) or not integer(raw_maximum, 1, 2000000):
   return "Неверные параметры масштабирования"
  var base := int(raw_base)
  var players := int(raw_players)
  var maximum := int(raw_maximum)
  if base != Rules.ENEMIES[entity.kind].health or not integer(players, 1, 4) or maximum != Rules.scaled_health(base, players):
   return "Неверное масштабирование здоровья"
  if not integer(entity.health, 1, maximum) or not point(entity.position, width, depth) or not point(entity.anchor, width, depth) or not velocity(entity.velocity) or not scalar(entity.grace, 0, 2) or not scalar(entity.clock, 0, 1e12) or not scalar(entity.hit_stun, 0, 1):
   return "Неверное существо"
  if entity.kind == "spirit" and entity.position.distance_to(entity.anchor) > 160.1:
   return "Дух вне радиуса сундука"
 for id in combat.chests:
  var chest: Variant = combat.chests[id]
  if not integer(id, 1, int(combat.next_chest) - 1) or not chest is Dictionary or not chest.has_all(["position", "owner", "profile", "contents"]):
   return "Неполный сундук"
  if not preload("res://data/equipment.gd").valid(chest.get("equipment",{})):return "Неверное снаряжение в сундуке смерти"
  if not point(chest.position, width, depth) or not integer(chest.owner, 1, 2147483647) or not hex_id(chest.profile, 32) or not inventory(chest.contents):
   return "Неверный сундук"
 return ""
