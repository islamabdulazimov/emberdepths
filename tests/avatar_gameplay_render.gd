extends "res://tests/recast_ui_render.gd"
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://scenes/combat_arena.tscn").instantiate();root.add_child(main)
 main.combat.spawning_enabled=false;main.encounter.enabled=false;main.exploration.set_process(false)
 for id in main.combat.entities.keys():main.combat.set_entity(id,{},false,false)
 main.items.local_inventory().load_data([])
 var p=main.player;var a=preload("res://data/appearance.gd")
 for gender in ["male","female"]:
  for build in a.BUILDS:
   main.combat.respawn(p);p.position=Vector2(90*16+8,26*16-10);p.velocity=Vector2.ZERO;p.roll_cooldown=0;p.hurt_immunity=0;p.appearance={"gender":gender,"build":build,"hair":"long_tail","hair_color":3,"skin":2};p.equipment={"weapon":"wood_sword","head":"wood_helm","body":"wood_armor","legs":"wood_legs","shield":"wood_shield","ability":"traveler_knot"};main.input_latched=false
   for i in range(3):await process_frame
   var before:Vector2=p.position
   key(KEY_D,true);await create_timer(.22).timeout;key(KEY_D,false)
   check(p.position.x>before.x+5 and p.velocity.x>0,"real run moves "+gender+" "+build)
   await create_timer(.18).timeout
   key(KEY_SPACE,true);await physics_frame;await physics_frame;await process_frame;key(KEY_SPACE,false)
   check(p.velocity.y<0 and not p.is_on_floor(),"real jump works for "+gender+" "+build)
   await create_timer(.9).timeout
   check(p.is_on_floor(),"fall lands with unchanged collider for "+gender+" "+build)
   mouse(Vector2(520,340),1);await create_timer(.16).timeout;mouse(Vector2(520,340),0)
   check(p.fighter.mode=="attack","real attack starts fitted pose for "+gender+" "+build)
   await create_timer(.45).timeout
   key(KEY_SHIFT,true);await physics_frame;await physics_frame;await process_frame;key(KEY_SHIFT,false)
   check(p.fighter.mode=="roll" and p.roll_cooldown>0,"real equipped roll works for "+gender+" "+build)
   await create_timer(.5).timeout
   main.combat.damage_player(1,10,p.position+Vector2(-20,0));await process_frame;await RenderingServer.frame_post_draw
   check(p.health<100 and p.appearance.build==build and p.get_node("Collision").shape.size==Vector2(10,28),"damage keeps appearance and hitbox for "+gender+" "+build)
 main.queue_free();await process_frame;print("AVATAR_GAMEPLAY_NATIVE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
