extends RefCounted
# Runtime connection leases. Negative entity IDs cannot collide with ENet peers.
const WINDOW := preload("res://data/boss_attempts.gd").RETURN_SECONDS
var encounter:Node2D
var offline:Dictionary={}
var waiting:Dictionary={}
var paused:=false
var absence:=0.0
var next_ghost:=-1
func _init(value:Node2D) -> void:encounter=value
func active() -> bool:return is_instance_valid(encounter.actor) and encounter.journal.last.get("status","")=="active"
func body(id:int) -> CharacterBody2D:return encounter.main.get_node("Players").get_node_or_null(str(id))
func online_count() -> int:
 var count:=0
 for p in encounter.main.get_node("Players").get_children():
  if int(str(p.name))>0 and encounter.can_damage(p.profile_id):count+=1
 return count
func rebind_body(old:int,id:int) -> void:
 var main=encounter.main;var p=body(old)
 main.survival.cancel_helper(old);main.survival.cancel_target(old);main.survival.intents.erase(old)
 p.name=str(id)
 for map in [main.items.inventories,main.items.attack_ready_at,main.items.attack_profiles,main.items.tool_ready_at,main.saves.peer_profiles]:
  if map.has(old):map[id]=map[old];map.erase(old)
 if encounter.living_participants.has(old):encounter.living_participants.erase(old);encounter.living_participants[id]=true
 if is_instance_valid(encounter.actor) and encounter.actor.hit_targets.has(old):encounter.actor.hit_targets.erase(old);encounter.actor.hit_targets[id]=true
func retain_body(id:int) -> bool:
 var p=body(id)
 if not active() or p==null or not encounter.can_damage(p.profile_id):return false
 var main=encounter.main
 main.saves._capture_peer(id)
 main.equipment_service.finish_block(p)
 main.items.cancel_medicine(p,true,false)
 p.submit_command(0,false)
 var ghost:=next_ghost;next_ghost-=1
 offline[p.profile_id]={"id":ghost,"elapsed":0.0}
 rebind_body(id,ghost)
 if main.network.active:
  main.network._broadcast("despawn_remote",[id])
  main.network._broadcast("spawn_remote",[ghost,p.position])
  main.network._broadcast("sync_life",[ghost,main.combat.player_data(p)])
 refresh_pause();encounter.publish();return true
func reclaim(id:int,profile:String) -> bool:
 if not active() or not offline.has(profile):return false
 var record:Dictionary=offline[profile]
 if record.elapsed>WINDOW or int(record.id)==0 or body(record.id)==null:return false
 var old:int=record.id
 encounter.main.saves._capture_peer(old)
 rebind_body(old,id);offline.erase(profile)
 if encounter.main.network.active:encounter.main.network._broadcast("despawn_remote",[old])
 refresh_pause();return true
func admitted(id:int,profile:String,reclaimed:bool) -> void:
 if not active():return
 var p=body(id)
 if not reclaimed and (not profile in encounter.journal.last.participants or offline.has(profile)):
  waiting[profile]=true
  if encounter.main.combat_zone.contains_body(p):move_outside(p)
  offline.erase(profile)
 refresh_pause();encounter.publish()
func move_outside(p:CharacterBody2D) -> void:
 p.position=entry_position();p.velocity=Vector2.ZERO;p.life_revision+=1
 encounter.main.combat.player_changed.emit(int(str(p.name)),encounter.main.combat.player_data(p))
func entry_position() -> Vector2:
 var main=encounter.main
 return main.world.safe_spawn_position(maxi(2,main.combat_zone.bounds.position.x-3))
func near_entry(p:CharacterBody2D) -> bool:
 if p==null or p.dead:return false
 if encounter.near_altar(p):return true
 return p.position.distance_to(entry_position())<=72
func needs_entry(profile:String) -> bool:
 return active() and not encounter.withdrawn.has(profile) and (waiting.has(profile) or not profile in encounter.journal.last.participants)
func refresh_pause() -> void:
 paused=active() and online_count()==0
 if not paused:absence=0
 for p in encounter.main.get_node("Players").get_children():p.set_meta("attempt_paused",paused and encounter.can_damage(p.profile_id))
func remove_ghost(profile:String) -> void:
 var record:Dictionary=offline[profile];var id:int=record.id
 if id!=0 and body(id)!=null:
  encounter.main.saves.detach_peer(id)
  encounter.main.remove_player(id)
  if encounter.main.network.active:encounter.main.network._broadcast("despawn_remote",[id])
 record.id=0
func tick(delta:float) -> void:
 if not active():return
 for profile in offline:
  offline[profile].elapsed+=delta
  if offline[profile].elapsed>WINDOW:
   waiting[profile]=true;remove_ghost(profile)
 refresh_pause()
 if paused:
  absence+=delta
  if absence>WINDOW:encounter.end_fight("no_players")
func clear() -> void:
 for profile in offline.keys():remove_ghost(profile)
 offline.clear();waiting.clear();paused=false;absence=0
 for p in encounter.main.get_node("Players").get_children():p.set_meta("attempt_paused",false)
func snapshot() -> Dictionary:
 return {"offline":offline.duplicate(true),"waiting":waiting.duplicate(),"paused":paused,"remaining":maxf(0,WINDOW-absence)}
func apply(data:Dictionary) -> void:
 paused=data.get("paused",false);offline=data.get("offline",{}).duplicate(true);waiting=data.get("waiting",{}).duplicate(true);absence=WINDOW-float(data.get("remaining",WINDOW))
 for p in encounter.main.get_node("Players").get_children():p.set_meta("attempt_paused",paused and encounter.can_damage(p.profile_id))
