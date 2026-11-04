extends CanvasLayer
const Items = preload("res://data/items.gd")
var main: Node2D
var opened := false
var source_slot := -1
var quick_buttons: Array[Button] = []
var bag_buttons: Array[Button] = []
var bag: PanelContainer
var clock := 0.0

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
 refresh()

func _click_slot(index: int) -> void:
 if main.network.stopping:
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
 for i in range(30):
  _paint(bag_buttons[i], inventory.slots[i], str(i + 1), i == source_slot)

func _paint(button: Button, slot: Dictionary, number: String, selected: bool) -> void:
 button.text = number + (" · %d" % slot.count if slot.count > 0 else " · —")
 button.tooltip_text = Items.DEFINITIONS[slot.item].name if slot.count > 0 else "Пустой слот"
 button.icon = null
 if slot.count > 0:
  var texture := AtlasTexture.new()
  texture.atlas = preload("res://assets/terrain.png")
  texture.region = Rect2(Vector2(Items.DEFINITIONS[slot.item].atlas) * 16.0, Vector2(16, 16))
  button.icon = texture
 var style := StyleBoxFlat.new()
 style.bg_color = Color("263b43") if not selected else Color("496052")
 style.border_color = Color("ddc98b") if selected else Color("4f666c")
 style.set_border_width_all(2 if selected else 1)
 button.add_theme_stylebox_override("normal", style)
