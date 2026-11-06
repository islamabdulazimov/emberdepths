extends PanelContainer
signal back
var fps: OptionButton
var resolution: OptionButton
var sync: CheckBox
var confirm: ConfirmationDialog
var remaining := 0.0
var countdown: Label
var sizes: Array[Vector2i] = []
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 theme = preload("res://scripts/visuals/art_direction.gd").theme()
 var box := VBoxContainer.new()
 box.add_theme_constant_override("separation",12)
 add_child(box)
 var title := Label.new(); title.text = "ВИДЕО"; title.add_theme_font_size_override("font_size",24); box.add_child(title)
 fps = OptionButton.new()
 for n in GameApp.FPS: fps.add_item("FPS: "+("Без лимита" if n == 0 else str(n)))
 fps.select(GameApp.FPS.find(int(GameApp.video.fps)))
 box.add_child(fps)
 sync = CheckBox.new(); sync.text = "VSync — синхронизация с монитором"; sync.button_pressed = GameApp.video.vsync; box.add_child(sync)
 var hint := Label.new(); hint.text = "FPS — верхний предел, а не обещание скорости.\nПри VSync пределом также становится частота монитора."; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(hint)
 resolution = OptionButton.new()
 sizes = GameApp.resolutions()
 var current := Vector2i(GameApp.video.width,GameApp.video.height)
 for n in sizes: resolution.add_item("%d × %d" % [n.x,n.y])
 resolution.select(maxi(0,sizes.find(current)))
 box.add_child(resolution)
 var info := Label.new(); info.text = "Стандартные размеры, помещающиеся на текущем экране.\nНеподтверждённое разрешение вернётся через 15 секунд."; info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(info)
 var apply := Button.new(); apply.text = "Применить"; apply.pressed.connect(apply_settings); box.add_child(apply)
 var leave := Button.new(); leave.text = "Назад"; leave.pressed.connect(close); box.add_child(leave)
 confirm = ConfirmationDialog.new()
 confirm.title = "Подтверждение разрешения"
 confirm.ok_button_text = "Оставить"
 confirm.cancel_button_text = "Вернуть прежнее"
 confirm.confirmed.connect(keep_resolution)
 confirm.canceled.connect(revert_resolution)
 add_child(confirm)
func apply_settings() -> void:
 GameApp.set_fps(GameApp.FPS[fps.selected],sync.button_pressed)
 var chosen: Vector2i = sizes[resolution.selected]
 if chosen != Vector2i(GameApp.video.width,GameApp.video.height):
  GameApp.preview_resolution(chosen)
  remaining = 15
  confirm.popup_centered(Vector2i(440,150))
func keep_resolution() -> void:
 GameApp.confirm_resolution()
 confirm.hide()
 remaining = 0
func revert_resolution() -> void:
 GameApp.cancel_resolution()
 confirm.hide()
 remaining = 0
func close() -> void:
 revert_resolution()
 back.emit()
func _process(delta: float) -> void:
 if not visible or not GameApp.resolution_pending: return
 remaining -= delta
 confirm.dialog_text = "Оставить это разрешение? Возврат через %d с" % ceili(maxf(0,remaining))
 if remaining <= 0: revert_resolution()
func _input(event: InputEvent) -> void:
 if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
  if GameApp.resolution_pending: revert_resolution()
  else: close()
  get_viewport().set_input_as_handled()
func _exit_tree() -> void: GameApp.cancel_resolution()
