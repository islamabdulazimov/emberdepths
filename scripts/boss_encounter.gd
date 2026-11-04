extends Node2D
signal changed(data: Dictionary)
const BossState = preload("res://scripts/boss_state.gd")
const AndrewScene = preload("res://scenes/andrew.tscn")
const Definition = preload("res://data/bosses.gd")
var main: Node2D
var state: RefCounted
var actor: CharacterBody2D
var kills := 0
var used_once := false
var pending := false
var retry_clock := 0.0
var enabled := true
var notice := "Пепельники: 0/3"
var living_participants: Dictionary = {}

func _ready() -> void:
 main = get_parent()
 main.combat.player_changed.connect(_player_changed)

func authoritative() -> bool:
 return main.combat.authoritative()

func alive_players() -> Array:
 var result: Array = []
 for player in main.get_node("Players").get_children():
  if not player.dead and (not main.combat_zone.active or main.combat_zone.contains_body(player)): result.append(player)
 return result

func nearest_player(at: Vector2) -> CharacterBody2D:
 var nearest: CharacterBody2D
 var distance := INF
 for player in alive_players():
  var value: float = player.position.distance_squared_to(at)
  if value < distance:
   nearest = player
   distance = value
 return nearest

func register_kill(kind: String) -> void:
 if not authoritative() or kind != "ashling": return
 kills += 1
 if kills >= 3 and not used_once: pending = true
 if not used_once: notice = "Пепельники: %d/3" % mini(kills, 3)
 publish()

func _find_spawn(players: Array) -> Variant:
 for player in players:
  var origin: Vector2i = main.world.cell_at(player.position + Vector2(0, 10))
  for offset in [6, -6, 5, -5, 7, -7, 8, -8, 10, -10, 12, -12]:
   var column: int = origin.x + offset
   for dy in [0, -1, 1, -2, 2, -3, 3, -4, 4, -6, 6, -8, 8]:
    var floor_y: int = origin.y + dy
    if column < 2 or column >= main.world.world_width - 2 or floor_y < 5 or floor_y >= main.world.world_depth: continue
    var clear := true
    for x in range(column - 2, column + 3):
     if absi(x - column) <= 1 and main.world.block_at(Vector2i(x, floor_y)) == -1: clear = false
     for y in range(floor_y - 5, floor_y):
      if main.world.block_at(Vector2i(x, y)) != -1 or main.world.door_at(Vector2i(x,y)) != null: clear = false
    var at := Vector2(column * 16 + 8, floor_y * 16)
    for other in players:
     if at.distance_to(other.position) < 80: clear = false
    if clear: return at
 return null

func try_spawn() -> bool:
 if not authoritative() or not enabled or not pending or used_once: return false
 var players := alive_players()
 var at: Variant = _find_spawn(players)
 if at == null:
  notice = "Andrew ожидает свободного места рядом"
  return false
 state = BossState.new()
 state.begin(Definition.ANDREW, main.combat.connected_player_count())
 actor = AndrewScene.instantiate()
 actor.encounter = self
 actor.state = state
 actor.definition = Definition.ANDREW
 add_child(actor)
 actor.position = at
 actor.remote_target = at
 main.combat_zone.lock(at,players)
 used_once = true
 pending = false
 living_participants.clear()
 for player in players:
  if main.combat_zone.contains_body(player): living_participants[int(str(player.name))] = true
 notice = "Andrew готовится к бою"
 if is_instance_valid(main.boss_ui): main.boss_ui.bind_boss(state)
 publish()
 return true

func _player_changed(id: int, data: Dictionary) -> void:
 if authoritative() and is_instance_valid(actor) and living_participants.has(id) and data.dead:
  end_fight("player_died")

func end_fight(reason: String) -> void:
 main.combat_zone.unlock()
 if state != null: state.active = false
 if is_instance_valid(actor):
  if reason == "defeated": main.effects.burst("impact",actor.position+Vector2(0,-32))
  actor.indicator_active = false
  actor.hit_targets.clear()
  remove_child(actor)
  actor.queue_free()
 actor = null
 pending = false
 living_participants.clear()
 if reason == "defeated": notice = "Andrew повержен"
 elif main.has_meta("combat_test"): notice = "Бой завершён · Andrew — повторить"
 elif reason == "no_players": notice = "Игроки покинули арену · бой завершён"
 else: notice = "Бой завершён · новый Andrew в новом запуске"
 if is_instance_valid(main.boss_ui): main.boss_ui.unbind_boss()
 publish()

func cancel_for_load() -> void:
 if is_instance_valid(actor): end_fight("loaded")

func reset_run() -> void:
 if is_instance_valid(actor): end_fight("new_world")
 state = null
 kills = 0
 used_once = false
 pending = false
 notice = "Пепельники: 0/3"
 publish()

func _physics_process(delta: float) -> void:
 if not authoritative() or not enabled: return
 if is_instance_valid(actor):
  var alive := alive_players()
  if alive.is_empty():
   end_fight("no_players")
   return
  for player in alive: living_participants[int(str(player.name))] = true
 if pending and not used_once:
  retry_clock -= delta
  if retry_clock <= 0:
   retry_clock = 1.0
   try_spawn()

func snapshot() -> Dictionary:
 return {"kills": kills, "used": used_once, "pending": pending, "notice": notice, "boss": actor.snapshot() if is_instance_valid(actor) else {},"zone":main.combat_zone.snapshot()}

func apply(data: Dictionary) -> void:
 main.combat_zone.apply(data.get("zone",{}))
 kills = data.kills
 used_once = data.used
 pending = data.pending
 notice = data.notice
 if data.boss.is_empty():
  if is_instance_valid(actor) and data.notice == "Andrew повержен": main.effects.burst("impact",actor.position+Vector2(0,-32))
  if state != null: state.active = false
  if is_instance_valid(actor):
   remove_child(actor)
   actor.queue_free()
  actor = null
  if is_instance_valid(main.boss_ui): main.boss_ui.unbind_boss()
  return
 if not is_instance_valid(actor):
  state = BossState.new()
  actor = AndrewScene.instantiate()
  actor.encounter = self
  actor.state = state
  actor.definition = Definition.ANDREW
  add_child(actor)
 actor.apply(data.boss)
 if is_instance_valid(main.boss_ui): main.boss_ui.bind_boss(state)

func publish() -> void:
 changed.emit(snapshot())


func motion_snapshot() -> Dictionary:
 if not is_instance_valid(actor): return {}
 var data: Dictionary = actor.snapshot()
 data.erase("state")
 return data

func apply_motion(data: Dictionary) -> void:
 if not is_instance_valid(actor) or data.is_empty(): return
 if int(data.get("phase_revision", 0)) < actor.phase_revision: return
 actor.phase_revision = int(data.get("phase_revision", 0))
 actor.remote_target = data.position
 actor.velocity = data.velocity
 actor.phase = data.phase
 actor.phase_elapsed = data.elapsed
 actor.phase_duration = data.duration
 actor.facing = data.facing
 actor.locked_target = data.target
 actor.indicator_active = data.indicator
