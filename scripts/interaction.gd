extends Node2D
const Blocks = preload("res://data/blocks.gd")
var network: Node
var world: Node2D
var player: CharacterBody2D
var bodies: Node2D
var label: Label
var selected_slot: int = 0
var selected_block: int:
 get:
  return get_parent().items.local_inventory().block_in_slot(selected_slot)
var selected_cell := Vector2i.ZERO
var mining_cell := Vector2i(-1, -1)
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
 return not network.stopping and not get_parent().inventory_ui.opened and get_viewport().gui_get_hovered_control() == null and (not network.active or network.connected)

func _process(delta: float) -> void:
 if not is_instance_valid(player):
  return
 selected_cell = world.cell_at(get_global_mouse_position())
 var players := bodies.get_children()
 var mine_status: String = world.interaction_status(player, selected_cell, false, players)
 var build_status: String = world.interaction_status(player, selected_cell, true, players)
 if selected_block == -1:
  build_status = "Выбран пустой слот"
 var has_block: bool = world.block_at(selected_cell) != -1
 var status := mine_status if has_block else build_status
 outline_color = Color("a9e89b") if status in ["Можно добыть", "Можно построить"] else Color("e97b77")
 build_cooldown = maxf(0.0, build_cooldown - delta)
 if can_use_mouse() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mine_status == "Можно добыть":
  if mining_cell != selected_cell:
   mining_time = 0.0
   mining_cell = selected_cell
  mining_time += delta
  var duration: float = Blocks.DEFINITIONS[world.block_at(selected_cell)].mine_time
  if mining_time >= duration:
   if not network.active:
    get_parent().items.try_edit(player, selected_cell, -1, players)
   mining_time = 0.0
 else:
  mining_time = 0.0
  mining_cell = Vector2i(-1, -1)
 # Left mouse takes precedence when both buttons are held.
 if selected_block != -1 and not network.active and can_use_mouse() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and build_cooldown <= 0.0:
  if get_parent().items.try_edit(player, selected_cell, selected_block, players, selected_slot):
   build_cooldown = 0.18
 if get_parent().inventory_ui.opened:
  status = "Закрой инвентарь для добычи и строительства"
 var item_name := "Пусто"
 if selected_block != -1:
  item_name = Blocks.DEFINITIONS[selected_block].name
 label.text = "EMBERDEPTHS · ЭТАП 3 · Seed: %d\nA/D · Space · ЛКМ — добыть · ПКМ — строить · Esc — инвентарь\n1–0 / колесо — слот | Выбрано: %s | %s\nПодбор рядом автоматически · Мир и вещи пока не сохраняются" % [world.world_seed, item_name, status]
 queue_redraw()

func _draw() -> void:
 if not is_instance_valid(world):
  return
 var corner: Vector2 = to_local(world.cell_center(selected_cell)) - Vector2(8, 8)
 draw_rect(Rect2(corner, Vector2(16, 16)), outline_color, false, 1.0)
 if mining_time > 0.0:
  var id: int = world.block_at(selected_cell)
  if id != -1:
   var fraction := clampf(mining_time / float(Blocks.DEFINITIONS[id].mine_time), 0.0, 1.0)
   draw_rect(Rect2(corner + Vector2(0, 13), Vector2(16 * fraction, 3)), Color("f0dc8c"))
