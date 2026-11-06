extends RefCounted
# Item IDs are independent of terrain IDs; recipes live in recipes.gd.
const Battle = preload("res://data/battle.gd")
const STACK_LIMIT := 99
const DEFINITIONS := {
 "dirt": {"name": "Земля", "kind": "solid", "block": 1, "atlas": Vector2i(1, 0)},
 "stone": {"name": "Камень", "kind": "solid", "block": 2, "atlas": Vector2i(2, 0)},
 "turf": {"name": "Дёрн", "kind": "solid", "block": 0, "atlas": Vector2i(0, 0)},
 "emberstone": {"name": "Искрокамень", "kind": "solid", "block": 3, "icon": "res://assets/icons/emberstone.svg"},
 "stone_pick": {"name": "Каменная кирка", "kind": "tool", "stack": 1, "mine_factor": 0.5, "icon": "res://assets/icons/pick.svg"},
 "stone_axe": {"name": "Каменный топор", "kind": "axe", "stack": 1, "chop_time": 1.6, "icon": "res://assets/icons/axe.svg"},
 "wood": {"name": "Древесина", "kind": "material", "icon": "res://assets/icons/wood.svg"},
 "wood_block": {"name": "Доски", "kind": "solid", "block": 4, "icon": "res://assets/icons/planks.svg"},
 "spark_balm": {"name": "Искровой бальзам", "kind": "consumable", "stack": 20, "heal": 30, "use_time": 1.0, "cooldown": preload("res://data/combat_rules.gd").HEALING_COOLDOWN, "interrupt_delay": 0.6, "icon": "res://assets/icons/balm.svg"},
 "stone_blade": {"equip_slot":"weapon","name": "Каменный клинок", "kind": "weapon", "stack": 1, "swing_time": Battle.BLADE.windup+Battle.BLADE.active+Battle.BLADE.recovery, "damage": Battle.BLADE.damage, "poise_damage": Battle.BLADE.poise, "reach": Battle.BLADE.reach, "icon": "res://assets/icons/blade.svg"},
 "torch": {"name": "Искровой факел", "kind": "torch", "icon": "res://assets/icons/torch.svg"},
 "dirt_wall": {"name": "Земляная стена", "kind": "wall", "wall": 1, "icon": "res://assets/icons/dirt_wall.svg"},
 "stone_wall": {"name": "Каменная стена", "kind": "wall", "wall": 2, "icon": "res://assets/icons/stone_wall.svg"},
 "wood_wall": {"name": "Деревянная стена", "kind": "wall", "wall": 3, "icon": "res://assets/icons/wood_wall.svg"},
 "wood_door": {"name": "Деревянная дверь", "kind": "door", "icon": "res://assets/icons/door.svg"},
 "wood_chest": {"name": "Деревянный сундук", "kind": "storage", "icon": "res://assets/icons/chest.svg"},
 "wood_sword":{"name":"Меч из корневой древесины","description":"Простой резной клинок. Лёгкий удар, малая цена ошибки.","kind":"weapon","equip_slot":"weapon","stack":1,"damage":18,"poise_damage":12,"reach":30.0,"swing_time":0.47},
 "wood_shield":{"name":"Щит из корневой древесины","description":"R: короткий фронтальный блок. Часть урона проходит; после блока нужно восстановиться и отпустить R.","kind":"equipment","equip_slot":"shield","stack":1,"block_percent":75},
 "traveler_knot":{"name":"Узел странника","description":"Экипируй в слот способности: Shift даёт перекат. Снятие отключает его; восстановление не сбрасывается.","kind":"equipment","equip_slot":"ability","ability":"roll","stack":1},
 "wood_helm":{"name":"Деревянный шлем","description":"Лёгкие резные пластины сохраняют обзор.","kind":"equipment","equip_slot":"head","stack":1,"armor":1},
 "wood_armor":{"name":"Деревянная кираса","description":"Скреплённая медью кора. Небольшая защита, без штрафа к движению.","kind":"equipment","equip_slot":"body","stack":1,"armor":1},
 "wood_legs":{"name":"Деревянные поножи","description":"Накладки на колени и голени. Не мешают перекату.","kind":"equipment","equip_slot":"legs","stack":1,"armor":1},
}
static var icon_cache: Dictionary = {}

static func stack_limit(item_id: String) -> int:
 return int(DEFINITIONS.get(item_id, {}).get("stack", STACK_LIMIT))

static func description(item_id:String) -> String:
 var definition:Dictionary=DEFINITIONS.get(item_id,{})
 var common:={"solid":"Материал для строительства. ПКМ: поставить блок.","wall":"Фоновая стена. ПКМ: поставить; ЛКМ: снять.","tool":"Кирка для добычи. Скорость добычи ×2.","axe":"Топор. Рубка дерева за 1,6 с.","material":"Древесина для инструментов, экипировки и строительства.","torch":"Свет для поверхности и подземелий.","door":"Проход высотой три блока. ПКМ пустым слотом: открыть.","storage":"Общий сундук на 30 слотов.","consumable":"Лечит 30 ОЗ за 1 с. Получение урона прерывает лечение.","weapon":"Каменный клинок с короткой подготовкой и сильным ударом."}
 return str(definition.get("description",common.get(definition.get("kind",""),"")))
static func stats(item_id:String) -> String:
 var d:Dictionary=DEFINITIONS.get(item_id,{})
 if d.has("damage"):return "Урон %d · стойкость %d · дальность %.1f блока"%[d.damage,d.poise_damage,float(d.reach)/16]
 if d.has("armor"):return "Защита +%d (снижает урон, максимум 35%%)"%d.armor
 if d.has("block_percent"):return "Поглощает %d%% · блок %.2f с · восстановление %.2f с"%[d.block_percent,preload("res://data/equipment.gd").SHIELD.hold_seconds,preload("res://data/equipment.gd").SHIELD.recovery]
 if d.get("ability","")=="roll":return "Перекат · восстановление %.1f с"%Battle.ROLL.cooldown
 return ""
static func icon(item_id: String) -> Texture2D:
 if not DEFINITIONS.has(item_id):return null
 if not icon_cache.has(item_id):icon_cache[item_id]=load("res://assets/recast/item_%s.png"%item_id)
 return icon_cache[item_id]
