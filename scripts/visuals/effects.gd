extends Node2D
const Art = preload("res://scripts/visuals/art_direction.gd")
const MAX_PARTICLES := 256
const MAX_RINGS := 16
var ghosts: Array = []
var particles: Array = []
var rings: Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
 z_index = 6
 rng.seed = 71693 # Local cosmetic RNG, never the gameplay RNG.

func clear() -> void:
 for child in get_children(): child.queue_free()
 ghosts.clear()
 particles.clear()
 rings.clear()
 queue_redraw()

func burst(kind: String, at: Vector2, direction: Vector2 = Vector2.UP) -> void:
 var count := 7
 var color := Art.COPPER
 var gravity := 70.0
 var speed := 24.0
 var life := 0.45
 match kind:
  "step":
   count = 3
   color = Art.MIST.darkened(0.2)
   speed = 10
   life = 0.25
  "land": count = 9
  "mine":
   count = 9
   color = Art.SLATE.lightened(0.25)
   speed = 34
  "place":
   count = 6
   color = Art.MIST
   gravity = 0
   speed = 12
   life = 0.3
  "hurt":
   count = 9
   color = Art.EMBER
   speed = 45
   life = 0.25
  "death", "spirit":
   count = 22
   color = Art.IVORY if kind == "spirit" else Art.MIST
   gravity = -15
   speed = 24
   life = 0.85
  "heal", "respawn":
   count = 15
   color = Art.IVORY if kind == "respawn" else Art.JADE.lightened(0.4)
   gravity = -18
   speed = 14
   life = 0.7
  "impact":
   count = 30
   color = Art.EMBER
   speed = 60
   life = 0.65
  "leaf":
   count = 12
   color = Art.JADE
   speed = 16
   gravity = 12
   life = 0.9
 if kind in ["heal","respawn","impact","spirit"]:
  if rings.size() >= MAX_RINGS: rings.pop_front()
  rings.append({"position":at,"age":0.0,"life":life,"color":color,"radius":32.0 if kind == "impact" else 17.0})
 for i in range(count):
  if particles.size() >= MAX_PARTICLES: particles.pop_front()
  var velocity := direction.normalized().rotated(rng.randf_range(-1.4,1.4))*rng.randf_range(speed*0.3,speed)
  particles.append({"position":at+Vector2(rng.randf_range(-4,4),rng.randf_range(-2,2)),"velocity":velocity,"age":0.0,"life":life*rng.randf_range(0.65,1.2),"gravity":gravity,"color":color.lerp(Art.IVORY,rng.randf()*0.25),"size":2 if i%3 else 1})

func boss_death(at: Vector2,facing: int) -> void:
 var echo:=Node2D.new();echo.set_script(preload("res://scripts/visuals/boss_death.gd"));echo.position=at;echo.facing=facing;add_child(echo)

func creature_death(kind: String,at: Vector2,facing: int) -> void:
 if ghosts.size()>=16:ghosts.pop_front()
 ghosts.append({"kind":kind,"position":at,"facing":facing,"age":0.0})

func _process(delta: float) -> void:
 for i in range(ghosts.size()-1,-1,-1):
  ghosts[i].age+=delta
  if ghosts[i].age>=0.5:ghosts.remove_at(i)
 for i in range(particles.size()-1,-1,-1):
  var p: Dictionary = particles[i]
  p.age += delta
  if p.age >= p.life:
   particles.remove_at(i)
   continue
  p.velocity.y += p.gravity*delta
  p.position += p.velocity*delta
 for i in range(rings.size()-1,-1,-1):
  rings[i].age += delta
  if rings[i].age >= rings[i].life: rings.remove_at(i)
 queue_redraw()

func _draw() -> void:
 for ghost in ghosts:
  preload("res://scripts/visuals/actor_atlas.gd").draw_frame(self,ghost.kind,6,int(ghost.age/0.5*8),ghost.position,ghost.facing,1-ghost.age/0.5)
 for p in particles:
  var color: Color = p.color
  color.a = 1-smoothstep(0.35,1,p.age/p.life)
  draw_rect(Rect2(Vector2(p.position).round(),Vector2.ONE*p.size),color)
 for ring in rings:
  var t: float = ring.age/ring.life
  var color: Color = ring.color
  color.a = (1-t)*0.4
  # Broken diamond rings are the common visual motif, not smooth vector halos.
  var r: float = lerpf(3,ring.radius,Art.smooth(t))
  for i in range(4):
   var a: Vector2 = ring.position+Vector2.from_angle(PI*0.5*i)*r
   var b: Vector2 = ring.position+Vector2.from_angle(PI*0.5*(i+1))*r
   draw_line(a.round(),a.lerp(b,0.72).round(),color,1)

func hero_death(body:Node2D) -> void:
 var echo:=Node2D.new();echo.set_script(preload("res://scripts/visuals/hero_death.gd"));echo.position=body.position;echo.appearance=body.appearance.duplicate();echo.equipment=body.equipment.duplicate();echo.bare=body.unclothed;echo.facing=body.facing;add_child(echo)
