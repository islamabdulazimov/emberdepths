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
var notice := "Andrew · призыв у алтаря"
const Attempt = preload("res://scripts/boss_attempt.gd")
const Summon = preload("res://data/boss_attempts.gd")
var journal = Attempt.new()
var choices:Dictionary={}
var starting:=false
var living_participants: Dictionary = {}
var withdrawn:Dictionary={}
func withdraw(profile:String) -> void:
 if authoritative() and is_instance_valid(actor):withdrawn[profile]=true;publish()

func _ready() -> void:
 main = get_parent()
 main.combat.player_changed.connect(_player_changed)

func authoritative() -> bool:
 return main.combat.authoritative()

func alive_players() -> Array:
 var result: Array = []
 for player in main.get_node("Players").get_children():
  if not player.dead and can_damage(player.profile_id) and (not main.combat_zone.active or main.combat_zone.contains_body(player)): result.append(player)
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
 # Kept as a diagnostic counter; kills never schedule a summon.
 kills += 1

func can_damage(profile:String) -> bool:
 return not withdrawn.has(profile) and (journal.last.get("status","")!="active" or profile in journal.last.participants)

func arena_bounds() -> Rect2i:
 var c:Vector2i=main.world.cell_at(journal.altar)
 return Rect2i(maxi(0,c.x-Summon.ARENA_HALF_WIDTH),maxi(0,c.y-10),Summon.ARENA_HALF_WIDTH*2+1,16)

func ensure_altar() -> void:
 if main.has_meta("combat_test") or journal.altar!=Vector2.ZERO:return
 # Find existing supported ground. Never flatten a player's saved terrain.
 for distance in range(20,72):
  for sign_value in [1,-1]:
   var x:int=main.world.world_width/2+distance*sign_value
   if x<3 or x>=main.world.world_width-3:continue
   var floor_y:=-1
   for y in range(3,main.world.world_depth-2):
    if main.world.block_at(Vector2i(x,y))>=0:floor_y=y;break
   if floor_y<3:continue
   var clear:=true
   for dx in [-1,0,1]:
    if main.world.block_at(Vector2i(x+dx,floor_y))<0:clear=false
    for dy in [-1,-2,-3]:
     if main.world.block_at(Vector2i(x+dx,floor_y+dy))>=0 or main.world.door_at(Vector2i(x+dx,floor_y+dy))!=null:clear=false
   for site in main.world.sites:
    if site.rect.grow(2).has_point(Vector2i(x,floor_y)):clear=false
   if clear:
    var at:=Vector2(x*16+8,floor_y*16)
    var area:=Rect2i(maxi(0,x-Summon.ARENA_HALF_WIDTH),maxi(0,floor_y-10),Summon.ARENA_HALF_WIDTH*2+1,16)
    # The first call should be possible without carving a new arena into a save.
    if _find_spawn_positions([at+Vector2(-32,-10)],area)==null and _find_spawn_positions([at+Vector2(32,-10)],area)==null:continue
    journal.altar=at;return

func near_altar(body:CharacterBody2D) -> bool:
 return body!=null and not body.dead and journal.altar!=Vector2.ZERO and body.position.distance_to(journal.altar)<=Summon.REACH and main.combat.line_clear(body.position+Vector2(0,-6),journal.altar+Vector2(0,-14))

func choose(peer:int,action:String) -> String:
 if not authoritative():return "Решает хост"
 var body=main.get_node("Players").get_node_or_null(str(peer))
 if body==null or body.profile_id.is_empty():return "Игрок не найден"
 if is_instance_valid(actor) or starting:return "Бой уже идёт"
 if action not in ["join","skip","ready","start"]:return "Неизвестное действие"
 if not near_altar(body):return "Подойди к алтарю"
 if action=="start":return start_attempt(peer)
 if action=="ready":
  if choices.get(body.profile_id,{}).get("choice","")!="join":return "Сначала выбери участие"
  choices[body.profile_id].ready=true
 else:choices[body.profile_id]={"choice":action,"ready":false}
 publish();return ""

func start_attempt(peer:int) -> String:
 if not authoritative():return "Решает хост"
 if starting or is_instance_valid(actor):return "Бой уже идёт"
 var initiator=main.get_node("Players").get_node_or_null(str(peer))
 if not near_altar(initiator):return "Подойди к алтарю"
 var players:Array=[];var profiles:Array=[]
 var area:=arena_bounds()
 for body in main.get_node("Players").get_children():
  var vote:Dictionary=choices.get(body.profile_id,{})
  if vote.get("choice","")!="join":continue
  if not vote.get("ready",false) or body.dead or not area.has_point(main.world.cell_at(body.position)):return "Все участники должны быть живы, на арене и готовы"
  if body.profile_id in profiles:return "Повторный профиль участника"
  players.append(body);profiles.append(body.profile_id)
 if initiator==null or not initiator in players or players.is_empty():return "Подтверди участие и готовность"
 if not main.saves.can_save() or main.saves.write_blocked:return "Призыв отменён: сохранение недоступно"
 var bag=main.items.inventory_for(peer);var slot:=-1
 if journal.free_used:
  for index in range(bag.slots.size()):
   if bag.item_at(index)==Summon.SUMMON_ITEM:slot=index;break
  if slot<0:return "Нужна Печать вызова Andrew у призывающего"
 var at:Variant=_find_spawn(players,area)
 if at==null:return "Нет места для Andrew: подготовь свободную площадку у алтаря"
 # Synchronous transaction: no input/frame/RPC may interleave actor + charge + disk.
 starting=true
 var before:Dictionary=journal.snapshot();var inventory:Array=bag.to_data()
 journal.begin(profiles)
 if slot>=0:bag.take_one(slot)
 _spawn_at(at,players,players.size(),area)
 if not main.saves.save_now():
  if is_instance_valid(actor):remove_child(actor);actor.queue_free()
  actor=null;state=null;main.combat_zone.unlock();journal.apply(before);bag.load_data(inventory)
  used_once=false;living_participants.clear();withdrawn.clear();starting=false
  notice="Призыв отменён: не удалось записать сохранение";publish();return notice
 starting=false;choices.clear()
 for body in main.get_node("Players").get_children():
  if not body.profile_id in profiles:withdrawn[body.profile_id]=true
 main.items.inventory_changed.emit(peer)
 if is_instance_valid(main.boss_ui):main.boss_ui.bind_boss(state)
 publish();return ""

func exclude_unlisted(profile:String) -> void:
 if journal.last.get("status","")=="active" and not profile in journal.last.participants:
  withdrawn[profile]=true;publish()

func restore_journal(data:Dictionary) -> void:
 journal.apply(data,true);choices.clear();ensure_altar();publish()

func persistent_data() -> Dictionary:return journal.snapshot()

func _find_spawn(players: Array, area:Rect2i=Rect2i()) -> Variant:
 var positions:Array=[]
 for player in players:positions.append(player.position)
 return _find_spawn_positions(positions,area)

func _find_spawn_positions(positions:Array,area:Rect2i=Rect2i()) -> Variant:
 for position_value in positions:
  var origin: Vector2i = main.world.cell_at(position_value + Vector2(0, 10))
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
    if area.has_area() and not area.encloses(Rect2i(column-2,floor_y-5,5,6)):clear=false
    for other in positions:
     if at.distance_to(other) < 80: clear = false
    if main.world.generator_version >= 2:
     var candidate := area if area.has_area() else Rect2i(column-12,maxi(0,floor_y-10),25,16)
     for site in main.world.sites:
      if candidate.intersects(site.rect.grow(2)): clear = false
    if clear: return at
 return null

func try_spawn() -> bool:
 if not authoritative() or not enabled or not pending or used_once: return false
 var players := alive_players()
 var at: Variant = _find_spawn(players)
 if at == null:
  notice = "Andrew ожидает свободного места рядом"
  return false
 _spawn_at(at,players,main.combat.connected_player_count())
 if is_instance_valid(main.boss_ui): main.boss_ui.bind_boss(state)
 publish()
 return true

func _spawn_at(at:Vector2,players:Array,count:int,area:Rect2i=Rect2i()) -> void:
 state = BossState.new()
 state.begin(Definition.ANDREW,count)
 actor = AndrewScene.instantiate()
 actor.encounter=self;actor.state=state;actor.definition=Definition.ANDREW
 add_child(actor);actor.position=at;actor.remote_target=at
 main.combat_zone.lock(at,players)
 if area.has_area():main.combat_zone.bounds=area;main.combat_zone.queue_redraw()
 used_once=true;pending=false;living_participants.clear();withdrawn.clear()
 for player in players:living_participants[int(str(player.name))]=true
 notice="Andrew готовится к бою"

func _player_changed(id: int, data: Dictionary) -> void:
 if authoritative() and is_instance_valid(actor) and living_participants.has(id) and data.dead:
  if alive_players().is_empty():end_fight("player_died")

func end_fight(reason: String) -> void:
 var durable:bool=journal.last.get("status","")=="active"
 if durable:journal.last.status=reason if reason in ["defeated","player_died","no_players","loaded"] else "interrupted"
 main.combat_zone.unlock()
 if state != null: state.active = false
 if is_instance_valid(actor):
  if reason == "defeated":
   main.effects.boss_death(actor.position,actor.facing)
   main.effects.burst("impact",actor.position+Vector2(0,-32))
  actor.indicator_active = false
  actor.hit_targets.clear()
  remove_child(actor)
  actor.queue_free()
 actor = null
 pending = false
 living_participants.clear()
 withdrawn.clear()
 if reason == "defeated": notice = "Andrew повержен"
 elif main.has_meta("combat_test"): notice = "Бой завершён · Andrew — повторить"
 elif reason == "no_players": notice = "Игроки покинули арену · бой завершён"
 else: notice = "Бой завершён · повторный призыв у алтаря"
 if is_instance_valid(main.boss_ui): main.boss_ui.unbind_boss()
 if durable and reason not in ["loaded","new_world"]:main.saves.checkpoint()
 publish()

func cancel_for_load() -> void:
 if is_instance_valid(actor): end_fight("loaded")

func reset_run() -> void:
 if is_instance_valid(actor): end_fight("new_world")
 state = null
 kills = 0
 used_once = false
 pending = false
 journal=Attempt.new();choices.clear()
 notice = "Andrew · призыв у алтаря"
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
 return {"attempt":journal.snapshot(),"choices":choices.duplicate(true),"withdrawn":withdrawn.duplicate(),"kills": kills, "used": used_once, "pending": pending, "notice": notice, "boss": actor.snapshot() if is_instance_valid(actor) else {},"zone":main.combat_zone.snapshot()}

func apply(data: Dictionary) -> void:
 journal.apply(data.get("attempt",{}));choices=data.get("choices",{}).duplicate(true)
 withdrawn=data.get("withdrawn",{}).duplicate()
 main.combat_zone.apply(data.get("zone",{}))
 kills = data.kills
 used_once = data.used
 pending = data.pending
 notice = data.notice
 if data.boss.is_empty():
  if is_instance_valid(actor) and data.notice == "Andrew повержен":
   main.effects.boss_death(actor.position,actor.facing)
   main.effects.burst("impact",actor.position+Vector2(0,-32))
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
