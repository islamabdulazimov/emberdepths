extends RefCounted
const Items = preload("res://data/items.gd")
const SLOT_COUNT := 30
const HOTBAR_COUNT := 10
var slots: Array = []

func _init() -> void:
 for i in range(SLOT_COUNT):
  slots.append({"item": "", "count": 0})

func add(item_id: String, amount: int) -> int:
 if not Items.DEFINITIONS.has(item_id) or amount <= 0:
  return amount
 var remaining := amount
 # Fill existing stacks before occupying an empty slot.
 for empty_pass in [false, true]:
  for slot in slots:
   if (slot.item == "" if empty_pass else slot.item == item_id):
    var accepted := mini(remaining, Items.STACK_LIMIT - int(slot.count))
    if accepted > 0:
     slot.item = item_id
     slot.count += accepted
     remaining -= accepted
    if remaining == 0:
     return 0
 return remaining

func block_in_slot(index: int) -> int:
 if index < 0 or index >= SLOT_COUNT:
  return -1
 var slot: Dictionary = slots[index]
 if slot.count <= 0 or not Items.DEFINITIONS.has(slot.item):
  return -1
 return int(Items.DEFINITIONS[slot.item].get("block", -1))

func take_one(index: int) -> bool:
 if index < 0 or index >= SLOT_COUNT or slots[index].count <= 0:
  return false
 slots[index].count -= 1
 if slots[index].count == 0:
  slots[index].item = ""
 return true

func transfer(source: int, destination: int) -> bool:
 if source < 0 or source >= SLOT_COUNT or destination < 0 or destination >= SLOT_COUNT or source == destination:
  return false
 var a: Dictionary = slots[source]
 var b: Dictionary = slots[destination]
 if a.count <= 0:
  return false
 if a.item == b.item:
  var moved := mini(int(a.count), Items.STACK_LIMIT - int(b.count))
  if moved <= 0:
   return false
  a.count -= moved
  b.count += moved
  if a.count == 0:
   a.item = ""
 else:
  slots[source] = b
  slots[destination] = a
 return true

func to_data() -> Array:
 return slots.duplicate(true)

func load_data(data: Array) -> void:
 for i in range(SLOT_COUNT):
  slots[i] = {"item": "", "count": 0}
  if i < data.size() and data[i] is Dictionary:
   var item_id := str(data[i].get("item", ""))
   var amount := clampi(int(data[i].get("count", 0)), 0, Items.STACK_LIMIT)
   if Items.DEFINITIONS.has(item_id) and amount > 0:
    slots[i] = {"item": item_id, "count": amount}
