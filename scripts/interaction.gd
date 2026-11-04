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
 if get_viewport().gui_get_focus_owner() is LineEdit:
  return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode == KEY_ESCAPE:
   get_parent().inventory_ui.toggle()
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

func can_use_mouse() -> bool:
 return is_instance_valid(player) and not player.dead and not network.stopping and not get_parent().inventory_ui.opened and get_viewport().gui_get_hovered_control() == null and (not network.active or network.connected)

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
 if kind == "wall" and world.wall_at(selected_cell) != -1:
  status = primary
 if world.torches.has(selected_cell) or get_parent().combat.chest_at(selected_cell) != -1 or (kind == "" and get_parent().combat.enemy_at(selected_cell) != -1):
  status = primary
 outline_color = Color("a9e89b") if status.begins_with("Можно") else Color("e97b77")
 if kind == "weapon":
  outline_color = Color("f0cc8c")
 build_cooldown = maxf(0.0, build_cooldown - delta)
 if can_use_mouse() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
  if kind == "weapon":
   mining_time = 0.0
   if not network.active:
    service.use_primary(player, selected_cell, selected_slot)
  elif primary.begins_with("Можно"):
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
 var health_text := "HP %d/100" % player.health
 if player.dead:
  health_text = "Вы погибли · Возрождение %.1f с" % player.respawn_remaining
 var grave_text := ""
 if player.last_chest_position.x >= 0:
  var grave: Vector2i = world.cell_at(player.last_chest_position)
  grave_text = " · Сундук (%d, %d)" % [grave.x, grave.y]
 var location: Vector2i = world.cell_at(player.position)
 label.text = "%s · %s\nA/D · Space · ЛКМ — инструмент / удар · ПКМ — размещение\n1–0 / колесо — слот · Esc — инвентарь и крафт\n%s | %s\nSeed %d · Вы (%d, %d)%s" % [health_text, combat.time_label(), definition.get("name", "Пустой слот"), status, world.world_seed, location.x, location.y, grave_text]
 queue_redraw()

func _draw() -> void:
 if not is_instance_valid(world):
  return
 var corner: Vector2 = to_local(world.cell_center(selected_cell)) - Vector2(8, 8)
 draw_rect(Rect2(corner, Vector2(16, 16)), outline_color, false, 1.0)
 if mining_time > 0.0 and is_instance_valid(player):
  var duration: float = get_parent().items.primary_duration(player, selected_cell, selected_slot)
  draw_rect(Rect2(corner + Vector2(0, 13), Vector2(16 * clampf(mining_time / duration, 0.0, 1.0), 3)), Color("f0dc8c"))
