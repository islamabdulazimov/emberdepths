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
 var craft_list := VBoxContainer.new()
 crafting.add_child(craft_list)
 var title := Label.new()
 title.text = "Крафт без верстака"
 title.add_theme_font_size_override("font_size", 15)
 craft_list.add_child(title)
 for recipe_id in Recipes.DEFINITIONS:
  var button := Button.new()
  button.custom_minimum_size = Vector2(236, 42)
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
 opened = not opened
 source_slot = -1
 bag.visible = opened
 crafting.visible = opened
 feedback.visible = opened
 refresh()

func _click_slot(index: int) -> void:
 if main.network.stopping or main.player.dead:
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
  _paint(bag_buttons[i], inventory.slots[i], str(i + 1), i == source_slot)

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
