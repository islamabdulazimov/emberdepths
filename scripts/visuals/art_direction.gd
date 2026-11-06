extends RefCounted
# Emberglass: ash silhouettes, oxidised metal, porcelain light and copper embers.
# Presentation data only. No gameplay code or random world generation uses this.
const INK := Color("18252e")
const SHADOW := Color("293b46")
const SLATE := Color("455d68")
const MIST := Color("88aaa9")
const IVORY := Color("e1dec2")
const COPPER := Color("bd8058")
const EMBER := Color("f2b36e")
const COAL := Color("543d43")
const JADE := Color("57847a")

static func smooth(value: float) -> float:
 var t := clampf(value,0,1)
 return t*t*(3-2*t)

# Held anticipation, fast strike, long release. Shared by hand tools and melee.
static func stroke(value: float) -> float:
 var t := clampf(value,0,1)
 if t < 0.23: return lerpf(0,-0.15,smooth(t/0.23))
 if t < 0.55: return lerpf(-0.15,1,smooth((t-0.23)/0.32))
 return lerpf(1,0.86,smooth((t-0.55)/0.45))

static func panel(color: Color = INK, edge: Color = SLATE) -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color = color
 box.border_color = edge
 box.set_border_width_all(1)
 box.shadow_color=Color(0.02,0.04,0.07,0.6)
 box.shadow_size=2
 box.shadow_offset=Vector2(0,2)
 box.content_margin_left = 5
 box.content_margin_right = 5
 box.content_margin_top = 3
 box.content_margin_bottom = 3
 return box

static func theme() -> Theme:
 var result := Theme.new()
 var font:=preload("res://assets/recast/DejaVuSansMono.ttf")
 font.antialiasing=TextServer.FONT_ANTIALIASING_NONE
 result.default_font=font
 result.default_font_size = 12
 var skin:=StyleBoxTexture.new();skin.texture=preload("res://assets/recast/ui_panel.png")
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:skin.set_texture_margin(side,5);skin.set_content_margin(side,8)
 result.set_stylebox("panel","PanelContainer",skin)
 for state in ["normal","hover","pressed","disabled","focus"]:
  var color := INK if state == "normal" else SHADOW
  var edge := COPPER if state in ["hover","focus"] else SLATE
  if state == "pressed": color = JADE.darkened(0.45)
  if state == "disabled": color = INK.darkened(0.15)
  result.set_stylebox(state,"Button",panel(color,edge))
 result.set_color("font_color","Button",IVORY)
 result.set_color("font_hover_color","Button",IVORY.lightened(0.1))
 result.set_color("font_disabled_color","Button",SLATE.lightened(0.3))
 result.set_color("font_color","Label",IVORY)
 return result
