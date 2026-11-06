extends Node2D
signal entity_changed(id: int, data: Dictionary)
signal chest_changed(id: int, data: Dictionary)
signal player_changed(id: int, data: Dictionary)
const Battle = preload("res://data/battle.gd")
const Rules = preload("res://data/combat_rules.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Chest = preload("res://scripts/death_chest.gd")
var main: Node2D
var world_time := 0.0
var entities: Dictionary = {}
var chests: Dictionary = {}
var next_entity_id := 1
var next_chest_id := 1
var remote_targets: Dictionary = {}
var spawning_enabled := true
var spawn_timer := 40.0
var last_night := false
var spawn_sequence := 0

func _ready() -> void:
 main = get_parent()
 main.items.attack_started.connect(resolve_attack)

func authoritative() -> bool:
 return is_instance_valid(main.network) and not main.network.stopping and (not main.network.active or (main.network.connected and multiplayer.is_server()))

func is_night() -> bool:
 return fposmod(world_time, Rules.CYCLE_SECONDS) >= Rules.DAY_SECONDS

func time_label() -> String:
 var phase := fposmod(world_time, Rules.CYCLE_SECONDS)
 var day := floori(world_time / Rules.CYCLE_SECONDS) + 1
 return ("Ночь %d · рассвет через %d с" % [day, ceili(Rules.CYCLE_SECONDS - phase)]) if is_night() else ("День %d · ночь через %d с" % [day, ceili(Rules.DAY_SECONDS - phase)])

func enemy_speed(kind: String) -> float:
 return float(Rules.ENEMIES[kind].night_speed if is_night() else Rules.ENEMIES[kind].day_speed)

func spawn_entity(kind: String, at: Vector2, anchor: Vector2 = Vector2.ZERO) -> int:
 if not authoritative() or not Rules.ENEMIES.has(kind):
  return -1
 var id := next_entity_id
 next_entity_id += 1
 var base: int = Rules.ENEMIES[kind].health
 var players := connected_player_count()
 var health: int = Rules.scaled_health(base, players)
 set_entity(id, {"kind": kind, "position": at, "velocity": Vector2.ZERO, "health": health, "base_health": base, "max_health": health, "scaling_players": players, "anchor": anchor, "grace": 1.2 if kind == "spirit" else 0.8})
 entity_changed.emit(id, entity_data(id))
 return id

func entity_data(id: int) -> Dictionary:
 var body = entities[id]
 return {"kind": body.kind, "position": body.position, "velocity": body.velocity, "health": body.health, "base_health": body.base_health, "max_health": body.max_health, "scaling_players": body.scaling_players, "anchor": body.anchor, "grace": body.grace, "clock": body.clock, "hit_stun": body.hit_stun, "attack_target":body.attack_target,"site_guard":body.site_guard,"attack_state":body.attack_state,"attack_elapsed":body.attack_elapsed,"attack_facing":body.attack_facing}

func set_entity(id: int, data: Dictionary, visual_remove: bool = false) -> void:
 if data.is_empty():
  if entities.has(id):
   if visual_remove and is_instance_valid(main.get("effects")):
    main.effects.creature_death(entities[id].kind,entities[id].position,entities[id].visual_facing)
    main.effects.burst("spirit" if entities[id].kind == "spirit" else "death",entities[id].position+Vector2(0,-5))
   remove_child(entities[id])
   entities[id].queue_free()
   entities.erase(id)
  remote_targets.erase(id)
  return
 var new_entity := not entities.has(id)
 if new_entity:
  var body := CharacterBody2D.new()
  body.set_script(Enemy)
  body.kind = data.kind
  body.entity_id = id
  body.max_health = int(data.get("max_health", Rules.ENEMIES[data.kind].health))
  add_child(body)
  entities[id] = body
 var body = entities[id]
 if not new_entity and body.health > int(data.health):
  body.hurt_flash = 0.16
 body.base_health = int(data.get("base_health", Rules.ENEMIES[data.kind].health))
 body.scaling_players = int(data.get("scaling_players", 1))
 body.max_health = int(data.get("max_health", body.base_health))
 body.health = data.health
 body.position = data.position
 body.velocity = data.velocity
 body.anchor = data.anchor
 body.attack_target = data.get("attack_target",body.position)
 body.site_guard = bool(data.get("site_guard",false))
 body.grace = data.get("grace", 0.0)
 body.clock = data.get("clock", 0.0)
 body.hit_stun = data.get("hit_stun", 0.0)
 body.attack_state = data.get("attack_state","chase")
 body.attack_elapsed = float(data.get("attack_elapsed",0))
 body.attack_facing = int(data.get("attack_facing",1))
 next_entity_id = maxi(next_entity_id, id + 1)

func chest_data(id: int, include_contents: bool = false) -> Dictionary:
 var chest = chests[id]
 var data := {"position": chest.position, "owner": chest.owner_id, "profile": chest.owner_profile}
 if include_contents:
  data["contents"] = chest.contents.duplicate(true)
 return data

func set_chest(id: int, data: Dictionary) -> void:
 if data.is_empty():
  if chests.has(id):
   remove_child(chests[id])
   chests[id].queue_free()
   chests.erase(id)
  return
 if not chests.has(id):
  var chest := Node2D.new()
  chest.set_script(Chest)
  add_child(chest)
  chests[id] = chest
 chests[id].position = data.position
 chests[id].owner_id = data.owner
 chests[id].owner_profile = data.get("profile", "")
 chests[id].contents = data.get("contents", []).duplicate(true)
 next_chest_id = maxi(next_chest_id, id + 1)

func chest_at(cell: Vector2i) -> int:
 for id in chests:
  if main.world.cell_at(chests[id].position) == cell:
   return id
 return -1

func enemy_at(cell: Vector2i) -> int:
 var area := Rect2(main.world.cell_center(cell) - Vector2(8, 8), Vector2(16, 16))
 for id in entities:
  var enemy = entities[id]
  var bounds := Rect2(enemy.position+Vector2(-7,-14),Vector2(14,14))
  if preload("res://data/creatures.gd").DEFINITIONS.has(enemy.kind):
   var collider: CollisionShape2D = enemy.get_node("Collision")
   bounds = collider.global_transform*collider.shape.get_rect()
  if area.intersects(bounds):
   return id
 return -1

func line_clear(from: Vector2, to: Vector2, exclude: Array[RID] = []) -> bool:
 var query := PhysicsRayQueryParameters2D.create(from, to, 1)
 query.exclude = exclude
 return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func player_data(body: CharacterBody2D) -> Dictionary:
 var state: Dictionary = body.resources.snapshot()
 state.merge({"appearance":body.appearance.duplicate(true),"medicine_cooldown": body.medicine_cooldown, "medicine_progress": body.medicine_progress, "action":body.fighter.snapshot()})
 state.merge({"dead": body.dead, "unclothed": body.unclothed, "immunity": body.hurt_immunity, "respawn": body.respawn_remaining, "position": body.position, "velocity": body.velocity, "revision": body.life_revision, "last_chest": body.last_chest_position, "profile": body.profile_id, "since_hurt": body.since_hurt, "regen_fraction": body.regen_fraction, "knockback": body.knockback_remaining})
 return state

func apply_player_state(id: int, data: Dictionary) -> void:
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null:
  return
 var changed_life: bool = body.life_revision != int(data.revision)
 var healed: int = maxi(0,int(data.health)-body.health) if not changed_life else 0
 body.profile_id = data.get("profile", body.profile_id)
 body.since_hurt = data.get("since_hurt", 0.0)
 body.regen_fraction = data.get("regen_fraction", 0.0)
 body.knockback_remaining = data.get("knockback", 0.0)
 body.fighter.apply(data.get("action",{}))
 body.resources.apply(data)
 body.medicine_cooldown = float(data.get("medicine_cooldown",0))
 body.medicine_progress = float(data.get("medicine_progress",0))
 if healed > 0: body.show_heal(healed)
 body.appearance=preload("res://data/appearance.gd").clean(data.get("appearance",body.appearance))
 body.dead = data.dead
 body.unclothed = data.unclothed
 body.hurt_immunity = data.immunity
 body.respawn_remaining = data.respawn
 body.last_chest_position = data.last_chest
 body.life_revision = data.revision
 body.visible = not body.dead
 body.get_node("Collision").set_deferred("disabled", body.dead)
 if changed_life:
  body.position = data.position
  body.velocity = data.velocity
  body.reset_physics_interpolation()
 if body.dead and main.player == body and is_instance_valid(main.inventory_ui) and main.inventory_ui.opened:
  main.inventory_ui.toggle()
 body.queue_redraw()

func damage_player(id: int, amount: int, source: Vector2, bypass_immunity: bool = false) -> bool:
 if not authoritative() or amount <= 0:
  return false
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead or ((body.hurt_immunity > 0.0 or body.fighter.roll_invulnerable()) and not bypass_immunity):
  return false
 body.fighter.interrupt()
 body.swing_remaining = 0
 body.work_remaining = 0
 body.health = maxi(0, body.health - amount)
 body.since_hurt = 0.0
 body.regen_fraction = 0.0
 body.hurt_immunity = Rules.HURT_IMMUNITY
 var direction := signf(body.position.x - source.x)
 body.velocity = Vector2((1.0 if direction == 0 else direction) * 140, -110)
 body.knockback_remaining = 0.16
 main.items.cancel_medicine(body,true,false)
 if body.health == 0:
  _kill(body)
 player_changed.emit(id, player_data(body))
 return true

func _kill(body: CharacterBody2D) -> void:
 var id := int(str(body.name))
 body.fighter.reset()
 body.dead = true
 body.unclothed = true
 body.respawn_remaining = Rules.RESPAWN_DELAY
 body.life_revision += 1
 body.velocity = Vector2.ZERO
 body.visible = false
 body.get_node("Collision").set_deferred("disabled", true)
 var chest_id := next_chest_id
 next_chest_id += 1
 var at: Vector2 = body.position
 at.x = clampf(at.x, 8.0, main.world.world_width * 16 - 8)
 at.y = clampf(at.y, 16.0, main.world.world_depth * 16 - 16)
 var inventory = main.items.inventory_for(id)
 set_chest(chest_id, {"owner": id, "profile": body.profile_id, "position": at, "contents": inventory.to_data()})
 inventory.load_data([])
 main.items.inventory_changed.emit(id)
 body.last_chest_position = at
 chest_changed.emit(chest_id, chest_data(chest_id, true))
 if main.player == body and is_instance_valid(main.inventory_ui) and main.inventory_ui.opened:
  main.inventory_ui.toggle()

func respawn(body: CharacterBody2D) -> void:
 body.fighter.reset()
 body.medicine_progress = 0
 body.medicine_slot = -1
 body.medicine_latch = -1
 body.dead = false
 body.resources.reset_full()
 body.hurt_immunity = Rules.RESPAWN_IMMUNITY
 body.since_hurt = 0.0
 body.regen_fraction = 0.0
 body.position = main.world.safe_spawn_position()
 body.reset_physics_interpolation()
 body.velocity = Vector2.ZERO
 body.move_command = 0.0
 body.jump_command = false
 body.knockback_remaining = 0.0
 body.life_revision += 1
 body.visible = true
 body.get_node("Collision").set_deferred("disabled", false)
 player_changed.emit(int(str(body.name)), player_data(body))

func break_chest(body: CharacterBody2D, cell: Vector2i) -> bool:
 if not authoritative() or body.dead or not main.world.in_reach(body, cell):
  return false
 var id := chest_at(cell)
 if id == -1 or not line_clear(body.position + Vector2(0, -5), chests[id].position):
  return false
 var chest = chests[id]
 var at: Vector2 = chest.position
 var contents: Array = chest.contents.duplicate(true)
 var owner_id: int = chest.owner_id
 set_chest(id, {})
 chest_changed.emit(id, {})
 var owner = main.get_node("Players").get_node_or_null(str(owner_id))
 if owner != null:
  owner.last_chest_position = Vector2(-1, -1)
  for remaining in chests.values():
   if remaining.owner_id == owner_id:
    owner.last_chest_position = remaining.position
  player_changed.emit(owner_id, player_data(owner))
 for slot in contents:
  if slot.count > 0:
   main.items.spawn_drop(slot.item, slot.count, at + Vector2(0, -6))
 spawn_entity("spirit", at, at)
 return true

func resolve_attack(id: int, direction: Vector2, active_strike: bool = false) -> void:
 if not authoritative():
  return
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead:
  return
 var profile: Dictionary = body.fighter.profile if active_strike else main.items.attack_profiles.get(id, {})
 if not active_strike and not profile.get("unarmed",false): return
 var hits: Dictionary = body.fighter.hits if active_strike else {}
 if profile.is_empty():
  return
 var origin: Vector2 = body.position + Vector2(0, -5)
 # Collect targets before breaking chests so a newborn spirit is never hit by
 # the same swing which released it.
 for target_id in entities.keys():
  if hits.has("enemy:%d" % target_id): continue
  var enemy = entities[target_id]
  var size: Vector2 = enemy.get_node("Collision").shape.size
  var target: Vector2 = enemy.position + Vector2(0,-size.y/2)
  var offset := target - origin
  if offset.length() <= float(profile.reach) + size.x/2 and (offset.length() < 1 or offset.normalized().dot(direction) >= float(profile.get("arc_dot",0.2))) and line_clear(origin, target):
   hits["enemy:%d" % target_id] = true
   hit_entity(target_id, int(profile.damage), direction)
 if is_instance_valid(main.encounter.actor):
  var boss = main.encounter.actor
  var target: Vector2 = boss.position + Vector2(0, -29)
  var offset: Vector2 = target - origin
  if not hits.has("boss") and offset.length() <= float(profile.reach) + 23 and (offset.length() < 1 or offset.normalized().dot(direction) >= float(profile.get("arc_dot",0.2))) and line_clear(origin, target):
   if boss.take_hit(int(profile.damage), int(profile.get("poise", profile.damage))): hits["boss"] = true
 for chest_id in chests.keys():
  var target: Vector2 = chests[chest_id].position
  var offset := target - origin
  if not hits.has("chest:%d" % chest_id) and offset.length() <= float(profile.reach) + 8 and (offset.length() < 1 or offset.normalized().dot(direction) >= float(profile.get("arc_dot",0.2))) and line_clear(origin, target):
   hits["chest:%d" % chest_id] = true
   var before := entities.keys()
   break_chest(body, main.world.cell_at(target))
   for born in entities:
    if not before.has(born): hits["enemy:%d" % born] = true

func hit_entity(id: int, damage: int, direction: Vector2) -> bool:
 if not authoritative() or not entities.has(id) or damage <= 0:
  return false
 var enemy = entities[id]
 if enemy.kind == "spirit":
  enemy.health = ceili(enemy.max_health / 2.0) if enemy.health == enemy.max_health else 0
 else:
  if enemy.kind == "void_collector" and direction.x*enemy.attack_facing < 0:
   damage = maxi(1,ceili(damage*0.5))
  enemy.health -= damage
 enemy.hurt_flash = 0.16
 if enemy.kind != "spirit" and enemy.health > 0: enemy.change_attack("recovery")
 enemy.hit_stun = 0.2
 enemy.velocity.x = direction.x * 150
 if enemy.health <= 0:
  var defeated_kind: String = enemy.kind
  var at: Vector2 = enemy.position
  var loot: String = Rules.ENEMIES[enemy.kind].loot
  set_entity(id, {},true)
  entity_changed.emit(id, {})
  if loot != "":
   main.items.spawn_drop(loot, 1, at)
  if is_instance_valid(main.encounter): main.encounter.register_kill(defeated_kind)
 else:
  entity_changed.emit(id, entity_data(id))
 return true

func start_defense(id: int, action: String, axis: float = 0) -> bool:
 if not is_finite(axis): return false
 if not authoritative() or action not in ["roll","parry"]: return false
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead or body.fighter.mode != "idle": return false
 if action == "roll" and not body.presentation_grounded(): return false
 var config: Dictionary = Battle.ROLL if action == "roll" else Battle.PARRY
 if not body.resources.spend_stamina(config.cost): return false
 main.items.cancel_medicine(body)
 body.work_remaining = 0
 body.swing_remaining = 0
 var direction := Vector2(signf(axis) if action == "roll" and absf(axis) > 0.1 else body.facing,0)
 body.fighter.begin(action,direction,config.duration)
 player_changed.emit(id,player_data(body))
 return true

# Resolve only an actual attack's hit, never its warning or a generic hazard.
func receive_attack(id: int, amount: int, source: Vector2, attacker: Node2D, parryable: bool = true, radial: bool = false) -> String:
 var body = main.get_node("Players").get_node_or_null(str(id))
 if not authoritative() or body == null or body.dead: return "miss"
 if body.fighter.roll_invulnerable(): return "dodged"
 if body.hurt_immunity > 0: return "immune"
 var facing_hit: bool = radial or (source.x-body.position.x)*body.facing >= -4
 if parryable and facing_hit and body.fighter.parry_open():
  body.fighter.parried()
  if attacker.has_method("receive_parry"): attacker.receive_parry()
  main.effects.burst("impact",body.position+Vector2(body.facing*12,-8))
  player_changed.emit(id,player_data(body))
  return "parried"
 return "hit" if damage_player(id,amount,source) else "immune"

func tick_fighter(body: CharacterBody2D, delta: float) -> void:
 var previous_mode: String = body.fighter.mode
 var before: String = body.fighter.phase()
 var due: bool = body.fighter.advance(delta)
 if body.fighter.mode == "attack" and (due or body.fighter.phase() == "attack_active"):
  resolve_attack(int(str(body.name)),body.fighter.direction,true)
 var completed: bool = body.fighter.complete_tick()
 if completed and previous_mode == "roll": body.velocity.x = body.move_command*body.SPEED
 if completed or before != body.fighter.phase(): player_changed.emit(int(str(body.name)),player_data(body))

func _physics_process(delta: float) -> void:
 if not is_instance_valid(main.network) or main.network.stopping:
  return
 if main.network.active and not main.network.connected:
  return
 world_time += delta
 if not authoritative():
  return
 var alive: Array = []
 for body in main.get_node("Players").get_children():
  body.hurt_immunity = maxf(0.0, body.hurt_immunity - delta)
  var previous_cooldown: float = body.medicine_cooldown
  body.medicine_cooldown = maxf(0,body.medicine_cooldown-delta)
  var cooldown_changed: bool = previous_cooldown != body.medicine_cooldown
  body.resource_sync = maxf(0,body.resource_sync-delta)
  if body.dead:
   if cooldown_changed and body.resource_sync <= 0:
    body.resource_sync = 0.1
    player_changed.emit(int(str(body.name)),player_data(body))
   body.respawn_remaining -= delta
   if body.respawn_remaining <= 0:
    respawn(body)
   continue
  alive.append(body)
  body.since_hurt += delta
  tick_fighter(body,delta)
  var recovered: bool = body.resources.tick(delta)
  if (recovered or cooldown_changed) and body.resource_sync <= 0:
   body.resource_sync = 0.1
   player_changed.emit(int(str(body.name)), player_data(body))
 for id in entities.keys():
  var enemy = entities[id]
  enemy.grace = maxf(0.0, enemy.grace - delta)
  enemy.hit_stun = maxf(0.0, enemy.hit_stun - delta)
  enemy.night = is_night()
  var target: CharacterBody2D = null
  var nearest := INF
  for body in alive:
   var distance: float = body.position.distance_to(enemy.position)
   if distance < nearest:
    nearest = distance
    target = body
  if main.world.generator_version >= 2 and nearest > 640 and enemy.kind != "spirit":
   if nearest > 900 and not enemy.site_guard:
    set_entity(id,{})
    entity_changed.emit(id,{})
    continue
   enemy.set_process(false)
   enemy.visible = false
   enemy.attack_state = "chase"
   enemy.attack_elapsed = 0
   if is_instance_valid(enemy.hum): enemy.hum.stop()
   continue
  enemy.set_process(true)
  enemy.visible = true
  if enemy.kind == "spirit":
   var destination: Vector2 = enemy.anchor + Vector2(sin(enemy.clock * 1.2) * 32, -20 + cos(enemy.clock) * 14)
   if target != null and target.position.distance_to(enemy.anchor) <= Rules.SPIRIT_RADIUS:
    destination = target.position
   var travel: Vector2 = destination - enemy.position
   enemy.velocity = travel.normalized() * minf(enemy_speed(enemy.kind), travel.length() * 4)
   enemy.position += enemy.velocity * delta
   var tether: Vector2 = enemy.position - enemy.anchor
   if tether.length() > Rules.SPIRIT_RADIUS:
    enemy.position = enemy.anchor + tether.normalized() * Rules.SPIRIT_RADIUS
  else:
   var detect := 310.0 if is_night() else 160.0
   var axis := signf(target.position.x - enemy.position.x) if target != null and nearest < detect else sin(world_time * 0.3 + id)
   var locked: bool = enemy.step_attack(delta,target,self)
   if enemy.hit_stun <= 0 and not locked:
    enemy.velocity.x = axis * enemy_speed(enemy.kind)
    if enemy.kind == "void_collector" and absf(axis) > 0.1: enemy.attack_facing = 1 if axis > 0 else -1
   var flying: bool = enemy.kind == "ashweaver" and enemy.attack_state in ["windup","active"]
   if enemy.kind == "ashweaver" and enemy.attack_state == "chase" and fmod(enemy.clock,3.0) < 1.0:
    enemy.velocity.y = -35.0
    flying = true
   if not flying: enemy.velocity.y = minf(enemy.velocity.y + 850.0 * delta,500.0)
   if not locked and enemy.is_on_floor() and enemy.is_on_wall() and absf(axis) > 0.1:
    enemy.velocity.y = -225.0
   enemy.move_and_slide()
   enemy.position.x = clampf(enemy.position.x, 8, main.world.world_width * 16 - 8)
   if enemy.position.y > main.world.world_depth * 16 + 32 or (nearest > 900 and entities.size() > 2 and not enemy.site_guard):
    set_entity(id, {})
    entity_changed.emit(id, {})
    continue
  if enemy.kind == "spirit" and target != null and enemy.grace <= 0.0:
   var offset: Vector2 = (target.position + Vector2(0, -4)) - (enemy.position + Vector2(0, -6))
   if absf(offset.x) < 13 and absf(offset.y) < 19 and line_clear(enemy.position + Vector2(0, -6), target.position + Vector2(0, -4)):
    var damage: int = Rules.ENEMIES[enemy.kind].night_damage if is_night() else Rules.ENEMIES[enemy.kind].day_damage
    receive_attack(int(str(target.name)),damage,enemy.position,enemy,false)
 if is_night() and not last_night:
  spawn_timer = minf(spawn_timer, 2.0)
 last_night = is_night()
 if spawning_enabled and not alive.is_empty():
  spawn_timer -= delta
  if spawn_timer <= 0:
   _try_spawn(alive)
   spawn_timer = 8.0 if is_night() else 25.0

func _try_spawn(alive: Array) -> bool:
 if main.world.generator_version >= 2: return main.exploration.try_spawn(alive)
 var count := 0
 for enemy in entities.values():
  if enemy.kind == "ashling":
   count += 1
 if count >= (6 if is_night() else 2):
  return false
 var body = alive[spawn_sequence % alive.size()]
 for attempt in range(16):
  var variation := posmod(main.world.world_seed + spawn_sequence * 17 + attempt * 7, 7)
  var offset := (12 if is_night() else 14) + variation
  var column := floori(body.position.x / 16) + offset * (1 if (spawn_sequence + attempt) % 2 == 0 else -1)
  if column < 1 or column >= main.world.world_width - 1:
   continue
  var top: int = main.world.heights[column]
  var at := Vector2(column * 16 + 8, top * 16 - 2)
  if main.world.block_at(Vector2i(column, top)) == -1 or main.world.block_at(Vector2i(column, top - 1)) != -1 or main.world.block_at(Vector2i(column, top - 2)) != -1:
   continue
  if main.world.door_at(Vector2i(column,top-1)) != null: continue
  var safe := true
  for player in alive:
   if player.position.distance_to(at) < 160:
    safe = false
  if safe:
   spawn_sequence += 1
   spawn_entity("ashling", at)
   return true
 return false

func snapshot(include_contents: bool = false) -> Dictionary:
 var state := {"time": world_time, "entities": {}, "chests": {}, "players": {}}
 for id in entities:
  state.entities[id] = entity_data(id)
 for id in chests:
  state.chests[id] = chest_data(id, include_contents)
 for body in main.get_node("Players").get_children():
  state.players[int(str(body.name))] = player_data(body)
 return state

func apply_snapshot(state: Dictionary) -> void:
 for id in entities.keys():
  set_entity(id, {})
 for id in chests.keys():
  set_chest(id, {})
 world_time = state.time
 for id in state.entities:
  set_entity(id, state.entities[id])
 for id in state.chests:
  set_chest(id, state.chests[id])
 for id in state.players:
  apply_player_state(id, state.players[id])

func motion_snapshot() -> Dictionary:
 var state := {"time": world_time, "poses": {}, "encounter": main.encounter.motion_snapshot()}
 for id in entities:
  state.poses[id] = [entities[id].position, entities[id].velocity]
 return state

func apply_motion(state: Dictionary) -> void:
 world_time = state.time
 remote_targets = state.poses
 if state.has("encounter"): main.encounter.apply_motion(state.encounter)

func _process(delta: float) -> void:
 if not is_instance_valid(main.network) or not main.network.active or not main.network.connected or multiplayer.is_server():
  return
 for id in remote_targets:
  if entities.has(id):
   entities[id].position = entities[id].position.lerp(remote_targets[id][0], minf(1, delta * 22))
   entities[id].velocity = remote_targets[id][1]
   entities[id].night = is_night()
 for body in main.get_node("Players").get_children():
  body.hurt_immunity = maxf(0, body.hurt_immunity - delta)
  body.fighter.advance(delta)
  body.fighter.complete_tick()
  if body.dead:
   body.respawn_remaining = maxf(0, body.respawn_remaining - delta)


func connected_player_count() -> int:
 # Registered bodies remain in Players during death/respawn; pending peers
 # and disconnected/offline profile records are not included.
 return clampi(main.get_node("Players").get_child_count(), 1, 4)

func heal_player(id: int, amount: int) -> int:
 if not authoritative(): return 0
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead: return 0
 var restored: int = body.resources.heal(amount)
 if restored > 0:
  body.show_heal(restored)
  player_changed.emit(id, player_data(body))
 return restored

func spend_mana(id: int, amount: int) -> bool:
 if not authoritative(): return false
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead or not body.resources.spend_mana(amount): return false
 player_changed.emit(id, player_data(body))
 return true

func restore_mana(id: int, amount: int) -> int:
 if not authoritative(): return 0
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead: return 0
 var restored: int = body.resources.restore_mana(amount)
 if restored > 0: player_changed.emit(id, player_data(body))
 return restored
