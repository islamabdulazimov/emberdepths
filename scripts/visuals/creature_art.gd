extends RefCounted
const Creatures = preload("res://data/creatures.gd")
const TEXTURES := {"seamling":preload("res://assets/creatures/seamling.svg"),"hollowbeak":preload("res://assets/creatures/hollowbeak.svg"),"ashweaver":preload("res://assets/creatures/ashweaver.svg"),"void_collector":preload("res://assets/creatures/void_collector.svg")}
static func draw_body(canvas: Node2D) -> void:
 var frame := 0
 if canvas.attack_state == "windup": frame = 1
 elif canvas.attack_state == "active": frame = 2
 elif canvas.attack_state in ["recovery","stagger"]: frame = 3
 var squash := Vector2(1+canvas.visual_anticipation*0.04,1-canvas.visual_anticipation*0.06)
 var bob := sin(canvas.clock*8)*minf(0.65,absf(canvas.visual_movement)*0.012)
 canvas.draw_set_transform(Vector2(0,-absf(bob)),0,squash*Vector2(canvas.visual_facing*canvas.visual_width,1))
 canvas.draw_texture_rect_region(TEXTURES[canvas.kind],Rect2(-32,-46,64,48),Rect2(frame*64,0,64,48),Color.WHITE.lerp(Color("efd0af"),minf(0.7,canvas.hurt_flash*4)))
 canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
 if preload("res://data/presentation.gd").combat_debug and canvas.attack_state in ["windup","active"]:
  var area: Rect2 = canvas.attack_area()
  area.position -= canvas.position
  var color := Color("e1dec2") if canvas.attack_state == "active" else Color("bd8058")
  canvas.draw_rect(area,Color(color,0.08 if canvas.attack_state == "windup" else 0.18))
  canvas.draw_line(area.position+Vector2(0,area.size.y),area.end,color,1)
  if canvas.kind == "hollowbeak":
   var reach: float = area.size.x
   for i in range(3):
    var x: float = canvas.attack_facing*reach*(0.5+i*0.25)
    canvas.draw_line(Vector2(x,-22),Vector2(x+canvas.attack_facing*3,-12),Color(color,0.65),1)
    canvas.draw_line(Vector2(x+canvas.attack_facing*3,-12),Vector2(x,-2),Color(color,0.65),1)
