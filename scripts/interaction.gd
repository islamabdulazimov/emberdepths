extends Node2D
const Blocks = preload("res://data/blocks.gd")
var network: Node
var world: Node2D
var player: CharacterBody2D
var bodies: Node2D
var label: Label
var selected_block: int = Blocks.DIRT
var selected_cell := Vector2i.ZERO
var mining_cell := Vector2i(-1, -1)
var mining_time := 0.0
var build_cooldown := 0.0
var outline_color := Color.WHITE

func _unhandled_key_input(event: InputEvent) -> void:
 if get_viewport().gui_get_focus_owner() is LineEdit:
  return
 if event is InputEventKey and event.pressed and not event.echo:
  match event.physical_keycode:
   KEY_1: selected_block = Blocks.DIRT
   KEY_2: selected_block = Blocks.STONE
   KEY_3: selected_block = Blocks.GRASS

func can_use_mouse() -> bool:
 return get_viewport().gui_get_hovered_control() == null and (not network.active or network.connected)

func _process(delta: float) -> void:
 if not is_instance_valid(player):
  return
 selected_cell = world.cell_at(get_global_mouse_position())
 var players := bodies.get_children()
 var mine_status: String = world.interaction_status(player, selected_cell, false, players)
 var build_status: String = world.interaction_status(player, selected_cell, true, players)
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
    world.request_edit(player, selected_cell, -1, players)
   mining_time = 0.0
 else:
  mining_time = 0.0
  mining_cell = Vector2i(-1, -1)
 # Left mouse takes precedence when both buttons are held.
 if not network.active and can_use_mouse() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and build_cooldown <= 0.0:
  if world.request_edit(player, selected_cell, selected_block, players):
   build_cooldown = 0.18
 label.text = "EMBERDEPTHS · ЭТАП 2b · Seed: %d\nA/D — ходьба · Space — прыжок · ЛКМ — добыть · ПКМ — строить\n1 Земля · 2 Камень · 3 Дёрн | Выбрано: %s (без лимита)\n%s · Дальность: 5 блоков · Изменения пока не сохраняются" % [world.world_seed, Blocks.DEFINITIONS[selected_block].name, status]
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
