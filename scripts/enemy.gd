extends CharacterBody2D
var kind := "ashling"
var health := 45
var max_health := 45
var base_health := 45
var scaling_players := 1
var anchor := Vector2.ZERO
var grace := 0.0
var hurt_flash := 0.0
var hit_stun := 0.0
var clock := 0.0
var night := false
var visual_facing := 1
var visual_target_facing := 1
var visual_turn_age := 0.1
var visual_width := 1.0
var visual_anticipation := 0.0
var visual_movement := 0.0
var motion_track = preload("res://scripts/visuals/motion_track.gd").new()
var visual_health := -1

func _ready() -> void:
 collision_layer = 8
 collision_mask = 0 if kind == "spirit" else 1
 var collider := CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 shape.size = Vector2(14, 12)
 collider.shape = shape
 collider.position = Vector2(0, -6)
 add_child(collider)
 z_index = 3

func _process(delta: float) -> void:
 if visual_health >= 0 and health < visual_health:
  var main := get_parent().get_parent()
  if is_instance_valid(main.get("effects")): main.effects.burst("hurt",position+Vector2(0,-6))
 visual_health = health
 if not get_parent().authoritative(): attack_elapsed += delta
 var duration: float = Battle.ASHLING.windup if attack_state == "windup" else (Battle.ASHLING.active if attack_state == "active" else Battle.ASHLING.recovery)
 var t: float = motion_track.advance(attack_state,attack_elapsed,delta,duration)/duration
 var target := 0.0
 if attack_state == "windup": target = smoothstep(0,1,t)
 elif attack_state == "active": target = lerpf(1,-0.45,smoothstep(0,0.65,t))
 elif attack_state == "recovery": target = -0.45*(1-smoothstep(0,0.65,t))
 visual_anticipation = lerpf(visual_anticipation,target,1-exp(-36*delta))
 visual_movement = lerpf(visual_movement,velocity.x,1-exp(-22*delta))
 var target_face := attack_facing if attack_state != "chase" else (-1 if velocity.x < -1 else (1 if velocity.x > 1 else visual_target_facing))
 if target_face != visual_target_facing:
  visual_target_facing = target_face
  visual_turn_age = 0
 visual_turn_age = minf(0.1,visual_turn_age+delta)
 if visual_turn_age >= 0.05: visual_facing = visual_target_facing
 visual_width = 1-sin(visual_turn_age/0.1*PI)*0.65
 clock += delta
 hurt_flash = maxf(0.0, hurt_flash - delta)
 queue_redraw()

func _draw() -> void:
 var art = preload("res://scripts/visuals/enemy_art.gd")
 if kind == "spirit": art.draw_spirit(self,clock,velocity,hurt_flash)
 else:
  art.draw_ashling(self,clock,Vector2(visual_movement,velocity.y),hurt_flash,night,visual_facing,visual_anticipation,visual_width)
  if attack_state in ["windup","active"]:
   var color := Color("bd8058") if attack_state == "windup" else Color("e1dec2")
   draw_line(Vector2(attack_facing*9,-7),Vector2(attack_facing*Battle.ASHLING.reach,-7),Color(color,0.35),1)
   draw_rect(Rect2(attack_facing*10-1,-18,3,4),color)
  if attack_state == "stagger":
   draw_line(Vector2(-3,-20),Vector2(3,-24),Color("e1dec2"),2)
 draw_rect(Rect2(-8,-23,16,2),Color("18252e"))
 draw_rect(Rect2(-8,-23,16*float(health)/max_health,2),Color("bd8058") if kind == "ashling" else Color("88aaa9"))

# Host-owned attack states; damage is confined to the active phase, never touch.
const Battle = preload("res://data/battle.gd")
var entity_id := -1
var attack_state := "chase"
var attack_elapsed := 0.0
var attack_facing := 1
var attack_hits: Dictionary = {}

func change_attack(value: String) -> void:
 attack_state = value
 attack_elapsed = 0
 attack_hits.clear()
 var combat := get_parent()
 combat.entity_changed.emit(entity_id,combat.entity_data(entity_id))

func receive_parry() -> void:
 hit_stun = Battle.PARRY.enemy_stagger
 change_attack("stagger")

func attack_area() -> Rect2:
 return Rect2(position+Vector2(1 if attack_facing > 0 else -Battle.ASHLING.reach,-22),Vector2(Battle.ASHLING.reach,25))

func step_attack(delta: float, target: CharacterBody2D, combat: Node2D) -> bool:
 attack_elapsed += delta
 if attack_state == "stagger":
  velocity.x = 0
  if attack_elapsed >= Battle.PARRY.enemy_stagger: change_attack("chase")
  return true
 if attack_state == "chase":
  if target != null and grace <= 0 and hit_stun <= 0 and absf(target.position.x-position.x) <= Battle.ASHLING.stop_distance and absf(target.position.y+4-position.y) < 24 and combat.line_clear(position+Vector2(0,-7),target.position+Vector2(0,-5)):
   attack_facing = 1 if target.position.x >= position.x else -1
   change_attack("windup")
   velocity.x = 0
   return true
  return false
 velocity.x = 0
 if attack_state == "windup" and attack_elapsed >= Battle.ASHLING.windup: change_attack("active")
 elif attack_state == "active":
  for body in combat.main.get_node("Players").get_children():
   var id := int(str(body.name))
   if body.dead or attack_hits.has(id): continue
   var collider: CollisionShape2D = body.get_node("Collision")
   if not attack_area().intersects(collider.global_transform*collider.shape.get_rect()): continue
   if not combat.line_clear(position+Vector2(0,-7),body.position+Vector2(0,-5)): continue
   var damage: int = combat.Rules.ENEMIES[kind].night_damage if night else combat.Rules.ENEMIES[kind].day_damage
   var result: String = combat.receive_attack(id,damage,position,self)
   attack_hits[id] = true
   if attack_state != "active": break
  if attack_state == "active" and attack_elapsed >= Battle.ASHLING.active: change_attack("recovery")
 elif attack_state == "recovery" and attack_elapsed >= Battle.ASHLING.recovery: change_attack("chase")
 return true
