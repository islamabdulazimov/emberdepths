extends RefCounted
const Recipes = preload("res://data/recipes.gd")
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
    var accepted := mini(remaining, Items.stack_limit(item_id) - int(slot.count))
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
  var moved := mini(int(a.count), Items.stack_limit(a.item) - int(b.count))
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

# Atomic transfer; items stay at their source until this operation succeeds.
func transfer_to(other: RefCounted, source: int, destination: int) -> bool:
 if other == self: return transfer(source,destination)
 if source < 0 or source >= slots.size() or destination < 0 or destination >= other.slots.size(): return false
 var a: Dictionary = slots[source]
 var b: Dictionary = other.slots[destination]
 if a.count <= 0: return false
 if a.item == b.item:
  var moved := mini(int(a.count),Items.stack_limit(a.item)-int(b.count))
  if moved <= 0: return false
  a.count -= moved
  b.count += moved
  if a.count == 0: a.item = ""
 else:
  slots[source] = b
  other.slots[destination] = a
 return true

func load_data(data: Array) -> void:
 for i in range(SLOT_COUNT):
  slots[i] = {"item": "", "count": 0}
  if i < data.size() and data[i] is Dictionary:
   var item_id := str(data[i].get("item", ""))
   var amount := clampi(int(data[i].get("count", 0)), 0, Items.stack_limit(item_id))
   if Items.DEFINITIONS.has(item_id) and amount > 0:
    slots[i] = {"item": item_id, "count": amount}


func item_at(index: int) -> String:
 if index < 0 or index >= SLOT_COUNT or slots[index].count <= 0:
  return ""
 return str(slots[index].item)

func count_item(item_id: String) -> int:
 var amount := 0
 for slot in slots:
  if slot.item == item_id:
   amount += int(slot.count)
 return amount

func remove_item(item_id: String, amount: int) -> bool:
 if amount <= 0 or count_item(item_id) < amount:
  return false
 var remaining := amount
 for slot in slots:
  if slot.item == item_id:
   var used := mini(remaining, int(slot.count))
   slot.count -= used
   remaining -= used
   if slot.count == 0:
    slot.item = ""
   if remaining == 0:
    break
 return true

func craft_preview(recipe_id: String) -> Dictionary:
 if not Recipes.DEFINITIONS.has(recipe_id):
  return {"status": "Неизвестный рецепт"}
 var recipe: Dictionary = Recipes.DEFINITIONS[recipe_id]
 for item_id in recipe.ingredients:
  if count_item(item_id) < int(recipe.ingredients[item_id]):
   return {"status": "Не хватает: " + Items.DEFINITIONS[item_id].name}
 var trial = get_script().new()
 trial.load_data(to_data())
 for item_id in recipe.ingredients:
  trial.remove_item(item_id, recipe.ingredients[item_id])
 if trial.add(recipe.output, recipe.count) != 0:
  return {"status": "Нет места для результата"}
 return {"status": "Можно создать", "slots": trial.to_data()}

func craft(recipe_id: String) -> bool:
 var preview := craft_preview(recipe_id)
 if preview.status != "Можно создать":
  return false
 load_data(preview.slots)
 return true

# Merge into every suitable destination, then empty slots; no swaps on fast move.
func quick_to(other:RefCounted,source:int,candidates:Array) -> bool:
 if source<0 or source>=30 or slots[source].count<=0:return false
 var moved:=false
 for empty_pass in [false,true]:
  for dest in candidates:
   if dest<0 or dest>=30 or (other==self and dest==source):continue
   if slots[source].count<=0:return moved
   var item:String=slots[source].item
   if (other.slots[dest].item=="" if empty_pass else other.slots[dest].item==item and other.slots[dest].count<Items.stack_limit(item)):
    moved=transfer_to(other,source,dest) or moved
 return moved
