extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/combat_arena.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.items.set_physics_process(false);main.player.set_physics_process(false);main.exploration.set_process(false)
 main.add_player(2,Vector2(95*16+8,26*16-10));var helper=main.get_node("Players/2");helper.profile_id="2".repeat(32);helper.set_physics_process(false)
 main.spawn_practice_boss();main.encounter.set_physics_process(false);var boss=main.encounter.actor;boss.set_physics_process(false)
 var p=main.player;p.hurt_immunity=0;var profile:String=p.profile_id
 check(is_instance_valid(boss) and main.encounter.alive_players().size()==2,"two alive arena participants are available")
 main.combat.damage_player(1,1000,p.position,true)
 check(p.dead and is_instance_valid(main.encounter.actor),"downed ally never prematurely ends remaining fight")
 check(main.survival.respawn_request(1) and main.encounter.withdrawn.has(profile),"choosing respawn withdraws stable profile from active attempt")
 check(not main.combat_zone.contains_body(p) and main.encounter.alive_players()==[helper],"respawned character is outside arena and excluded from boss targets")
 var before:int=boss.state.health;p.position=boss.position+Vector2(-20,-10);p.fighter.reset();main.items.attack_ready_at.clear()
 main.items.swing(p,0,Vector2.RIGHT);main.combat.tick_fighter(p,.13)
 check(boss.state.health==before,"withdrawn player cannot damage boss by walking back")
 main.survival._physics_process(0)
 check(not main.combat_zone.contains_body(p),"server prevents reentry by a withdrawn profile")
 var snapshot:Dictionary=main.encounter.snapshot()
 check(snapshot.withdrawn.has(profile),"withdrawal uses stable identity in encounter snapshot")
 helper.hurt_immunity=0;main.combat.damage_player(2,1000,helper.position,true)
 check(main.encounter.actor==null and not main.combat_zone.active,"last remaining participant downed ends attempt even with respawned spectator alive")
 main.queue_free();await process_frame;print("SURVIVAL_BOSS_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
