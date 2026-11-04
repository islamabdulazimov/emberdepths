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
  background.border_color = Color("455d68")
  background.set_border_width_all(1)
  bar.add_theme_stylebox_override("background", background)
  var fill := StyleBoxFlat.new()
  fill.bg_color = [Color("ac655f"), Color("597e9c"), Color("668a75")][i]
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
 progress.max_lines_visible = 2
 progress.add_theme_font_size_override("font_size", 12)
 progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(progress)

func _process(_delta: float) -> void:
 if not is_instance_valid(main.player): return
 progress.text = main.encounter.notice
 if main.player.medicine_progress > 0:
  progress.text = "Бальзам · применение %d%%\n%s" % [roundi(main.player.medicine_progress*100),main.encounter.notice]
 elif main.player.medicine_cooldown > 0:
  progress.text = "Бальзам · готов через %.1f с\n%s" % [main.player.medicine_cooldown,main.encounter.notice]
 var action: String = main.player.fighter.phase()
 var names := {"attack_windup":"Клинок · замах","attack_active":"Клинок · удар","attack_recovery":"Клинок · восстановление","roll":"Перекат · неуязвимость" if main.player.fighter.roll_invulnerable() else "Перекат · восстановление","parry":"Парирование · окно" if main.player.fighter.parry_open() else ("Парирование · подготовка" if main.player.fighter.elapsed < 0.04 else "Парирование · восстановление"),"parry_success":"Успешное парирование","hurt":"Получен удар"}
 if action != "idle": progress.text = str(names.get(action,action))+"\n"+main.encounter.notice
 var values = main.player.resources
 var current := [values.health, values.mana, values.stamina]
 var maximum := [values.max_health, values.max_mana, values.max_stamina]
 for i in range(3):
  bars[i].max_value = maximum[i]
  bars[i].value = current[i]
  labels[i].text = "%s %d/%d" % [["ОЗ", "МП", "Выносливость"][i], floori(current[i]), maximum[i]]
