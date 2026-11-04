extends RefCounted
const Trees = preload("res://data/trees.gd")

static func draw_tree(canvas: Node2D, record: Dictionary, time: float) -> void:
 var height: float = record.height * 16
 var wind := Trees.wind(record, time)
 var bark := Color("80624f") if record.form != 1 else Color("a8a18a")
 var shade := Color("29383e")
 # Fixed roots, tapering trunk, branch tips moving independently of the base.
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-9,1),Vector2(-4,-9),Vector2(-3,-height),Vector2(2,-height-3),Vector2(5,-8),Vector2(10,1)]), shade)
 canvas.draw_colored_polygon(PackedVector2Array([Vector2(-5,0),Vector2(-2,-height),Vector2(1,-height),Vector2(3,-9),Vector2(6,0)]), bark)
 for i in range(2, int(height) - 8, 8):
  var offset := posmod(i * 13 + int(record.seed), 3) - 1
  canvas.draw_rect(Rect2(offset,-i,2,4),bark.lightened(0.12) if i % 3 else shade)
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
 at = at.round()
 var w := half.x
 var h := half.y
 var outline := PackedVector2Array([Vector2(-w,-h*0.3),Vector2(-w+5,-h*0.3),Vector2(-w+5,-h*0.7),Vector2(-w+12,-h*0.7),Vector2(-w+12,-h),Vector2(w-12,-h),Vector2(w-12,-h*0.8),Vector2(w-5,-h*0.8),Vector2(w-5,-h*0.4),Vector2(w,-h*0.4),Vector2(w,h*0.4),Vector2(w-6,h*0.4),Vector2(w-6,h*0.7),Vector2(w-14,h*0.7),Vector2(w-14,h),Vector2(-w+10,h),Vector2(-w+10,h*0.7),Vector2(-w,h*0.7)])
 var shifted := PackedVector2Array()
 for point in outline: shifted.append(at + point.round())
 canvas.draw_colored_polygon(shifted,colors[0])
 # Small connected leaf planes; deterministic texture, never random per frame.
 for i in range(35):
  var x := float(posmod(seed_value * 13 + i * 113, int(w * 1.6))) - w * 0.8
  var y := float(posmod(seed_value * 7 + i * 47, int(h * 1.4))) - h * 0.85
  if Vector2(x / w, y / h).length_squared() > 0.85: continue
  var color: Color = colors[2] if i % 4 == 0 else colors[1]
  canvas.draw_rect(Rect2((at + Vector2(x,y)).snapped(Vector2(2,2)),Vector2(6 + i % 3 * 2,3 + i % 2)),color)
