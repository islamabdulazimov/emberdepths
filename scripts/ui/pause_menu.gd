extends CanvasLayer
var main: Node2D
var panel: PanelContainer
var options: PanelContainer
var status: Label
func _ready() -> void:
 main=get_parent();process_mode=Node.PROCESS_MODE_ALWAYS;layer=12
 panel=PanelContainer.new();panel.theme=preload("res://scripts/visuals/art_direction.gd").theme();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-230;panel.offset_right=230;panel.offset_top=-210;panel.offset_bottom=210;add_child(panel);panel.hide()
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
 var title:=Label.new();title.text="ПАУЗА · P / Esc";title.add_theme_font_size_override("font_size",24);box.add_child(title)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
 for item in [["Продолжить",resume],["Настройки",show_settings],["Сохранить и выйти в главное меню",save_exit]]:
  var b:=Button.new();b.text=item[0];b.custom_minimum_size.y=40;b.pressed.connect(item[1]);box.add_child(b)
 options=PanelContainer.new();options.set_script(preload("res://scripts/ui/video_options.gd"));options.set_anchors_and_offsets_preset(Control.PRESET_CENTER);options.offset_left=-260;options.offset_right=260;options.offset_top=-230;options.offset_bottom=230;add_child(options);options.hide();options.back.connect(func():options.hide();panel.show())
func open() -> void:
 if main.inventory_ui.opened:main.inventory_ui.toggle()
 main.npcs.close_dialogue()
 main.pause_open=true;main.input_latched=true
 panel.show();status.text="Сетевая игра продолжается во время меню." if main.network.active else "Игра приостановлена."
 if not main.network.active:get_tree().paused=true
func resume() -> void:
 options.hide();panel.hide();get_tree().paused=false;main.pause_open=false;main.input_latched=true
func show_settings() -> void:panel.hide();options.show()
func save_exit() -> void:
 get_tree().paused=false
 if main.network.active and not main.multiplayer.is_server():await main.network.stop()
 if not main.has_meta("combat_test") and not main.saves.save_now():
  status.text=main.saves.status
  if not main.network.active:get_tree().paused=true
  return
 if main.network.active:await main.network.stop()
 main.pause_open=false
 GameApp.new_game=false
 get_tree().change_scene_to_file("res://scenes/menu.tscn")
func _input(event: InputEvent) -> void:
 if get_viewport().gui_get_focus_owner() is LineEdit:return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_P:
   if main.pause_open:resume()
   else:open()
   get_viewport().set_input_as_handled()
  elif event.physical_keycode==KEY_ESCAPE and main.pause_open and not options.visible:
   resume();get_viewport().set_input_as_handled()
func _exit_tree() -> void:get_tree().paused=false
