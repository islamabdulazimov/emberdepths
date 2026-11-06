extends Node2D
const Art = preload("res://scripts/visuals/art_direction.gd")
var world: Node2D
var edges: Node2D
var cached_region := Rect2i()
var dirty := true
var grass: Array[Vector2] = []
var veins: Array[Vector2] = []
var clock := 0.0
var rebuilds := 0
func _ready() -> void:
 world = get_parent()
 edges = Node2D.new()
 edges.set_script(preload("res://scripts/visuals/terrain_edges.gd"))
 add_child(edges)
func invalidate() -> void: dirty = true
func _process(delta: float) -> void:
 if not is_instance_valid(world.solid): return
 var bounds: Rect2 = (get_canvas_transform().affine_inverse()*get_viewport_rect()).grow(32)
 var first: Vector2i = world.cell_at(bounds.position)
 var last: Vector2i = world.cell_at(bounds.end)
 var region := Rect2i(first,last-first+Vector2i.ONE)
 if dirty or region != cached_region:
  cached_region = region
  _rebuild()
 clock += delta
 if clock >= 1.0/30:
  clock = fmod(clock,1.0/30)
  queue_redraw()
func _rebuild() -> void:
 dirty = false
 rebuilds += 1
 edges.rectangles.clear()
 edges.lines.clear()
 grass.clear()
 veins.clear()
 for y in range(maxi(0,cached_region.position.y),mini(world.world_depth,cached_region.end.y)):
  for x in range(maxi(0,cached_region.position.x),mini(world.world_width,cached_region.end.x)):
   var cell := Vector2i(x,y)
   var id: int = world.block_at(cell)
   if id < 0: continue
   var at := Vector2(cell)*16
   var h := posmod(x*73+y*137+world.world_seed,997)
   if world.block_at(cell+Vector2i.UP) < 0:
    edges.rectangles.append([Rect2(at,Vector2(16,1)),Art.MIST if id == 2 else Color("9c9877")])
    if id == 0:
     # Moss hangs over the soil edge; isolated tufts avoid a uniform comb.
     edges.rectangles.append([Rect2(at+Vector2(h%11,1),Vector2(3,3+h%3)),Art.JADE.darkened(0.25)])
     for i in range(3): grass.append(at+Vector2(posmod(h+i*7,14)+1,0))
   if world.block_at(cell+Vector2i.LEFT) < 0:
    edges.rectangles.append([Rect2(at,Vector2(1,16)),Art.SHADOW])
   if world.block_at(cell+Vector2i.RIGHT) < 0:
    edges.rectangles.append([Rect2(at+Vector2(15,1),Vector2(1,15)),Art.INK])
   if world.block_at(cell+Vector2i.DOWN) < 0:
    if world.generator_version >= 2 and world.region_at(cell) != "surface" and h%3 == 0:
     var tip := at+Vector2(5+h%6,20+h%5)
     edges.lines.append([at+Vector2(5,15),tip,Art.JADE.darkened(0.1) if world.region_at(cell) == "roots" else Art.MIST.darkened(0.25)])
    edges.rectangles.append([Rect2(at+Vector2(0,15),Vector2(16,1)),Art.INK])
   if id == 2 and h%4 == 0:
    var p := at+Vector2(3+h%7,4+h%5)
    edges.lines.append([p,p+Vector2(3,2),Art.SHADOW])
    edges.lines.append([p+Vector2(3,2),p+Vector2(5,1),Art.SHADOW])
   if id == 3: veins.append(at+Vector2(5,4))
 edges.queue_redraw()
 queue_redraw()
func _draw() -> void:
 var main := world.get_parent()
 var time: float = main.combat.world_time if is_instance_valid(main.get("combat")) else 0.0
 for at in grass:
  var bend := roundf(sin(time*1.2+at.x*0.025)*0.7)
  draw_line(at,at+Vector2(bend,-2-int(at.x)%2),Art.JADE.lightened(0.15),1)
 for at in veins:
  var glow := 0.3+sin(time*1.8+at.x*0.125+at.y*0.0625)*0.15
  draw_rect(Rect2(at,Vector2(2,1)),Color(0.95,0.70,0.43,glow))
