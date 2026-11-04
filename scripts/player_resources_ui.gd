extends Control
var main: Node2D
var bars: Array[ProgressBar] = []
var labels: Array[Label] = []
var progress: Label

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 for i in range(3):
  var bar := ProgressBar.new()
  bar.position = Vector2(0, i * 23)
  bar.size = Vector2(220, 19)
  bar.show_percentage = false
  bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var background := StyleBoxFlat.new()
  background.bg_color = Color("18252e")
  bar.add_theme_stylebox_override("background", background)
  var fill := StyleBoxFlat.new()
  fill.bg_color = [Color("bb515b"), Color("4d83c7"), Color("579a68")][i]
  bar.add_theme_stylebox_override("fill", fill)
  add_child(bar)
  bars.append(bar)
  var label := Label.new()
  label.size = bar.size
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override("font_size", 13)
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  bar.add_child(label)
  labels.append(label)

 progress = Label.new()
 progress.position = Vector2(0, 74)
 progress.size = Vector2(220, 36)
 progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 progress.add_theme_font_size_override("font_size", 12)
 progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(progress)

func _process(_delta: float) -> void:
 if not is_instance_valid(main.player): return
 progress.text = main.encounter.notice
 var values = main.player.resources
 var current := [values.health, values.mana, values.stamina]
 var maximum := [values.max_health, values.max_mana, values.max_stamina]
 for i in range(3):
  bars[i].max_value = maximum[i]
  bars[i].value = current[i]
  labels[i].text = "%s %d/%d" % [["ОЗ", "МП", "Выносливость"][i], floori(current[i]), maximum[i]]
