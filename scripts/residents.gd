extends Node
signal changed(records: Dictionary)
const Data = preload("res://data/residents.gd")
var main: Node2D
var actors := {}
var clock := 0.0
var cursors := {}
var opened := false
var active_id := ""
var layer: CanvasLayer
var prompt: Label
var panel: PanelContainer
var speaker: Label
var speech: Label
class Resident extends Node2D:
 var id := "julia"
 var clock := 0.0
 func _ready() -> void:
  var shading:=ShaderMaterial.new();shading.shader=preload("res://scripts/visuals/resident_light.gdshader");material=shading
 func _process(delta: float) -> void:
  clock += delta
  queue_redraw()
 func _draw() -> void:
  var texture: Texture2D = preload("res://assets/actors/julia.png") if id=="julia" else preload("res://assets/actors/cameron.png")
  var frame := int(clock*2)%4
  draw_set_transform(Vector2.ZERO,0,Vector2(1 if id=="julia" else -1,1))
  draw_texture_rect_region(texture,Rect2(-16,-28,32,40),Rect2(frame*32,0,32,40))
  draw_set_transform_matrix(Transform2D.IDENTITY)
func _ready() -> void:
 main = get_parent()
 layer=CanvasLayer.new();layer.layer=8;add_child(layer)
 prompt=Label.new();prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;prompt.add_theme_font_size_override("font_size",13);prompt.add_theme_color_override("font_outline_color",Color("18252e"));prompt.add_theme_constant_override("outline_size",3);layer.add_child(prompt)
 panel=PanelContainer.new();panel.theme=preload("res://scripts/visuals/art_direction.gd").theme();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);panel.offset_left=-300;panel.offset_right=300;panel.offset_top=-168;panel.offset_bottom=-20;layer.add_child(panel);panel.hide()
 var box:=VBoxContainer.new();panel.add_child(box)
 speaker=Label.new();speaker.add_theme_font_size_override("font_size",20);box.add_child(speaker)
 speech=Label.new();speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;speech.custom_minimum_size=Vector2(560,52);speech.add_theme_font_size_override("font_size",16);box.add_child(speech)
 var close:=Button.new();close.text="Закрыть · Esc";close.pressed.connect(close_dialogue);box.add_child(close)
func sync() -> void:
 for id in actors.keys():
  if not main.world.npc_records.has(id): actors[id].queue_free();actors.erase(id)
 for id in main.world.npc_records:
  if not Data.DEFINITIONS.has(id):continue
  if not actors.has(id):
   var actor:=Resident.new();actor.id=id;actor.z_index=3;add_child(actor);actors[id]=actor
  actors[id].position=main.world.npc_records[id].position
func nearest() -> String:
 if not is_instance_valid(main.player) or main.player.dead:return ""
 var closest:="";var distance:=72.0
 for id in actors:
  var d:float=main.player.position.distance_to(actors[id].position)
  if d<distance and main.combat.line_clear(main.player.position+Vector2(0,-6),actors[id].position+Vector2(0,-6)):
   closest=id;distance=d
 return closest
func talk(id: String) -> bool:
 if not Data.DEFINITIONS.has(id) or id!=nearest() or main.pause_open or main.inventory_ui.opened:return false
 var entry:Dictionary=Data.DEFINITIONS[id]
 var index:int=int(cursors.get(id,0))%entry.lines.size()
 speaker.text=entry.name;speech.text=entry.lines[index]
 cursors[id]=index+1;active_id=id;opened=true;panel.show();main.input_latched=true
 return true
func close_dialogue() -> void:
 opened=false;active_id="";panel.hide();main.input_latched=true
func rescue() -> void:
 var updated:=false
 for id in main.world.npc_records:
  var record:Dictionary=main.world.npc_records[id]
  var at:Vector2=record.position
  var floor_cell:Vector2i=main.world.cell_at(at+Vector2(0,10.1))
  if main.world.block_at(floor_cell)>=0 and main.world.character_fits(at):continue
  var found:=false
  var home:Vector2=record.home
  var home_cell:Vector2i=main.world.cell_at(home+Vector2(0,10))
  for radius in range(22):
   if found:break
   for dx in [-radius,radius]:
    for dy in [0,-1,1,-2,2]:
     var c:=home_cell+Vector2i(dx,dy)
     var candidate:=Vector2(c.x*16+8,c.y*16-10)
     if main.world.block_at(c)>=0 and main.world.character_fits(candidate):
      record.position=candidate;found=true;updated=true;break
    if found:break
 if updated:sync();changed.emit(main.world.npc_records.duplicate(true))
func _process(delta: float) -> void:
 clock+=delta
 if clock>=0.5:
  clock=fmod(clock,0.5);sync()
  if is_instance_valid(main.network) and main.combat.authoritative():rescue()
 if opened and (main.player.dead or active_id!=nearest()):close_dialogue()
 var id:=nearest()
 prompt.visible=not id.is_empty() and not opened and not main.pause_open and not main.inventory_ui.opened
 if prompt.visible:
  prompt.text=Data.DEFINITIONS[id].name+" · E — поговорить"
  prompt.position=actors[id].get_global_transform_with_canvas().origin+Vector2(-80,-78)
func _unhandled_key_input(event: InputEvent) -> void:
 if get_viewport().gui_get_focus_owner() is LineEdit:return
 if event is InputEventKey and event.pressed and not event.echo:
  if opened and event.physical_keycode in [KEY_ESCAPE,KEY_E]:close_dialogue();get_viewport().set_input_as_handled()
  elif event.physical_keycode==KEY_E and not nearest().is_empty():
   talk(nearest());get_viewport().set_input_as_handled()
