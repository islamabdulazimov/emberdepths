extends Node2D
# Local UI only; commands go through the authenticated host.
var main:Node2D
var opened:=false
var feedback:=""
var layer:CanvasLayer
var panel:PanelContainer
var prompt:Label
var detail:Label
var result:Label
var buttons:Array=[]
func _ready() -> void:
 main=get_parent();z_index=3
 layer=CanvasLayer.new();layer.layer=9;add_child(layer)
 layer.hide()
 if main.has_meta("combat_test"):set_process(false);return
 layer.show()
 prompt=Label.new();prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;prompt.add_theme_font_size_override("font_size",12);prompt.add_theme_color_override("font_outline_color",Color("18252e"));prompt.add_theme_constant_override("outline_size",3);layer.add_child(prompt)
 panel=PanelContainer.new();panel.theme=preload("res://scripts/visuals/art_direction.gd").theme();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-270;panel.offset_right=270;panel.offset_top=-190;panel.offset_bottom=190;layer.add_child(panel);panel.hide()
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box)
 var title:=Label.new();title.text="АЛТАРЬ ВЫЗОВА · ANDREW";title.add_theme_font_size_override("font_size",20);box.add_child(title)
 detail=Label.new();detail.custom_minimum_size=Vector2(510,170);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",13);box.add_child(detail)
 var row:=HBoxContainer.new();box.add_child(row)
 for entry in [["Участвую","join"],["Пропускаю","skip"],["Готов","ready"]]:
  var button:=Button.new();button.text=entry[0];button.add_theme_font_size_override("font_size",13);row.add_child(button);buttons.append(button);button.pressed.connect(func():main.network.altar_local(entry[1]))
 var summon:=Button.new();summon.text="Призвать · один вызов на команду";summon.pressed.connect(func():main.network.altar_local("start"));box.add_child(summon);buttons.append(summon)
 result=Label.new();result.custom_minimum_size.y=30;result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result.add_theme_font_size_override("font_size",12);box.add_child(result)
 var close:=Button.new();close.text="Закрыть · E / Esc";close.pressed.connect(close_panel);box.add_child(close)
func close_panel() -> void:
 opened=false;panel.hide();main.input_latched=true
func open_panel() -> bool:
 if is_instance_valid(main.encounter.actor) or not main.encounter.near_altar(main.player) or main.pause_open or main.inventory_ui.opened or main.npcs.opened:return false
 opened=true;feedback="";panel.show();main.input_latched=true;refresh();return true
func refresh() -> void:
 var encounter=main.encounter;var journal=encounter.journal
 var text:String="Первый вызов: бесплатно для всей команды.\n" if not journal.free_used else "Нужна Печать у призывающего (8 камня, 4 дерева, 2 искрокамня).\n"
 text+="Участники: выберите участие и подтвердите готовность на арене.\n"
 for body in main.get_node("Players").get_children():
  var vote:Dictionary=encounter.choices.get(body.profile_id,{})
  var state:String="наблюдатель" if vote.get("choice","")!="join" else ("готов" if vote.get("ready",false) else "не готов")
  text+="• %s — %s\n"%["Вы" if body==main.player else "Игрок "+str(body.name),state]
 if is_instance_valid(encounter.actor):text="Бой идёт. Новые участники смогут вступать на следующем подэтапе.\n"+encounter.notice
 else:text+="Не участвующие не блокируют призыв. Полоса здоровья учитывает только участников."
 detail.text=text;result.text=feedback
 for button in buttons:button.disabled=is_instance_valid(encounter.actor)
func _process(_delta:float) -> void:
 if not is_instance_valid(main.player):return
 position=main.encounter.journal.altar;visible=position!=Vector2.ZERO
 var near:bool=main.encounter.near_altar(main.player)
 if opened and (not near or main.pause_open or is_instance_valid(main.encounter.actor)):close_panel()
 prompt.visible=not opened and not main.player.dead and not main.pause_open and not main.inventory_ui.opened and not main.npcs.opened
 if prompt.visible:
  if is_instance_valid(main.encounter.actor):
   prompt.text="Арена: блоки защищены на время боя";prompt.position=Vector2(14,165)
  elif near:
   prompt.text="Алтарь Andrew · E — подготовка";prompt.position=get_global_transform_with_canvas().origin+Vector2(-95,-74)
  else:
   var distance:float=position.x-main.player.position.x
   prompt.text="Алтарь Andrew %s · %d блоков"%["→" if distance>0 else "←",ceili(absf(distance)/16)];prompt.position=Vector2(14,165)
 if opened:refresh()
 queue_redraw()
func _unhandled_key_input(event:InputEvent) -> void:
 if main.has_meta("combat_test") or get_viewport().gui_get_focus_owner() is LineEdit:return
 if not event is InputEventKey or not event.pressed or event.echo:return
 if opened and event.physical_keycode in [KEY_E,KEY_ESCAPE]:close_panel();get_viewport().set_input_as_handled()
 elif event.physical_keycode==KEY_E and not main.ui_blocked() and main.survival.nearest_downed()==0 and main.npcs.nearest().is_empty():
  if open_panel():get_viewport().set_input_as_handled()
func _draw() -> void:
 if main.has_meta("combat_test") or position==Vector2.ZERO:return
 # Own pixel clusters, no copied symbols. Non-solid; supported by world terrain.
 draw_rect(Rect2(-19,-4,38,4),Color("131c27"))
 draw_rect(Rect2(-16,-8,32,4),Color("455d68"))
 draw_rect(Rect2(-11,-24,22,16),Color("24313e"))
 draw_rect(Rect2(-10,-24,3,15),Color("68818a"))
 draw_rect(Rect2(7,-24,3,15),Color("455d68"))
 draw_rect(Rect2(-15,-28,30,5),Color("131c27"))
 draw_rect(Rect2(-13,-28,26,2),Color("bf9260"))
 draw_rect(Rect2(-4,-23,8,8),Color("693f39"))
 draw_rect(Rect2(-1,-22,2,5),Color("e5ba7e"))
 if opened and not main.combat_zone.active:
  var area:Rect2i=main.encounter.arena_bounds()
  draw_rect(Rect2(Vector2(area.position)*16-position,Vector2(area.size)*16),Color("bf9260"),false,1)
