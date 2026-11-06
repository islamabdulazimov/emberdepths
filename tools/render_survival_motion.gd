extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1280,720)
 var main=load("res://scenes/combat_arena.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.items.set_physics_process(false);main.interaction.set_process(false);main.exploration.set_process(false);main.encounter.set_physics_process(false);main.combat.spawning_enabled=false
 for id in main.combat.entities.keys():main.combat.set_entity(id,{},false,false)
 main.player.set_physics_process(false);main.player.hurt_immunity=0;main.player.money=101;main.equipment_service.starter(1)
 main.equipment_service.move(1,0,"weapon")
 main.add_player(2,main.player.position+Vector2(26,0));var helper=main.get_node("Players/2");helper.profile_id="2".repeat(32);helper.set_physics_process(false)
 main.items.inventory_for(2).add("spark_binding",2)
 var mob:int=main.combat.spawn_entity("ashling",main.player.position+Vector2(120,0));main.combat.entities[mob].money=17
 main.combat.world_time=90;main.combat.damage_player(1,1000,main.player.position,true)
 main.fps_label.hide()
 var directory:="/tmp/ember-survival-motion";DirAccess.make_dir_recursive_absolute(directory+"/frames")
 for i in range(360):
  if i>=60 and i<300:main.survival.intent(2,1,true);main.survival.tick_help(1.0/60)
  if i>=300:main.player.revive_immunity=maxf(0,main.player.revive_immunity-1.0/60)
  helper.resource_sync=0
  main.player.visual_idle_clock=i/60.0;helper.visual_idle_clock=i/60.0
  main.survival._process(0);main.interaction._process(0);main._process(0)
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(directory+"/frames/%04d.png"%i)
  if i in [40,190,310]:root.get_texture().get_image().save_png(directory+"/state-%d.png"%i)
 main.queue_free();await process_frame;print("SURVIVAL_MOTION_RENDER_OK");quit()
