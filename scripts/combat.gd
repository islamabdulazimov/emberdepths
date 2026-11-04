extends Node2D
signal entity_changed(id: int, data: Dictionary)
signal chest_changed(id: int, data: Dictionary)
signal player_changed(id: int, data: Dictionary)
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
 var id := next_entity_id
 next_entity_id += 1
 var health: int = Rules.ENEMIES[kind].health
 set_entity(id, {"kind": kind, "position": at, "velocity": Vector2.ZERO, "health": health, "anchor": anchor, "grace": 1.2 if kind == "spirit" else 0.8})
 entity_changed.emit(id, entity_data(id))
 return id

func entity_data(id: int) -> Dictionary:
 var body = entities[id]
 return {"kind": body.kind, "position": body.position, "velocity": body.velocity, "health": body.health, "anchor": body.anchor, "grace": body.grace, "clock": body.clock, "hit_stun": body.hit_stun}

func set_entity(id: int, data: Dictionary) -> void:
 if data.is_empty():
  if entities.has(id):
   remove_child(entities[id])
   entities[id].queue_free()
   entities.erase(id)
  remote_targets.erase(id)
  return
 if not entities.has(id):
  var body := CharacterBody2D.new()
  body.set_script(Enemy)
  body.kind = data.kind
  body.max_health = Rules.ENEMIES[data.kind].health
  add_child(body)
  entities[id] = body
 var body = entities[id]
 if body.health > int(data.health):
  body.hurt_flash = 0.16
 body.health = data.health
 body.position = data.position
 body.velocity = data.velocity
 body.anchor = data.anchor
 body.grace = data.get("grace", 0.0)
 body.clock = data.get("clock", 0.0)
 body.hit_stun = data.get("hit_stun", 0.0)
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
  if area.intersects(Rect2(entities[id].position + Vector2(-7, -14), Vector2(14, 14))):
   return id
 return -1

func line_clear(from: Vector2, to: Vector2) -> bool:
 var query := PhysicsRayQueryParameters2D.create(from, to, 1)
 return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func player_data(body: CharacterBody2D) -> Dictionary:
 return {"health": body.health, "dead": body.dead, "unclothed": body.unclothed, "immunity": body.hurt_immunity, "respawn": body.respawn_remaining, "position": body.position, "velocity": body.velocity, "revision": body.life_revision, "last_chest": body.last_chest_position, "profile": body.profile_id, "since_hurt": body.since_hurt, "regen_fraction": body.regen_fraction, "knockback": body.knockback_remaining}

func apply_player_state(id: int, data: Dictionary) -> void:
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null:
  return
 var changed_life: bool = body.life_revision != int(data.revision)
 body.profile_id = data.get("profile", body.profile_id)
 body.since_hurt = data.get("since_hurt", 0.0)
 body.regen_fraction = data.get("regen_fraction", 0.0)
 body.knockback_remaining = data.get("knockback", 0.0)
 body.health = data.health
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
 if body.dead and main.player == body and is_instance_valid(main.inventory_ui) and main.inventory_ui.opened:
  main.inventory_ui.toggle()
 body.queue_redraw()

func damage_player(id: int, amount: int, source: Vector2, bypass_immunity: bool = false) -> bool:
 if not authoritative() or amount <= 0:
  return false
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead or (body.hurt_immunity > 0.0 and not bypass_immunity):
  return false
 body.health = maxi(0, body.health - amount)
 body.since_hurt = 0.0
 body.regen_fraction = 0.0
 body.hurt_immunity = Rules.HURT_IMMUNITY
 var direction := signf(body.position.x - source.x)
 body.velocity = Vector2((1.0 if direction == 0 else direction) * 140, -110)
 body.knockback_remaining = 0.16
 if body.health == 0:
  _kill(body)
 player_changed.emit(id, player_data(body))
 return true

func _kill(body: CharacterBody2D) -> void:
 var id := int(str(body.name))
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
 body.dead = false
 body.health = Rules.MAX_HEALTH
 body.hurt_immunity = Rules.RESPAWN_IMMUNITY
 body.since_hurt = 0.0
 body.regen_fraction = 0.0
 body.position = main.world.safe_spawn_position()
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

func resolve_attack(id: int, direction: Vector2) -> void:
 if not authoritative():
  return
 var body = main.get_node("Players").get_node_or_null(str(id))
 if body == null or body.dead:
  return
 var profile: Dictionary = main.items.attack_profiles.get(id, {})
 if profile.is_empty():
  return
 var origin: Vector2 = body.position + Vector2(0, -5)
 # Collect targets before breaking chests so a newborn spirit is never hit by
 # the same swing which released it.
 for target_id in entities.keys():
  var enemy = entities[target_id]
  var target: Vector2 = enemy.position + Vector2(0, -6)
  var offset := target - origin
  if offset.length() <= float(profile.reach) + 7 and (offset.length() < 1 or offset.normalized().dot(direction) >= 0.2) and line_clear(origin, target):
   hit_entity(target_id, int(profile.damage), direction)
 for chest_id in chests.keys():
  var target: Vector2 = chests[chest_id].position
  var offset := target - origin
  if offset.length() <= float(profile.reach) + 8 and (offset.length() < 1 or offset.normalized().dot(direction) >= 0.2) and line_clear(origin, target):
   break_chest(body, main.world.cell_at(target))

func hit_entity(id: int, damage: int, direction: Vector2) -> bool:
 if not authoritative() or not entities.has(id) or damage <= 0:
  return false
 var enemy = entities[id]
 enemy.health -= 1 if enemy.kind == "spirit" else damage
 enemy.hurt_flash = 0.16
 enemy.hit_stun = 0.2
 enemy.velocity.x = direction.x * 150
 if enemy.health <= 0:
  var at: Vector2 = enemy.position
  var loot: String = Rules.ENEMIES[enemy.kind].loot
  set_entity(id, {})
  entity_changed.emit(id, {})
  if loot != "":
   main.items.spawn_drop(loot, 1, at)
 else:
  entity_changed.emit(id, entity_data(id))
 return true

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
  if body.dead:
   body.respawn_remaining -= delta
   if body.respawn_remaining <= 0:
    respawn(body)
   continue
  alive.append(body)
  body.since_hurt += delta
  if body.health < Rules.MAX_HEALTH and body.since_hurt >= Rules.REGEN_DELAY:
   body.regen_fraction += Rules.REGEN_RATE * delta
   if body.regen_fraction >= 1:
    var healed := floori(body.regen_fraction)
    body.regen_fraction -= healed
    body.health = mini(Rules.MAX_HEALTH, body.health + healed)
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
   if enemy.hit_stun <= 0:
    enemy.velocity.x = axis * enemy_speed(enemy.kind)
   enemy.velocity.y = minf(enemy.velocity.y + 850.0 * delta, 500.0)
   if enemy.is_on_floor() and enemy.is_on_wall() and absf(axis) > 0.1:
    enemy.velocity.y = -225.0
   enemy.move_and_slide()
   enemy.position.x = clampf(enemy.position.x, 8, main.world.world_width * 16 - 8)
   if enemy.position.y > main.world.world_depth * 16 + 32 or (nearest > 900 and entities.size() > 2):
    set_entity(id, {})
    entity_changed.emit(id, {})
    continue
  if target != null and enemy.grace <= 0.0:
   var offset: Vector2 = (target.position + Vector2(0, -4)) - (enemy.position + Vector2(0, -6))
   if absf(offset.x) < 13 and absf(offset.y) < 19 and line_clear(enemy.position + Vector2(0, -6), target.position + Vector2(0, -4)):
    var damage: int = Rules.ENEMIES[enemy.kind].night_damage if is_night() else Rules.ENEMIES[enemy.kind].day_damage
    damage_player(int(str(target.name)), damage, enemy.position)
 if is_night() and not last_night:
  spawn_timer = minf(spawn_timer, 2.0)
 last_night = is_night()
 if spawning_enabled and not alive.is_empty():
  spawn_timer -= delta
  if spawn_timer <= 0:
   _try_spawn(alive)
   spawn_timer = 8.0 if is_night() else 25.0

func _try_spawn(alive: Array) -> bool:
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
 var state := {"time": world_time, "poses": {}}
 for id in entities:
  state.poses[id] = [entities[id].position, entities[id].velocity]
 return state

func apply_motion(state: Dictionary) -> void:
 world_time = state.time
 remote_targets = state.poses

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
  if body.dead:
   body.respawn_remaining = maxf(0, body.respawn_remaining - delta)
