extends Control
const Art = preload("res://scripts/visuals/art_direction.gd")
const Appearance = preload("res://data/appearance.gd")
const Sizes = preload("res://data/world_sizes.gd")
var page := "home"
var content: Control
var box: VBoxContainer
var selected: Dictionary = {}
var draft: Dictionary = {}
var create_origin := "home"
var world_origin := "worlds"
var name_input: LineEdit
var gender: OptionButton
var hair: OptionButton
var skin: OptionButton
var world_size: OptionButton
var portrait: Control
var message: Label
var backdrop: TextureRect
var busy := false
func _ready() -> void:
 theme = Art.theme()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop = TextureRect.new()
 backdrop.texture = preload("res://assets/recast/menu.png")
 backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
 add_child(backdrop)
 GameApp.import_legacy()
 show_home()
func begin(title: String) -> void:
 if is_instance_valid(content): remove_child(content); content.queue_free()
 var panel := PanelContainer.new()
 content = panel
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.offset_left = -260
 panel.offset_top = -240
 panel.offset_right = 260
 panel.offset_bottom = 240
 add_child(panel)
 var scroll := ScrollContainer.new(); panel.add_child(scroll)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",10); scroll.add_child(box)
 var heading := Label.new(); heading.text = title; heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.add_theme_font_size_override("font_size",25); box.add_child(heading)
 message = Label.new(); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; message.add_theme_color_override("font_color",Color("e8b58e")); box.add_child(message)
func button(label: String, callback: Callable) -> Button:
 var b := Button.new(); b.text = label; b.custom_minimum_size.y = 36; b.pressed.connect(callback); box.add_child(b)
 return b
func text(value: String) -> Label:
 var label := Label.new(); label.text = value; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(label); return label
func show_home() -> void:
 page = "home"; begin("EMBERDEPTHS")
 text("Тлеющая глубина\nИсследуй. Построй опору. Выбери момент удара.")
 button("ПРОДОЛЖИТЬ",show_characters).grab_focus()
 button("НОВАЯ ИГРА",func(): draft={};create_origin="home";show_character_creator())
 button("НАСТРОЙКИ",show_settings)
 button("ВЫХОД",func(): get_tree().quit())
 message.text = GameApp.menu_error
 GameApp.menu_error = ""
 if not GameApp.library_warnings.is_empty(): message.text += "\n"+"\n".join(GameApp.library_warnings)
func show_characters() -> void:
 page = "characters"; begin("ПЕРСОНАЖИ")
 var records := GameApp.characters()
 if records.is_empty(): text("Персонажей пока нет. Создай своего первого путника.")
 for record in records:
  var row := HBoxContainer.new(); box.add_child(row)
  var p := Control.new(); p.set_script(preload("res://scripts/ui/portrait.gd")); p.appearance=record.appearance; p.custom_minimum_size=Vector2(82,94); row.add_child(p)
  var b := Button.new(); b.text=record.name+"\n"+Appearance.describe(record.appearance); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; b.pressed.connect(func(): selected=record;show_worlds()); row.add_child(b)
 button("Создать персонажа",func(): draft={};create_origin="characters";show_character_creator())
 button("Назад",show_home)
func show_character_creator() -> void:
 page = "create_character"; begin("НОВЫЙ ПЕРСОНАЖ")
 name_input = LineEdit.new(); name_input.placeholder_text="Имя персонажа"; name_input.max_length=32; name_input.text=draft.get("name",""); box.add_child(name_input)
 portrait=Control.new();portrait.set_script(preload("res://scripts/ui/portrait.gd"));portrait.custom_minimum_size=Vector2(90,95);portrait.appearance=draft.get("appearance",Appearance.DEFAULT).duplicate();box.add_child(portrait)
 gender=OptionButton.new();gender.add_item("Мужчина");gender.add_item("Женщина");box.add_child(gender)
 hair=OptionButton.new();hair.add_item("Короткие волосы");hair.add_item("Длинные волосы");box.add_child(hair)
 skin=OptionButton.new()
 for title in ["Светлая кожа","Светлая тёплая кожа","Средний оттенок кожи","Смуглая кожа","Тёмная кожа"]: skin.add_item(title)
 box.add_child(skin)
 var a: Dictionary=Appearance.clean(draft.get("appearance",Appearance.DEFAULT))
 gender.select(0 if a.gender=="male" else 1);hair.select(0 if a.hair=="short" else 1);skin.select(a.skin)
 for option in [gender,hair,skin]: option.item_selected.connect(func(_i): portrait.update_appearance(creator_appearance()))
 button("Далее — создать мир",save_character)
 button("Назад",func():
  if create_origin=="characters": show_characters()
  else: show_home())
func creator_appearance() -> Dictionary: return {"gender":"male" if gender.selected==0 else "female","hair":"short" if hair.selected==0 else "long","skin":skin.selected}
func save_character() -> void:
 if name_input.text.strip_edges().is_empty(): message.text="Введите имя персонажа.";return
 if draft.has("id"):
  draft.name=name_input.text.strip_edges();draft.appearance=creator_appearance()
  if not GameApp.write_json(GameApp.ROOT+"/characters/"+draft.id+".json",draft): message.text="Не удалось сохранить персонажа.";return
 else: draft=GameApp.create_character(name_input.text,creator_appearance())
 if draft.is_empty(): message.text="Не удалось сохранить персонажа.";return
 selected=draft;world_origin="create_character";show_world_creator()
func show_worlds() -> void:
 page="worlds";begin("МИРЫ · "+selected.get("name",""))
 var records:=GameApp.worlds(selected.id)
 if records.is_empty(): text("У этого персонажа ещё нет миров.")
 for record in records:
  var date:="Ещё не запускался"
  if int(record.get("last_played",0))>0: date=Time.get_datetime_string_from_unix_time(int(record.last_played)).substr(0,10)
  button(record.name+" · "+Sizes.DEFINITIONS[record.size].name+"\n"+date,func(): launch(record,false))
 button("Создать мир",func(): world_origin="worlds";show_world_creator())
 button("Назад",show_characters)
func show_world_creator() -> void:
 page="create_world";begin("НОВЫЙ МИР")
 name_input=LineEdit.new();name_input.placeholder_text="Название мира";name_input.max_length=40;box.add_child(name_input)
 world_size=OptionButton.new();world_size.add_item("Маленький");world_size.add_item("Большой");box.add_child(world_size)
 var explanation:=text(Sizes.DEFINITIONS.small.description)
 world_size.item_selected.connect(func(index):explanation.text=Sizes.DEFINITIONS["small" if index==0 else "large"].description)
 button("Создать и играть",func():
  if name_input.text.strip_edges().is_empty():message.text="Введите название мира.";return
  var record:=GameApp.create_world(selected,name_input.text,"small" if world_size.selected==0 else "large")
  if record.is_empty():message.text="Не удалось создать мир.";return
  launch(record,true))
 button("Назад",func():
  if world_origin=="create_character":show_character_creator()
  else:show_worlds())
func launch(record: Dictionary,creating: bool) -> void:
 if busy or not GameApp.select_world(selected,record,creating):return
 busy=true;page="loading";begin("СОЗДАЁМ МИР…" if creating else "ЗАГРУЖАЕМ МИР…")
 text("Подготовка ландшафта, персонажа и сохранения.")
 await get_tree().process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 get_tree().change_scene_to_file("res://scenes/main.tscn")
func show_settings() -> void:
 page="settings";begin("НАСТРОЙКИ")
 var options:=PanelContainer.new();options.set_script(preload("res://scripts/ui/video_options.gd"));box.add_child(options);options.back.connect(show_home)
func _input(event: InputEvent) -> void:
 if busy or page=="settings":return
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
  match page:
   "characters":show_home()
   "worlds":show_characters()
   "create_character":
    if create_origin=="characters":show_characters()
    else:show_home()
   "create_world":
    if world_origin=="create_character":show_character_creator()
    else:show_worlds()
  get_viewport().set_input_as_handled()
