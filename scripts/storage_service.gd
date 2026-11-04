extends Node2D
signal object_changed(anchor: Vector2i, data: Dictionary)
signal view_changed(id: int, anchor: Vector2i, slots: Array, revision: int, message: String)
const Chest = preload("res://scripts/storage_chest.gd")
const Rules = preload("res://data/structures.gd")
const NONE := Vector2i(-1,-1)
var main: Node2D
var chests: Dictionary = {}
var cells: Dictionary = {}
var viewers: Dictionary = {} # Host-only player ID -> chest anchor.

func _ready() -> void: main = get_parent()
func authoritative() -> bool: return main.combat.authoritative()
func at_cell(cell: Vector2i) -> Node2D: return chests.get(cells.get(cell))
func empty(chest: Node2D) -> bool:
 for slot in chest.inventory.slots:
  if slot.count > 0: return false
 return true

func area(anchor: Vector2i) -> Rect2:
 return Rect2(main.world.cell_center(anchor)-Vector2(8,8),Vector2(Rules.CHEST_WIDTH*16,16))

func access_status(body: CharacterBody2D, anchor: Vector2i) -> String:
 if body == null or body.dead: return "Сундук недоступен после смерти"
 if not chests.has(anchor): return "Сундук убран"
 var near := false
 for part in Rules.chest_cells(anchor):
  if main.world.in_reach(body,part): near = true
 if not near: return "Сундук слишком далеко"
 if not main.combat.line_clear(body.position+Vector2(0,-5),area(anchor).get_center()): return "Сундук за преградой"
 return "Можно открыть сундук"

func placement_status(body: CharacterBody2D, anchor: Vector2i) -> String:
 if body.dead: return "Вы погибли"
 if chests.size() >= Rules.MAX_CHESTS: return "Слишком много сундуков"
 if anchor.x < 0 or anchor.x+Rules.CHEST_WIDTH > main.world.world_width or anchor.y < 0 or anchor.y >= main.world.world_depth-1: return "За границей мира"
 for part in Rules.chest_cells(anchor):
  if not main.world.in_reach(body,part): return "Сундук вне досягаемости"
  if main.world.block_at(part) != -1 or main.world.door_at(part) != null or at_cell(part) != null or main.world.torches.has(part) or main.combat.chest_at(part) != -1:
   return "Нужны две свободные клетки"
  if main.world.block_at(part+Vector2i.DOWN) == -1: return "Нужен твёрдый пол под сундуком"
 if main.world.area_occupied(area(anchor),main.items.solid_bodies()): return "Мешает персонаж или противник"
 if not main.combat.line_clear(body.position+Vector2(0,-5),area(anchor).get_center()): return "Сундук за преградой"
 return "Можно поставить сундук"

func place(body: CharacterBody2D, anchor: Vector2i, slot: int) -> bool:
 if not authoritative() or slot < 0 or slot >= 10 or main.items.selected_definition(body,slot).get("kind","") != "storage" or placement_status(body,anchor) != "Можно поставить сундук": return false
 apply_object(anchor,{"empty":true,"opened":false})
 var id := int(str(body.name))
 main.items.inventory_for(id).take_one(slot)
 main.items.inventory_changed.emit(id)
 main.items.animate_work(body,anchor,"build")
 refresh(anchor)
 return true

func removal_status(body: CharacterBody2D, cell: Vector2i) -> String:
 var chest = at_cell(cell)
 if chest == null: return "Здесь нет сундука"
 var status := access_status(body,chest.anchor)
 if status != "Можно открыть сундук": return status
 if not chest.known_empty: return "Сначала опустоши сундук"
 if viewers.values().has(chest.anchor) or chest.opened: return "Сначала закрой сундук"
 return "Можно снять сундук"

func remove_empty(body: CharacterBody2D, cell: Vector2i) -> bool:
 if not authoritative() or removal_status(body,cell) != "Можно снять сундук": return false
 destroy(at_cell(cell).anchor)
 return true

func open_view(id: int, cell: Vector2i, slot: int) -> bool:
 if not authoritative(): return false
 var body = main.get_node("Players").get_node_or_null(str(id))
 var chest = at_cell(cell)
 var status := "Здесь нет сундука" if chest == null else access_status(body,chest.anchor)
 if body == null or slot < 0 or slot >= 10 or not main.items.selected_definition(body,slot).is_empty(): status = "Выбери пустой слот для сундука"
 if status != "Можно открыть сундук":
  close_view(id,status)
  return false
 if viewers.has(id) and viewers[id] != chest.anchor: close_view(id,"")
 main.items.cancel_medicine(body)
 viewers[id] = chest.anchor
 refresh(chest.anchor)
 return true

func send_view(id: int, message: String = "") -> void:
 if not viewers.has(id) or not chests.has(viewers[id]): return
 var chest = chests[viewers[id]]
 view_changed.emit(id,chest.anchor,chest.inventory.to_data(),chest.revision,message)

func close_view(id: int, message: String = "") -> void:
 var old: Vector2i = viewers.get(id,NONE)
 viewers.erase(id)
 view_changed.emit(id,NONE,[],0,message)
 if chests.has(old): refresh(old)

func close_all() -> void:
 for id in viewers.keys(): close_view(id,"")
 if is_instance_valid(main.inventory_ui): main.inventory_ui.reset_storage()

func move(id: int, anchor: Vector2i, from_box: bool, source: int, to_box: bool, destination: int, revision: int) -> bool:
 if not authoritative() or viewers.get(id,NONE) != anchor or not chests.has(anchor): return false
 var body = main.get_node("Players").get_node_or_null(str(id))
 var status := access_status(body,anchor)
 if status != "Можно открыть сундук":
  close_view(id,status)
  return false
 var chest = chests[anchor]
 if revision != chest.revision:
  send_view(id,"Сундук изменился — выбери стопку ещё раз")
  return false
 var bag = main.items.inventory_for(id)
 var origin = chest.inventory if from_box else bag
 var target = chest.inventory if to_box else bag
 if not origin.transfer_to(target,source,destination):
  send_view(id,"Перенос недоступен")
  return false
 if from_box or to_box: chest.revision += 1
 main.items.inventory_changed.emit(id)
 refresh(anchor)
 return true

func refresh(anchor: Vector2i) -> void:
 if not chests.has(anchor): return
 var chest = chests[anchor]
 chest.known_empty = empty(chest)
 chest.opened = viewers.values().has(anchor)
 object_changed.emit(anchor,{"empty":chest.known_empty,"opened":chest.opened})
 for id in viewers:
  if viewers[id] == anchor: send_view(id)

func destroy(anchor: Vector2i) -> void:
 if not authoritative() or not chests.has(anchor): return
 var contents: Array = chests[anchor].inventory.to_data()
 for id in viewers.keys():
  if viewers[id] == anchor: close_view(id,"Сундук убран")
 apply_object(anchor,{})
 object_changed.emit(anchor,{})
 var at: Vector2 = main.world.cell_center(anchor)+Vector2(8,0)
 for slot in contents:
  if slot.count > 0: main.items.spawn_drop(slot.item,slot.count,at)
 main.items.spawn_drop("wood_chest",1,at)

func check_support() -> void:
 if not authoritative(): return
 for anchor in chests.keys():
  for part in Rules.chest_cells(anchor):
   if main.world.block_at(part+Vector2i.DOWN) == -1:
    destroy(anchor)
    break

func _physics_process(_delta: float) -> void:
 if not authoritative(): return
 for id in viewers.keys():
  var body = main.get_node("Players").get_node_or_null(str(id))
  var status := access_status(body,viewers[id])
  if status != "Можно открыть сундук": close_view(id,status)

func apply_object(anchor: Vector2i, data: Dictionary) -> void:
 if data.is_empty():
  if not chests.has(anchor): return
  remove_child(chests[anchor])
  chests[anchor].queue_free()
  chests.erase(anchor)
  for part in Rules.chest_cells(anchor): cells.erase(part)
  if is_instance_valid(main.inventory_ui) and main.inventory_ui.storage_anchor == anchor:
   main.inventory_ui.apply_storage_view(NONE,[],0,"Сундук убран")
  return
 if not chests.has(anchor):
  var chest := Node2D.new()
  chest.set_script(Chest)
  chest.anchor = anchor
  chest.position = main.world.cell_center(anchor)+Vector2(8,0)
  chest.opened = data.opened
  add_child(chest)
  chests[anchor] = chest
  for part in Rules.chest_cells(anchor): cells[part] = anchor
 chests[anchor].known_empty = data.empty
 chests[anchor].opened = data.opened

func objects_snapshot() -> Dictionary:
 var result: Dictionary = {}
 for anchor in chests: result[anchor] = {"empty":chests[anchor].known_empty,"opened":chests[anchor].opened}
 return result

func snapshot() -> Dictionary:
 var result: Dictionary = {}
 for anchor in chests: result[anchor] = chests[anchor].inventory.to_data()
 return result

func clear() -> void:
 viewers.clear()
 if is_instance_valid(main.inventory_ui): main.inventory_ui.reset_storage()
 for anchor in chests.keys(): apply_object(anchor,{})

func restore(data: Dictionary) -> void:
 clear()
 for anchor in data:
  apply_object(anchor,{"empty":true,"opened":false})
  chests[anchor].inventory.load_data(data[anchor])
  chests[anchor].known_empty = empty(chests[anchor])
