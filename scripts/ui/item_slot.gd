extends Button
var ui:CanvasLayer
var domain:="bag"
var index:=0
var gear_slot:=""
var item:=""
var amount:=0
var slot_number:=""
func _ready() -> void:
 focus_mode=Control.FOCUS_NONE
 mouse_entered.connect(func():ui.hover(self));mouse_exited.connect(func():ui.unhover(self))
func _draw() -> void:
 if item!="":
  var tex=preload("res://data/items.gd").icon(item)
  if tex!=null:draw_texture_rect(tex,Rect2((size-Vector2(28,28))/2-Vector2(0,2),Vector2(28,28)),false)
 elif domain=="gear":
  var ghost:={"weapon":"wood_sword","head":"wood_helm","body":"wood_armor","legs":"wood_legs","shield":"wood_shield"}
  draw_texture_rect(preload("res://data/items.gd").icon(ghost[gear_slot]),Rect2((size-Vector2(26,26))/2,Vector2(26,26)),false,Color(0.5,0.65,0.7,0.18))
 var font:Font=get_theme_font("font")
 if slot_number!="":draw_string(font,Vector2(4,11),slot_number,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("8fa09b"))
 if amount>1:
  var n:=str(amount);var pos:=Vector2(size.x-4-font.get_string_size(n,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x,size.y-4)
  draw_string_outline(font,pos,n,HORIZONTAL_ALIGNMENT_LEFT,-1,11,2,Color("131c27"));draw_string(font,pos,n,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f0dab1"))
func _get_drag_data(_at:Vector2) -> Variant:
 if item=="" or not ui.opened:return null
 var preview:=TextureRect.new();preview.texture=preload("res://data/items.gd").icon(item);preview.custom_minimum_size=Vector2(32,32);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;set_drag_preview(preview)
 ui.source_slot=-1
 return {"ui":ui,"domain":domain,"index":index,"slot":gear_slot,"item":item,"revision":ui.storage_revision}
func _can_drop_data(_at:Vector2,data:Variant) -> bool:return ui.can_drop(self,data)
func _drop_data(_at:Vector2,data:Variant) -> void:ui.drop(self,data)
