extends RefCounted
const Regions = preload("res://data/world_regions.gd")
# Version 2 is deterministic. Version 1 stays in World.generate for old saves.
static func put(world: Node2D, cell: Vector2i, id: int) -> void:
 if cell.x < 0 or cell.y < 0 or cell.x >= world.world_width or cell.y >= world.world_depth: return
 if id < 0: world.solid.erase_cell(cell)
 else:
  var d: Dictionary = world.Blocks.DEFINITIONS[id]
  world.solid.set_cell(cell,int(d.get("source",0)),d.atlas)
static func corridor(world: Node2D, x0: int, x1: int, floor_y: int, clearance: int = 4) -> void:
 for x in range(mini(x0,x1),maxi(x0,x1)+1):
  for y in range(floor_y-clearance,floor_y): put(world,Vector2i(x,y),-1)
  put(world,Vector2i(x,floor_y),2)
  put(world,Vector2i(x,floor_y+1),2)
static func stair(world: Node2D, start: Vector2i, length: int, descending: bool) -> void:
 for i in range(length):
  var floor_y := start.y+(i/2 if descending else -i/2)
  for y in range(floor_y-4,floor_y): put(world,Vector2i(start.x+i,y),-1)
  for y in range(floor_y,floor_y+2): put(world,Vector2i(start.x+i,y),2)
static func generate(world: Node2D) -> Array:
 var noise := FastNoiseLite.new()
 noise.seed = world.world_seed
 noise.frequency = 0.027
 var broad := FastNoiseLite.new()
 broad.seed = world.world_seed+41
 broad.frequency = 0.009
 var cave := FastNoiseLite.new()
 cave.seed = world.world_seed+1
 cave.frequency = 0.065
 for x in range(world.world_width):
  var distance := absi(x-world.world_width/2)
  var top := 22+roundi(noise.get_noise_1d(x)*10+broad.get_noise_1d(x)*12)
  top = clampi(roundi(lerpf(22,top,smoothstep(14,28,distance))),16,34)
  world.heights.append(top)
  for y in range(top,world.world_depth):
   var hash_value := posmod(x*31+y*17+world.world_seed,173)
   var id := 0 if y == top else (1 if y < top+6 else 2)
   var roots := y >= top+7 and y < 84
   if roots and hash_value < 10: id = 5
   if y > top+3 and hash_value%47 < (5 if y >= 84 else 2): id = 3
   if x == world.world_width/2+3 and y in [25,26]: id = 3
   world.walls.set_cell(Vector2i(x,y),3 if roots and hash_value < 12 else 0,Vector2i(0,0) if roots and hash_value < 12 else Vector2i(2,0))
   var empty: bool = y > top+8 and y < world.world_depth-3 and absf(cave.get_noise_2d(x,y)) < (0.145 if y >= 84 else 0.09)
   if not empty: put(world,Vector2i(x,y),id)
 # Two connected lateral cave trunks with occasional broad chambers.
 for x in range(20,world.world_width-20):
  for level in [55,112]:
   var mid: int = level+roundi(sin(x*0.035+world.world_seed%31)*6)
   for y in range(mid-2,mid+3): put(world,Vector2i(x,y),-1)
 var rng := RandomNumberGenerator.new()
 rng.seed = world.world_seed ^ 0x7a14
 for i in range(12):
  var center := Vector2i(rng.randi_range(26,world.world_width-26),rng.randi_range(88,world.world_depth-16))
  var radius := Vector2(rng.randi_range(8,16),rng.randi_range(4,8))
  for y in range(center.y-int(radius.y),center.y+int(radius.y)+1):
   for x in range(center.x-int(radius.x),center.x+int(radius.x)+1):
    if (Vector2(Vector2i(x,y)-center)/radius).length_squared() <= 1: put(world,Vector2i(x,y),-1)
  # Every chamber joins the deep trunk; no isolated reward pockets.
  var trunk_y := 112+roundi(sin(center.x*0.035+world.world_seed%31)*6)
  for y in range(mini(center.y,trunk_y),maxi(center.y,trunk_y)+1):
   for x in range(center.x-1,center.x+2): put(world,Vector2i(x,y),-1)
 # A recoverable staircase connects surface, roots and deep rock with the
 # existing jump. Its 16px rises are below the player's ~49px jump height.
 var start_x := 88+posmod(world.world_seed,3)
 var start_y: int = world.heights[start_x]
 stair(world,Vector2i(start_x,start_y),(123-start_y)*2+1,true)
 var sites: Array = []
 for entry in preload("res://data/exploration_sites.gd").DUNGEONS:
  var rect: Rect2i = entry[1]
  dungeon(world,rect,entry[0])
  var floor_y := rect.end.y-2
  var route_x := start_x+(floor_y-start_y)*2
  var portal_x := rect.end.x+18 if entry[0] == "root_shelter" else rect.position.x+1
  corridor(world,clampi(route_x,16,world.world_width-17),portal_x,floor_y,2)
  if entry[0] == "root_shelter":
   corridor(world,rect.end.x-2,rect.end.x+18,rect.position.y+rect.size.y/2)
   stair(world,Vector2i(rect.end.x+2,rect.position.y+rect.size.y/2),17,true)
  sites.append(site(entry[0],rect))
 for x in [22,world.world_width-72]:
  var top: int = world.heights[x+20]
  var rect := Rect2i(x,top-9,48,11)
  village(world,rect,world.world_seed+x)
  sites.append(site("settlement",rect))
 return sites
static func dungeon(world: Node2D, r: Rect2i, kind: String) -> void:
 for y in range(r.position.y,r.end.y):
  for x in range(r.position.x,r.end.x):
   var edge := y in [r.position.y,r.end.y-1] or x in [r.position.x,r.end.x-1]
   put(world,Vector2i(x,y),2 if edge else -1)
   world.walls.set_cell(Vector2i(x,y),3 if kind == "root_shelter" else 0,Vector2i(0,0) if kind == "root_shelter" else Vector2i(2,0))
 var middle := r.position.y+r.size.y/2
 corridor(world,r.position.x+1,r.end.x-2,middle)
 corridor(world,r.position.x+1,r.end.x-2,r.end.y-2)
 stair(world,Vector2i(r.position.x+4,r.end.y-2),(r.end.y-2-middle)*2+4,false)
 if kind == "well_archive":
  for y in range(r.position.y+1,r.end.y-2):
   for x in range(r.position.x+30,r.position.x+33): put(world,Vector2i(x,y),-1)
  # Small bridges remain jumpable across the central well.
  for y in [middle,r.end.y-2]:
   for x in range(r.position.x+29,r.position.x+34): put(world,Vector2i(x,y),2)
 var partition := r.end.x-(12 if kind == "root_shelter" else 10)
 for y in range(r.position.y+1,r.end.y-2):
  if y in range(middle-3,middle) or y in range(r.end.y-5,r.end.y-2): continue
  put(world,Vector2i(partition,y),2 if kind == "well_archive" else 5)
 # Side cache is reached through a short, deliberately open passage.
 corridor(world,r.end.x-10,r.end.x-2,middle)
static func village(world: Node2D, r: Rect2i, seed_value: int) -> void:
 var floor_y := r.end.y-2
 corridor(world,r.position.x,r.end.x-1,floor_y)
 for x in range(r.position.x,r.end.x): world.heights[x] = floor_y
 for i in range(3):
  var x0 := r.position.x+2+i*15+posmod(seed_value+i*7,2)
  var height := 5+posmod(seed_value+i,3)
  for y in range(floor_y-height,floor_y):
   for x in range(x0,x0+10):
    put(world,Vector2i(x,y),-1)
    world.walls.set_cell(Vector2i(x,y),2,Vector2i.ZERO)
  for y in range(floor_y-height,floor_y):
   if y < floor_y-3: put(world,Vector2i(x0,y),4)
   if y > floor_y-height+1: put(world,Vector2i(x0+9,y),4)
  for x in range(x0,x0+10):
   if posmod(seed_value+x,5) != 0: put(world,Vector2i(x,floor_y-height),4)
  # Workbench remains, a split shelf and a low threshold describe former use.
  put(world,Vector2i(x0+6,floor_y-1),4)
  if i == 1: put(world,Vector2i(x0+7,floor_y-2),4)
 # Graded approaches meet the surrounding surface, rather than floating houses.
 for side in [-1,1]:
  for i in range(12):
   var x := r.position.x-i-1 if side < 0 else r.end.x+i
   if x < 1 or x >= world.world_width-1: continue
   var y := roundi(lerpf(floor_y,world.heights[x],float(i+1)/12))
   corridor(world,x,x,y)
   world.heights[x] = y
static func site(kind: String, r: Rect2i) -> Dictionary:
 var bottom := r.end.y-3
 var middle := r.position.y+r.size.y/2-1
 var chests := [Vector2i(r.end.x-7,middle),Vector2i(r.end.x-7,bottom)] if kind != "settlement" else [Vector2i(r.position.x+4,bottom),Vector2i(r.position.x+20,bottom),Vector2i(r.position.x+35,bottom)]
 var guards: Array = []
 if kind == "root_shelter": guards = [["seamling",Vector2i(r.end.x-4,bottom)],["seamling",Vector2i(r.end.x-14,middle)]]
 if kind == "well_archive": guards = [["hollowbeak",Vector2i(r.position.x+8,middle)],["hollowbeak",Vector2i(r.position.x+22,bottom)],["void_collector",Vector2i(r.end.x-12,bottom)]]
 return {"id":"%s_%d" % [kind,r.position.x],"kind":kind,"rect":r,"chests":chests,"guards":guards}
