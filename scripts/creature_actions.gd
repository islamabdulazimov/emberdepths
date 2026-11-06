extends RefCounted
const Creatures = preload("res://data/creatures.gd")
static func area(enemy: CharacterBody2D) -> Rect2:
 var d: Dictionary = Creatures.DEFINITIONS[enemy.kind]
 var reach: float = d.reach
 if enemy.kind == "hollowbeak" and enemy.attack_state == "active": reach *= clampf(enemy.attack_elapsed/float(d.active),0.15,1)
 return Rect2(enemy.position+Vector2(0 if enemy.attack_facing > 0 else -reach,-maxf(d.size.y,24)),Vector2(reach,maxf(d.size.y,24)+3))
static func step(enemy: CharacterBody2D, delta: float, target: CharacterBody2D, combat: Node2D) -> bool:
 var d: Dictionary = Creatures.DEFINITIONS[enemy.kind]
 enemy.attack_elapsed += delta
 if enemy.attack_state == "stagger":
  enemy.velocity.x = 0
  if enemy.attack_elapsed >= 1.0: enemy.change_attack("chase")
  return true
 if enemy.attack_state == "chase":
  if target != null and enemy.grace <= 0 and enemy.hit_stun <= 0 and enemy.position.distance_to(target.position) <= float(d.detect) and absf(enemy.position.y-target.position.y) < (96 if enemy.kind == "ashweaver" else 32) and combat.line_clear(enemy.position+Vector2(0,-10),target.position+Vector2(0,-5)):
   enemy.attack_facing = 1 if target.position.x >= enemy.position.x else -1
   enemy.attack_target = target.position+Vector2(0,-5)
   enemy.change_attack("windup")
   enemy.velocity = Vector2.ZERO
   return true
  return false
 if enemy.attack_state == "windup":
  enemy.velocity.x = 0
  if enemy.kind == "ashweaver": enemy.velocity.y = 0
  if enemy.attack_elapsed >= float(d.windup): enemy.change_attack("active")
 elif enemy.attack_state == "active":
  if enemy.kind == "ashweaver":
   if enemy.attack_elapsed <= delta+0.0001:
    enemy.velocity = (enemy.attack_target-(enemy.position+Vector2(0,-6))).normalized()*float(d.dash)
  else: enemy.velocity.x = enemy.attack_facing*float(d.dash)
  for body in combat.main.get_node("Players").get_children():
   var id := int(str(body.name))
   if body.dead or enemy.attack_hits.has(id): continue
   var collider: CollisionShape2D = body.get_node("Collision")
   if not area(enemy).intersects(collider.global_transform*collider.shape.get_rect()): continue
   if not combat.line_clear(enemy.position+Vector2(0,-10),body.position+Vector2(0,-5)): continue
   combat.receive_attack(id,int(d.damage),enemy.position,enemy,true)
   enemy.attack_hits[id] = true
   if enemy.attack_state != "active": break
  if enemy.attack_state == "active" and enemy.attack_elapsed >= float(d.active):
   enemy.velocity = Vector2.ZERO
   enemy.change_attack("recovery")
 elif enemy.attack_state == "recovery":
  enemy.velocity.x = 0
  if enemy.attack_elapsed >= float(d.recovery): enemy.change_attack("chase")
 return true
