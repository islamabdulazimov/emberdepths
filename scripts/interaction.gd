extends Node2D
const Items = preload("res://data/items.gd")
var network: Node
var world: Node2D
var player: CharacterBody2D
var label: Label
var selected_slot: int = 0
var selected_cell := Vector2i.ZERO
var mining_cell := Vector2i(-1, -1)
var mining_slot := -1
var mining_time := 0.0
var build_cooldown := 0.0
var outline_color := Color.WHITE

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE and get_parent().inventory_ui.opened:
  get_parent().inventory_ui.toggle();get_viewport().set_input_as_handled();return
 if get_parent().ui_blocked(): return
 if get_viewport().gui_get_focus_owner() is LineEdit:
  return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode == KEY_ESCAPE:
   get_parent().inventory_ui.toggle()
  elif event.physical_keycode in [KEY_SHIFT,KEY_F] and not get_parent().inventory_ui.opened:
   network.defense_local("roll" if event.physical_keycode == KEY_SHIFT else "parry")
  elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
   selected_slot = event.physical_keycode - KEY_1
  elif event.physical_keycode == KEY_0:
   selected_slot = 9

func _unhandled_input(event: InputEvent) -> void:
 if get_viewport().gui_get_focus_owner() is LineEdit:
  return
 if event is InputEventMouseButton and event.pressed:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP:
   selected_slot = posmod(selected_slot - 1, 10)
  elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
   selected_slot = (selected_slot + 1) % 10
  elif event.button_index == MOUSE_BUTTON_RIGHT and can_use_mouse() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
   var cell: Vector2i = world.cell_at(get_global_mouse_position())
   if get_parent().items.local_inventory().item_at(selected_slot)=="" and world.door_at(cell) != null:
    network.toggle_door_local(cell,selected_slot)
   elif get_parent().items.local_inventory().item_at(selected_slot)=="" and get_parent().storage.at_cell(cell) != null:
    network.open_storage_local(cell,selected_slot)

func can_use_mouse() -> bool:
 return not get_parent().ui_blocked() and is_instance_valid(player) and not player.dead and player.fighter.mode == "idle" and not network.stopping and not get_parent().inventory_ui.opened and get_viewport().gui_get_hovered_control() == null and (not network.active or network.connected)

func _process(delta: float) -> void:
 if not is_instance_valid(player):
  return
 var service = get_parent().items
 selected_cell = world.cell_at(get_global_mouse_position())
 var definition: Dictionary = service.selected_definition(player, selected_slot)
 var kind: String = definition.get("kind", "")
 var primary: String = service.primary_status(player, selected_cell, selected_slot)
 var placement: String = service.placement_status(player, selected_cell, selected_slot)
 var status := primary if world.block_at(selected_cell) != -1 or kind == "weapon" else placement
 if kind in ["axe","consumable"]: status = primary
 if kind == "wall" and world.wall_at(selected_cell) != -1:
  status = primary
 if world.torches.has(selected_cell) or get_parent().combat.chest_at(selected_cell) != -1 or (kind == "" and get_parent().combat.enemy_at(selected_cell) != -1):
  status = primary
 if world.door_at(selected_cell) != null and kind not in ["weapon","axe","consumable","wall"]:
  status = primary
  if kind == "" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
   status = service.door_toggle_status(player,selected_cell,selected_slot) + " · ПКМ | ЛКМ — снять"
 if get_parent().combat.chest_at(selected_cell) == -1 and get_parent().storage.at_cell(selected_cell) != null and kind not in ["weapon","axe","consumable","wall"]:
  status = primary
  if kind == "" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
   status = get_parent().storage.access_status(player,get_parent().storage.at_cell(selected_cell).anchor) + " · ПКМ | ЛКМ — снять пустой"
 outline_color = Color("a9e89b") if status.begins_with("Можно") else Color("e97b77")
 if kind == "weapon":
  outline_color = Color("f0cc8c")
 build_cooldown = maxf(0.0, build_cooldown - delta)
 var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
 if not held or player.medicine_latch != selected_slot: player.medicine_latch = -1
 if held and kind == "consumable": player.medicine_latch = selected_slot
 var medicine_input: bool = kind == "consumable" or player.medicine_latch == selected_slot
 if medicine_input and kind != "consumable":
  status = "Бальзам закончился · отпусти ЛКМ"
  outline_color = Color("e97b77")
 if not network.active:
  var medicine_slot := selected_slot if can_use_mouse() and medicine_input and held else -1
  service.medicine_step(player,medicine_slot,delta)
 if can_use_mouse() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
  if medicine_input:
   mining_time = 0.0
  elif kind == "weapon":
   mining_time = 0.0
   if not network.active:
    service.use_primary(player, selected_cell, selected_slot)
  elif primary.begins_with("Можно"):
   if kind == "axe" and not network.active: service.animate_chop(player,selected_cell,selected_slot)
   elif not network.active: service.animate_work(player,selected_cell,"pick" if kind == "tool" else "punch")
   if mining_cell != selected_cell or mining_slot != selected_slot:
    mining_time = 0.0
    mining_cell = selected_cell
    mining_slot = selected_slot
   mining_time += delta
   if mining_time >= service.primary_duration(player, selected_cell, selected_slot):
    if not network.active:
     service.use_primary(player, selected_cell, selected_slot)
    mining_time = 0.0
  else:
   mining_time = 0.0
 else:
  mining_time = 0.0
  mining_cell = Vector2i(-1, -1)
 if not network.active and can_use_mouse() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and build_cooldown <= 0.0:
  if service.place_selected(player, selected_cell, selected_slot):
   build_cooldown = 0.18
 if get_parent().inventory_ui.opened:
  status = "Инвентарь и крафт открыты"
 var combat = get_parent().combat
 if player.dead:status="Вы упали · вещи сохранены"
 var grave_text := ""
 label.text = "%s\n%s\n%s%s"%[combat.time_label(),definition.get("name","Пустой слот"),status,grave_text]
 label.tooltip_text = "A/D — движение · Space — прыжок\nЛКМ — инструмент / удар · ПКМ — стройка / дверь / сундук\n1–0 / колесо — панель · Esc — инвентарь · Shift — перекат · F — парирование"
 queue_redraw()

func _draw() -> void:
 if is_instance_valid(player) and player.dead:return
 if not is_instance_valid(world):
  return
 if is_instance_valid(player) and (get_parent().items.selected_definition(player,selected_slot).get("kind","") == "consumable" or player.medicine_latch == selected_slot): return
 var corner: Vector2 = to_local(world.cell_center(selected_cell)) - Vector2(8, 8)
 var size := Vector2(16,16)
 var definition: Dictionary = get_parent().items.selected_definition(player,selected_slot)
 var door = world.door_at(selected_cell)
 var chest = get_parent().storage.at_cell(selected_cell)
 if definition.get("kind","") == "storage" or (chest != null and definition.get("kind","") not in ["wall","axe","weapon"]):
  var chest_area: Rect2 = get_parent().storage.area(chest.anchor if chest != null else selected_cell)
  corner = to_local(chest_area.position)
  size = chest_area.size
 elif definition.get("kind","") == "door" or (door != null and definition.get("kind","") not in ["wall","axe","weapon"]):
  var area: Rect2 = world.door_area(door.anchor if door != null else selected_cell)
  corner = to_local(area.position)
  size = area.size
 draw_rect(Rect2(corner, size), outline_color, false, 1.0)
 if mining_time > 0.0 and is_instance_valid(player):
  var duration: float = get_parent().items.primary_duration(player, selected_cell, selected_slot)
  draw_rect(Rect2(corner + Vector2(0, size.y-3), Vector2(size.x * clampf(mining_time / duration, 0.0, 1.0), 3)), Color("f0dc8c"))
