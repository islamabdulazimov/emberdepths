extends Node2D
const Art = preload("res://scripts/visuals/art_direction.gd")
var world: Node2D
func _ready() -> void:
 world = get_parent()
 z_index = 0
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
 if not is_instance_valid(world.solid): return
 var bounds: Rect2 = (get_canvas_transform().affine_inverse()*get_viewport_rect()).grow(32)
 var first: Vector2i = world.cell_at(bounds.position)
 var last: Vector2i = world.cell_at(bounds.end)
 var main := world.get_parent()
 var time: float = main.combat.world_time if is_instance_valid(main.get("combat")) else 0.0
 for y in range(maxi(0,first.y),mini(world.world_depth,last.y+1)):
  for x in range(maxi(0,first.x),mini(world.world_width,last.x+1)):
   var cell := Vector2i(x,y)
   var id: int = world.block_at(cell)
   if id < 0: continue
   var at := Vector2(cell)*16
   var exposed: bool = world.block_at(cell+Vector2i.UP) < 0
   var hash_value := posmod(x*73+y*137+world.world_seed,997)
   if exposed:
    draw_rect(Rect2(at,Vector2(16,1)),Art.MIST if id == 2 else Color("9c9877"))
    if id == 0:
     for i in range(3):
      var offset := posmod(hash_value+i*7,14)+1
      var bend := roundf(sin(time*1.2+x*0.4+i)*0.7)
      draw_line(at+Vector2(offset,0),at+Vector2(offset+bend,-2-i%2),Art.JADE.lightened(0.15),1)
   if world.block_at(cell+Vector2i.LEFT) < 0: draw_rect(Rect2(at,Vector2(1,16)),Art.SHADOW)
   if world.block_at(cell+Vector2i.RIGHT) < 0: draw_rect(Rect2(at+Vector2(15,1),Vector2(1,15)),Art.INK)
   if world.block_at(cell+Vector2i.DOWN) < 0: draw_rect(Rect2(at+Vector2(0,15),Vector2(16,1)),Art.INK)
   if id == 2 and hash_value%4 == 0:
    var p := at+Vector2(3+hash_value%7,4+hash_value%5)
    draw_line(p,p+Vector2(3,2),Art.SHADOW,1)
    draw_line(p+Vector2(3,2),p+Vector2(5,1),Art.SHADOW,1)
   if id == 3:
    var glow := 0.3+sin(time*1.8+x*2+y)*0.15
    draw_rect(Rect2(at+Vector2(5,4),Vector2(2,1)),Color(0.95,0.70,0.43,glow))
