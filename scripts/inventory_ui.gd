extends CanvasLayer
const Recipes = preload("res://data/recipes.gd")
const Items = preload("res://data/items.gd")
var main: Node2D
var opened := false
var source_slot := -1
var quick_buttons: Array[Button] = []
var bag_buttons: Array[Button] = []
var bag: PanelContainer
var clock := 0.0
var crafting: PanelContainer
var recipe_buttons: Dictionary = {}
var feedback: Label
var storage_panel: PanelContainer
var storage_buttons: Array[Button] = []
var storage_anchor := Vector2i(-1,-1)
var storage_requested := false
var storage_slots: Array = []
var storage_revision := 0
var source_box := false
var notice_left := 0.0

func _ready() -> void:
 main = get_parent()
 layer = 3
 var quick := HBoxContainer.new()
 quick.position = Vector2(14, 128)
 add_child(quick)
 for i in range(10):
  var button := _slot_button()
  quick.add_child(button)
  quick_buttons.append(button)
  button.pressed.connect(func(): main.interaction.selected_slot = i)
 bag = PanelContainer.new()
 bag.position = Vector2(14, 200)
 add_child(bag)
 var layout := VBoxContainer.new()
 bag.add_child(layout)
 var hint := Label.new()
 hint.text = "Инвентарь · ЛКМ: выбери стопку, затем место · Esc: закрыть"
 layout.add_child(hint)
 var grid := GridContainer.new()
 grid.columns = 10
 layout.add_child(grid)
 for i in range(30):
  var button := _slot_button()
  grid.add_child(button)
  bag_buttons.append(button)
  button.pressed.connect(func(): _click_slot(i))
 bag.hide()
 crafting = PanelContainer.new()
 crafting.position = Vector2(708, 200)
 add_child(crafting)
 var scroll := ScrollContainer.new()
 scroll.custom_minimum_size = Vector2(236, 300)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 crafting.add_child(scroll)
 var craft_list := VBoxContainer.new()
 scroll.add_child(craft_list)
 var title := Label.new()
 title.text = "Крафт без верстака"
 title.add_theme_font_size_override("font_size", 15)
 craft_list.add_child(title)
 for recipe_id in Recipes.DEFINITIONS:
  var button := Button.new()
  button.custom_minimum_size = Vector2(220, 42)
  button.clip_text = true
  button.focus_mode = Control.FOCUS_NONE
  button.add_theme_font_size_override("font_size", 12)
  craft_list.add_child(button)
  recipe_buttons[recipe_id] = button
  button.pressed.connect(func(): _craft(recipe_id))
 crafting.hide()
 feedback = Label.new()
 feedback.position = Vector2(14, 420)
 feedback.add_theme_font_size_override("font_size", 13)
 feedback.text = "Искрокамень: янтарные вкрапления под поверхностью. Рядом со стартом: 3 блока вправо, 3 вниз."
 add_child(feedback)
 feedback.hide()
 feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
 storage_panel = PanelContainer.new()
 storage_panel.position = Vector2(708,200)
 add_child(storage_panel)
 var storage_layout := VBoxContainer.new()
 storage_panel.add_child(storage_layout)
 var storage_header := Button.new()
 storage_header.text = "Сундук · 30 ячеек · закрыть"
 storage_header.focus_mode = Control.FOCUS_NONE
 storage_header.add_theme_font_size_override("font_size",12)
 storage_header.pressed.connect(toggle)
 storage_layout.add_child(storage_header)
 var storage_grid := GridContainer.new()
 storage_grid.columns = 5
 storage_layout.add_child(storage_grid)
 for i in range(30):
  var button := _slot_button()
  button.custom_minimum_size = Vector2(42,38)
  button.add_theme_constant_override("icon_max_width",14)
  button.add_theme_font_size_override("font_size",11)
  storage_grid.add_child(button)
  storage_buttons.append(button)
  button.pressed.connect(func(): _storage_click(true,i))
 storage_panel.hide()
 refresh()

func _slot_button() -> Button:
 var button := Button.new()
 button.custom_minimum_size = Vector2(64, 56)
 button.focus_mode = Control.FOCUS_NONE
 button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
 button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
 button.expand_icon = true
 button.add_theme_constant_override("icon_max_width", 20)
 button.add_theme_font_size_override("font_size", 13)
 return button

func toggle() -> void:
 var pending := storage_requested and not opened
 if storage_requested or storage_anchor != Vector2i(-1,-1): main.network.close_storage_local()
 reset_storage()
 if pending: return
 opened = not opened
 source_slot = -1
 bag.visible = opened
 crafting.visible = opened
 feedback.visible = opened
 refresh()

func _click_slot(index: int) -> void:
 if main.network.stopping or main.player.dead:
  return
 if storage_anchor != Vector2i(-1,-1):
  _storage_click(false,index)
  return
 var inventory = main.items.local_inventory()
 if source_slot == -1:
  if inventory.slots[index].count > 0:
   source_slot = index
 elif source_slot == index:
  source_slot = -1
 else:
  if main.network.active:
   main.network.transfer_local(source_slot, index)
  else:
   main.items.transfer(int(str(main.player.name)), source_slot, index)
  source_slot = -1
 refresh()

func _process(delta: float) -> void:
 notice_left = maxf(0,notice_left-delta)
 if not opened: feedback.visible = notice_left > 0
 clock += delta
 if clock >= 0.1:
  clock = 0.0
  refresh()

func refresh() -> void:
 if not is_instance_valid(main.player):
  return
 var inventory = main.items.local_inventory()
 for i in range(10):
  _paint(quick_buttons[i], inventory.slots[i], str((i + 1) % 10), i == main.interaction.selected_slot)
 for recipe_id in recipe_buttons:
  var recipe: Dictionary = Recipes.DEFINITIONS[recipe_id]
  var ingredients: PackedStringArray = []
  for item_id in recipe.ingredients:
   ingredients.append("%s %d/%d" % [Items.DEFINITIONS[item_id].name, inventory.count_item(item_id), recipe.ingredients[item_id]])
  var button: Button = recipe_buttons[recipe_id]
  button.text = "%s ×%d\n%s" % [Items.DEFINITIONS[recipe.output].name, recipe.count, " · ".join(ingredients)]
  var status: String = inventory.craft_preview(recipe_id).status
  button.tooltip_text = status + "\n" + " · ".join(ingredients)
  button.disabled = status != "Можно создать" or main.player.dead or main.network.stopping or (main.network.active and not main.network.connected)
 for i in range(30):
  _paint(bag_buttons[i], inventory.slots[i], str(i + 1), i == source_slot and not source_box)
 if storage_anchor != Vector2i(-1,-1) and storage_slots.size() == 30:
  for i in range(30): _paint(storage_buttons[i],storage_slots[i],str(i+1),source_box and i == source_slot)

func reset_storage() -> void:
 storage_requested = false
 storage_anchor = Vector2i(-1,-1)
 storage_slots = []
 storage_revision = 0
 source_slot = -1
 source_box = false
 if is_instance_valid(storage_panel): storage_panel.hide()
 if is_instance_valid(crafting): crafting.visible = opened

func apply_storage_view(anchor: Vector2i, contents: Array, revision: int, message: String = "") -> void:
 if anchor == Vector2i(-1,-1):
  reset_storage()
  if message != "":
   feedback.text = message
   notice_left = 2.5
   feedback.show()
  return
 if not storage_requested: return # Ignore a delayed open after Esc/cancellation.
 if revision != storage_revision or anchor != storage_anchor: source_slot = -1
 storage_anchor = anchor
 storage_slots = contents.duplicate(true)
 storage_revision = revision
 opened = true
 bag.show()
 crafting.hide()
 storage_panel.show()
 feedback.text = message if message != "" else "ЛКМ по стопке → ЛКМ по ячейке назначения · Esc: закрыть"
 feedback.show()
 refresh()

func _storage_click(from_box: bool, index: int) -> void:
 if main.network.stopping or main.player.dead or storage_anchor == Vector2i(-1,-1): return
 var slots: Array = storage_slots if from_box else main.items.local_inventory().slots
 if source_slot == -1:
  if slots[index].count > 0:
   source_slot = index
   source_box = from_box
 elif source_box == from_box and source_slot == index:
  source_slot = -1
 else:
  main.network.move_storage_local(storage_anchor,source_box,source_slot,from_box,index,storage_revision)
  source_slot = -1
 refresh()

func _paint(button: Button, slot: Dictionary, number: String, selected: bool) -> void:
 button.text = number + (" · %d" % slot.count if slot.count > 0 else " · —")
 button.tooltip_text = Items.DEFINITIONS[slot.item].name if slot.count > 0 else "Пустой слот"
 button.icon = null
 if slot.count > 0:
  button.icon = Items.icon(slot.item)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("263b43") if not selected else Color("496052")
 style.border_color = Color("ddc98b") if selected else Color("4f666c")
 style.set_border_width_all(2 if selected else 1)
 button.add_theme_stylebox_override("normal", style)


func _craft(recipe_id: String) -> void:
 if main.network.stopping or main.player.dead:
  return
 if main.network.active:
  main.network.craft_local(recipe_id)
 else:
  show_craft_result(main.items.craft(int(str(main.player.name)), recipe_id))

func show_craft_result(message: String) -> void:
 feedback.text = message
 refresh()
