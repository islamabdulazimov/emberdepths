extends Control
var main: Node2D
var bars: Array[ProgressBar] = []
var labels: Array[Label] = []
var progress: Label

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 for i in range(2):
  var icon:=TextureRect.new();icon.texture=load("res://assets/recast/ui_%s.png"%["health","mana"][i]);icon.position=Vector2(1,i*20);icon.size=Vector2(15,15);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
  var bar := ProgressBar.new()
  bar.position = Vector2(22, i * 20)
  bar.size = Vector2(180, 16)
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
  label.add_theme_font_size_override("font_size", 11)
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  bar.add_child(label)
  labels.append(label)

 progress = Label.new()
 progress.position = Vector2(0, 46)
 progress.size = Vector2(220, 32)
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
 var names := {"attack_windup":"Клинок · замах","attack_active":"Клинок · удар","attack_recovery":"Клинок · восстановление","roll":"Перекат · неуязвимость" if main.player.fighter.roll_invulnerable() else "Перекат · восстановление","parry":"Парирование · окно" if main.player.fighter.parry_open() else ("Парирование · подготовка" if main.player.fighter.elapsed < 0.04 else "Парирование · восстановление"),"parry_success":"Успешное парирование","help":"Помощь товарищу · %d%%"%roundi(main.player.help_progress*100),"hurt":"Получен удар","block":"Блок щитом · R","guard_break":"Щит пробит · восстановление"}
 if action != "idle": progress.text = str(names.get(action,action))+"\n"+main.encounter.notice
 if action=="idle" and main.player.medicine_progress<=0 and main.player.medicine_cooldown<=0:
  var ability:String=main.player.equipment.get("ability","")
  var roll_text:="Shift: нужен Узел странника" if ability=="" else ("Перекат: %.1f с"%main.player.roll_cooldown if main.player.roll_cooldown>0 else "Shift: перекат готов")
  progress.text=roll_text+"\n"+main.encounter.notice
 if main.player.dead:progress.text="Ожидание помощи" if main.player.help_progress<=0 else "Помощь: %d%%"%roundi(main.player.help_progress*100)
 var values = main.player.resources
 var current := [values.health, values.mana]
 var maximum := [values.max_health, values.max_mana]
 for i in range(2):
  bars[i].max_value = maximum[i]
  bars[i].value = current[i]
  labels[i].text = "%s %d/%d" % [["ОЗ", "МП"][i], floori(current[i]), maximum[i]]
