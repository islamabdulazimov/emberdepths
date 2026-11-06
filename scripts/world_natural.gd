extends RefCounted
const Stamp = preload("res://scripts/world_expansion.gd")
const Sizes = preload("res://data/world_sizes.gd")
static func trunk(world: Node2D,x: int,deep: bool) -> int:
 return int(world.world_depth*(0.70 if deep else 0.30))+roundi(sin(x*0.028+world.world_seed%37)*5)
static func put(world: Node2D,cell: Vector2i,id: int) -> void: Stamp.put(world,cell,id)
static func generate(world: Node2D) -> Array:
 var noise := FastNoiseLite.new()
 noise.seed = world.world_seed
 noise.frequency = 0.024
 var broad := FastNoiseLite.new()
 broad.seed = world.world_seed+41
 broad.frequency = 0.006
 var cave := FastNoiseLite.new()
 cave.seed = world.world_seed+1
 cave.frequency = 0.061
 var deep_start: int = world.world_depth/2
 for x in range(world.world_width):
  var h := clampi(22+roundi(noise.get_noise_1d(x)*11+broad.get_noise_1d(x)*14),16,36)
  h = roundi(lerpf(22,h,smoothstep(14,28,absi(x-world.world_width/2))))
  world.heights.append(h)
  for y in range(h,world.world_depth):
   var hash_value := posmod(x*31+y*17+world.world_seed,173)
   var roots := y >= h+7 and y < deep_start
   var id := 0 if y == h else (1 if y < h+6 else 2)
   if roots and hash_value < 10: id = 5
   if y > h+3 and hash_value%47 < (5 if y >= deep_start else 2): id = 3
   world.walls.set_cell(Vector2i(x,y),3 if roots and hash_value < 12 else 0,Vector2i.ZERO if roots and hash_value < 12 else Vector2i(2,0))
   if not (y > h+8 and y < world.world_depth-3 and absf(cave.get_noise_2d(x,y)) < (0.15 if y >= deep_start else 0.095)): put(world,Vector2i(x,y),id)
 # Organic cave trunks: clear air, never lay continuous manufactured stone roads.
 for x in range(16,world.world_width-16):
  for deep in [false,true]:
   var mid := trunk(world,x,deep)
   for y in range(mid-2,mid+3): put(world,Vector2i(x,y),-1)
 var rng := RandomNumberGenerator.new()
 rng.seed = world.world_seed ^ 0x761a
 for i in range(12 if world.world_width <= 512 else 22):
  var center := Vector2i(rng.randi_range(24,world.world_width-25),rng.randi_range(deep_start+4,world.world_depth-16))
  var radius := Vector2(rng.randi_range(7,16),rng.randi_range(4,8))
  for y in range(center.y-int(radius.y),center.y+int(radius.y)+1):
   for x in range(center.x-int(radius.x),center.x+int(radius.x)+1):
    if (Vector2(Vector2i(x,y)-center)/radius).length_squared() <= 1: put(world,Vector2i(x,y),-1)
  var target := trunk(world,center.x,true)
  for y in range(mini(target,center.y),maxi(target,center.y)+1):
   var bend := roundi(sin(y*0.1+i)*2)
   for x in range(center.x+bend-1,center.x+bend+2): put(world,Vector2i(x,y),-1)
 # A natural stepped opening near the start joins both trunks; remaining rock
 # supports retain their actual material. No map-wide structure corridor.
 var start_x: int = world.world_width/2-64
 var start_y: int = world.heights[start_x]
 for y in range(start_y-2,int(world.world_depth*0.75)):
  var x := start_x+int((y-start_y)*1.7)
  for dx in range(-2,3):
   for dy in range(-3,1): put(world,Vector2i(x+dx,y+dy),-1)
 var sites := plan(world,rng)
 for site in sites:
  if site.kind == "settlement": village(world,site.rect,world.world_seed+site.rect.position.x)
  else:
   Stamp.dungeon(world,site.rect,site.kind)
   var floor_y: int = site.rect.end.y-2
   Stamp.corridor(world,site.rect.position.x-7,site.rect.position.x+2,floor_y,4)
 return sites
static func plan(world: Node2D,rng: RandomNumberGenerator) -> Array:
 var config: Dictionary = Sizes.DEFINITIONS["small" if world.world_width == 512 else "large"]
 var result: Array = []
 var center: int = world.world_width/2
 # First inhabited settlement has a guaranteed accessible surface reservation.
 var first_x := center-136+rng.randi_range(-8,8)
 var floor_y: int = world.heights[first_x+20]
 var inhabited := Stamp.site("settlement",Rect2i(first_x,floor_y-9,48,11))
 inhabited.inhabited = true
 result.append(inhabited)
 if int(config.settlements) == 2:
  var x := center+112+rng.randi_range(-8,8)
  var r := Rect2i(x,world.heights[x+20]-9,48,11)
  if fits(world,r,result): result.append(Stamp.site("settlement",r))
 for index in range(int(config.dungeons)):
  var kind := "root_shelter" if index%2 == 0 else "well_archive"
  for attempt in range(160):
   var x := rng.randi_range(20,world.world_width-70)
   var h := 20 if kind == "root_shelter" else 26
   var floor_at := trunk(world,x,kind == "well_archive")+3
   var top := maxi(world.heights[x+20]+7,floor_at-(h-2))
   var rect := Rect2i(x,top,42 if kind == "root_shelter" else 44,h)
   if fits(world,rect,result):
    result.append(Stamp.site(kind,rect))
    break
 return result
static func fits(world: Node2D,r: Rect2i,sites: Array) -> bool:
 if r.position.x < 12 or r.end.x > world.world_width-12 or r.end.y > world.world_depth-8: return false
 var safe := Rect2i(world.world_width/2-25,0,50,43)
 if safe.intersects(r.grow(4)): return false
 for site in sites:
  if not Sizes.separated(r,site.rect): return false
 return true
static func village(world: Node2D,r: Rect2i,seed_value: int) -> void:
 var floor_y := r.end.y-2
 # Clear the whole footprint before placing houses, including the courtyard.
 for x in range(r.position.x-10,r.end.x+10):
  var old: int = world.heights[x]
  var target := floor_y
  if x < r.position.x: target = roundi(lerpf(old,floor_y,float(x-r.position.x+10)/10))
  elif x >= r.end.x: target = roundi(lerpf(floor_y,old,float(x-r.end.x+1)/10))
  for y in range(mini(old,r.position.y-3),target): put(world,Vector2i(x,y),-1)
  for y in range(target,maxi(old,target)+4): put(world,Vector2i(x,y),0 if y == target else 1)
  world.heights[x] = target
 for i in range(3):
  var x0 := r.position.x+2+i*15+posmod(seed_value+i,2)
  var h := 5+posmod(seed_value+i*3,3)
  for y in range(floor_y-h,floor_y):
   for x in range(x0,x0+10):
    put(world,Vector2i(x,y),-1)
    world.walls.set_cell(Vector2i(x,y),2,Vector2i.ZERO)
  for y in range(floor_y-h,floor_y-3):
   put(world,Vector2i(x0,y),4)
   put(world,Vector2i(x0+9,y),4)
  for x in range(x0,x0+10):
   if i == 0 or posmod(x+seed_value,7) != 0: put(world,Vector2i(x,floor_y-h),4)
  put(world,Vector2i(x0+6,floor_y-1),4)
  if i == 1: put(world,Vector2i(x0+7,floor_y-2),4)
static func residents(sites: Array) -> Dictionary:
 for site in sites:
  if site.get("inhabited",false):
   var result := {}
   for entry in [["julia",6],["cameron",19]]:
    var position := Vector2((site.rect.position.x+int(entry[1]))*16+8,(site.rect.end.y-2)*16-10)
    result[entry[0]] = {"id":entry[0],"position":position,"home":position,"site":site.id}
   return result
 return {}
