extends RefCounted
const CANOPY = preload("res://assets/recast/canopy.png")
const Trees = preload("res://data/trees.gd")

static func draw_tree(canvas: Node2D, record: Dictionary, time: float) -> void:
 var height: float = record.height * 16
 var wind := Trees.wind(record, time)
 var bark := Color("8e7354")
 var shade := Color("29383e")
 for segment in range(int(record.height)):
  var variant:=posmod(int(record.seed)+segment,4)
  canvas.draw_texture_rect_region(preload("res://assets/recast/bark.png"),Rect2(-6,-(segment+1)*16,12,16),Rect2(variant*12,0,12,16))
 canvas.draw_texture(preload("res://assets/recast/roots.png"),Vector2(-16,-15))
 for side in [-1, 1]:
  var joint := Vector2(side * 2, -height * 0.45)
  var elbow := Vector2(side * 15, -height * 0.61)
  var tip := Vector2(side * 27 + wind + sin(time*1.3+side+record.seed%13)*0.5, -height * 0.75)
  canvas.draw_line(joint,elbow,shade,5)
  canvas.draw_line(elbow,tip,shade,3)
  canvas.draw_line(joint + Vector2(0,-1),elbow + Vector2(0,-1),bark,2)
 var palettes := [ [Color("2e5150"),Color("466c64"),Color("7b977b")], [Color("3c5b51"),Color("557b71"),Color("9aa27b")], [Color("304c4b"),Color("4d6c57"),Color("71866a")]]
 var palette: Array = palettes[int(record.form)]
 if record.form == 2:
  # A tiered, narrow crown.
  for tier in range(3):
   var at := Vector2(wind * (1.0 - tier * 0.15), -height + tier * 17)
   _crown(canvas, at, Vector2(19 + tier * 5,19),palette,int(record.seed) + tier * 41)
 else:
  for side in [-1, 1]:
   _crown(canvas,Vector2(side * 23 + wind * (0.7 if side < 0 else 1.1),-height + 24 + side * 3),Vector2(24,19),palette,int(record.seed) + side * 37)
  _crown(canvas,Vector2(wind,-height + 4),Vector2(30 if record.form == 0 else 22,24),palette,int(record.seed))

 # A few slow falling leaves, sampled from the same world clock as wind.
 for i in range(3):
  var phase := fposmod(time*0.14+float(posmod(int(record.seed),93))/93.0+i*0.31,1.0)
  var at := Vector2((i-1)*18+sin(phase*TAU*1.5+i)*7,-height+22+phase*height*0.7)
  var color: Color = palette[2]
  color.a = sin(phase*PI)*0.65
  canvas.draw_line(at.round(),(at+Vector2(2,1 if i%2 else -1)).round(),color,1)

static func _crown(canvas: Node2D, at: Vector2, half: Vector2, colors: Array, seed_value: int) -> void:
 # Baked leaf planes become one textured quad, rather than 35 new shapes.
 var row := 0
 if colors[0] == Color("3c5b51"): row = 1
 elif colors[0] == Color("304c4b"): row = 2
 var source := Rect2(posmod(seed_value,4)*64,row*52,64,52)
 canvas.draw_texture_rect_region(CANOPY,Rect2(at.round()-Vector2(32,26),Vector2(64,52)),source)
