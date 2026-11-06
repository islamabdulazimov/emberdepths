extends "res://tests/altar_smoke.gd"
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);freeze(main)
 var e=main.encounter;var leases=e.returns
 for x in range(65,128):
  for y in range(10,26):main.world.apply_edit(Vector2i(x,y),-1)
  for y in range(26,29):main.world.apply_edit(Vector2i(x,y),2)
 e.journal.altar=Vector2(1544,416);main.player.position=Vector2(1544,406)
 for id in [2,3]:
  main.add_player(id,Vector2(1544+id*8,406));main.saves.attach_peer(id,str(id).repeat(32),str(id).repeat(64))
 freeze(main);ready(main,1);ready(main,2)
 check(e.choose(1,"start")=="","two initial participants start")
 var boss=e.actor;boss.set_physics_process(false);boss.state.health=101;boss.state.poise=31
 var p=main.get_node("Players/2");p.health=65;p.resources.mana=12;p.roll_cooldown=4;p.hurt_immunity=0
 main.items.inventory_for(2).add("wood",17);boss.hit_targets[2]=true
 var uid:String=p.profile_id
 check(leases.retain_body(2),"disconnect retains participant body")
 var ghost:int=leases.offline[uid].id
 check(ghost<0 and main.get_node("Players").get_node(str(ghost))==p and not main.get_node("Players").has_node("2"),"same physical body gets a non-network entity ID")
 check(boss.hit_targets.has(ghost) and not boss.hit_targets.has(2),"hit ledger follows retained body without a second hit")
 check(main.saves.authorize(uid,"2".repeat(64))=="" and main.saves.authorize(uid,"f".repeat(64))!="","only authenticated owner may reclaim offline profile")
 check(main.combat.connected_player_count()==2,"offline body is not counted as connected for normal mobs")
 var mob:int=main.combat.spawn_entity("ashling",Vector2(1900,416))
 check(main.combat.entities[mob].max_health==57 and boss.state.max_health==450,"new normal mob uses connected count while boss keeps participant count")
 check(main.combat.damage_player(ghost,9,p.position+Vector2(-20,0),true) and p.health==56,"offline body remains vulnerable while another participant fights")
 leases.tick(60)
 check(leases.reclaim(7,uid),"return at exactly 60 seconds reclaims body")
 leases.admitted(7,uid,true)
 check(main.get_node("Players/7")==p and p.health==56 and p.resources.mana==12 and p.roll_cooldown==4,"return keeps same health mana and cooldown instead of restoring defaults")
 check(main.items.inventory_for(7).count_item("wood")==17 and boss.state.health==101 and boss.state.max_health==450,"return does not heal boss or duplicate inventory")
 check(boss.hit_targets.has(7) and not boss.hit_targets.has(ghost),"return keeps current attack hit exclusion")
 check(main.saves.authorize(uid,"2".repeat(64))!="","live profile cannot be claimed twice")
 # A new participant must explicitly confirm the warning for this attempt.
 var newcomer=main.get_node("Players/3");leases.move_outside(newcomer);newcomer.health=42
 check(e.choose(3,"enter","old-attempt")!="" and boss.state.health==101,"stale confirmation never heals or joins another attempt")
 var before:Dictionary=e.persistent_data();main.saves.write_blocked=true
 check(e.choose(3,"enter",e.journal.last.id)!="" and e.persistent_data()==before and boss.state.health==101,"failed admission save keeps participants and boss health unchanged")
 main.saves.write_blocked=false
 check(e.choose(3,"enter",e.journal.last.id)=="","new participant confirms active attempt")
 check(boss.state.max_health==540 and boss.state.health==540 and boss.state.poise==31 and newcomer.health==42,"new entry heals only boss health and increases scale once")
 boss.state.health=102
 check(e.choose(3,"enter",e.journal.last.id)!="" and boss.state.health==102 and e.journal.last.participants.size()==3,"repeated entry neither heals nor counts the same profile again")
 # A late return is restored outside the arena until a fresh warning is accepted.
 p.hurt_immunity=0
 check(leases.retain_body(7),"second disconnect starts its own timer")
 leases.tick(60.01)
 check(leases.offline[uid].id==0 and not main.get_node("Players").has_node(str(ghost)),"expired body is captured and removed")
 main.add_player(8,Vector2(1544,406));main.saves.attach_peer(8,uid,"2".repeat(64));leases.admitted(8,uid,false);freeze(main)
 p=main.get_node("Players/8")
 check(p.health==56 and not main.combat_zone.contains_body(p) and boss.state.health==102,"late connection alone heals nobody and stays outside")
 check(not e.can_damage(uid) and e.choose(8,"enter",e.journal.last.id)=="","late player must explicitly enter again")
 check(e.journal.last.participants.size()==3 and boss.state.max_health==540 and boss.state.health==540 and p.health==56,"late reentry heals boss without increasing same profile scale")
 # Downing while offline is retained; respawning permanently withdraws the profile.
 p.hurt_immunity=0;leases.retain_body(8);ghost=leases.offline[uid].id
 check(main.combat.damage_player(ghost,1000,p.position,true) and p.dead,"offline participant can be downed")
 check(leases.reclaim(8,uid) and p.dead and p.health==0,"quick return never resurrects downed participant")
 leases.admitted(8,uid,true)
 check(main.survival.respawn_request(8) and e.withdrawn.has(uid),"choosing respawn withdraws persistent participant")
 leases.move_outside(p);boss.state.health=103
 check(e.choose(8,"enter",e.journal.last.id)!="" and boss.state.health==103,"respawn cannot bypass active attempt exclusion")
 main.saves.detach_peer(8);main.remove_player(8)
 main.add_player(10,leases.entry_position());main.saves.attach_peer(10,uid,"2".repeat(64));leases.admitted(10,uid,false);freeze(main)
 check(e.choose(10,"enter",e.journal.last.id)!="" and boss.state.health==103,"disconnect and rejoin never bypass persistent respawn withdrawal")
 # Two independent clocks, pause with an observer still connected, inclusive boundary.
 var host_profile:String=main.player.profile_id;var other_profile:String=newcomer.profile_id
 check(leases.retain_body(1),"first participant disconnects independently")
 leases.tick(20)
 check(not leases.paused,"other connected participant keeps fight running")
 leases.retain_body(3)
 check(leases.paused and leases.absence==0,"last participant departure pauses boss despite connected spectator")
 var age:float=boss.phase_elapsed;var immunity:float=main.get_node("Players").get_node(str(leases.offline[host_profile].id)).hurt_immunity
 boss._physics_process(1);main.combat._physics_process(1)
 check(boss.phase_elapsed==age and main.get_node("Players").get_node(str(leases.offline[host_profile].id)).hurt_immunity==immunity,"paused attempt freezes phases and participant effects")
 check(not boss.take_hit(30,30) and not main.combat.damage_player(leases.offline[host_profile].id,30,Vector2.ZERO,true),"paused attempt takes no outside damage")
 leases.tick(40)
 check(leases.offline[host_profile].elapsed==60 and leases.offline[other_profile].elapsed==40,"individual disconnect timers remain independent during pause")
 check(leases.reclaim(1,host_profile) and not leases.paused and boss.state.health==103,"timely return resumes without boss healing")
 leases.admitted(1,host_profile,true);main.select_local_player(1)
 check(leases.offline[other_profile].elapsed==40,"resume does not reset another participant timer")
 leases.retain_body(1);leases.tick(20)
 check(leases.reclaim(3,other_profile) and not leases.paused,"second participant may reclaim exactly at their own 60 seconds")
 leases.admitted(3,other_profile,true)
 leases.retain_body(3);leases.tick(60)
 check(is_instance_valid(e.actor) and leases.paused and leases.absence==60,"all-offline timeout is inclusive at 60 seconds")
 leases.tick(.01)
 check(e.actor==null and e.journal.last.status=="no_players" and not main.combat_zone.active,"timeout beyond 60 seconds ends attempt and unlocks arena")
 var ghosts:=0
 for body in main.get_node("Players").get_children():
  if int(str(body.name))<0:ghosts+=1
 check(ghosts==0 and leases.offline.is_empty(),"terminal attempt removes all retained bodies without duplicates")
 check(preload("res://scripts/save_schema.gd").validate(main.saves.capture())=="","all retained inventories and life states remain valid saved profiles")
 main.queue_free();await process_frame;print("BOSS_RETURN_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
