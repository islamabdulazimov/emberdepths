extends SceneTree
var main:Node2D
var out:="/tmp/recast-sample"
var before:=false
func _initialize() -> void:call_deferred("run")
func capture(name:String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
  if arg=="--before":before=true
 DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,720)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.exploration.set_process(false);main.player.set_physics_process(false);main.interaction.set_process(false);main.encounter.enabled=false
 main.combat.world_time=80
 for x in range(80,112):
  for y in range(12,22):main.world.apply_edit(Vector2i(x,y),-1)
  for y in range(22,26):main.world.apply_edit(Vector2i(x,y),2 if x>=101 else (0 if y==22 else 1))
 main.world.heights.fill(22);main.world.solid.update_internals()
 main.world.trees=[{"cell":Vector2i(90,22),"height":6,"form":0,"seed":8321,"active":true}]
 main.world.apply_decoration("torch",Vector2i(98,20),1)
 var bag=main.items.local_inventory();bag.load_data([]);bag.add("wood",80);bag.add("stone",40);bag.add("emberstone",8);bag.add("torch",12);bag.add("stone_pick",1)
 if before:bag.add("stone_blade",1)
 else:
  for item in ["wood_sword","wood_shield","wood_helm","wood_armor","wood_legs"]:
   if not bag.craft(item):push_error("Sample craft failed: "+item);quit(1);return
  for i in range(30):
   var item:String=bag.item_at(i)
   if item.begins_with("wood_") and item not in ["wood_block","wood_wall"]:main.equipment_service.move(1,i,preload("res://data/items.gd").DEFINITIONS[item].equip_slot)
 main.interaction.selected_slot=9
 main.player.position=Vector2(96*16+8,22*16-10);main.player.velocity=Vector2.ZERO
 main.select_local_player(1);main.player.get_node("Camera2D").zoom=Vector2(2,2);main.player.get_node("Camera2D").reset_smoothing()
 var id:int=main.combat.spawn_entity("seamling",main.player.position+Vector2(34,10))
 var enemy=main.combat.entities[id];enemy.set_process(false)
 main.fps_label.hide();main.inventory_ui.refresh();main.interaction._process(0)
 await create_timer(0.25).timeout
 await capture("game")
 if not before:
  var worn:Dictionary=main.player.equipment.duplicate();main.player.equipment={"weapon":"","head":"","body":"","legs":"","shield":""}
  await capture("unarmored-game");main.player.equipment=worn
 main.inventory_ui.toggle();await create_timer(0.2).timeout;await capture("inventory")
 if not before:
  main.inventory_ui.hover(main.inventory_ui.gear_buttons.body);await capture("equipment-tooltip")
 main.inventory_ui.toggle()
 main.player.set_process(false)
 if not before:
  DirAccess.make_dir_recursive_absolute(out+"/frames")
  for frame in range(240):
   var t:=frame/60.0;var axis:=0.0
   if t>=0.3 and t<0.8:axis=-1
   elif t>=0.8 and t<1.3:axis=1
   main.player.velocity=Vector2(axis*115,0);main.player.position.x+=axis*115/60.0
   if axis!=0:main.player.facing=int(axis)
   if frame==120:main.items.swing(main.player,9,Vector2.RIGHT)
   if frame==180:main.combat.start_defense(1,"parry")
   main.combat.tick_fighter(main.player,1.0/60)
   main.player._process(1.0/60)
   enemy.attack_state="windup" if t<0.7 else ("active" if t<0.88 else "recovery")
   enemy.attack_elapsed=fposmod(t,1.0);enemy._process(1.0/60)
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/frames/%04d.png"%frame)
 if not before:
  main.world.configure_new();main.world.generate();await process_frame;main.world.solid.update_internals();main.npcs.sync();main.exploration.initialize_loot()
  main.player.position=main.world.npc_records.julia.position+Vector2(28,0);main.player.velocity=Vector2.ZERO;main.select_local_player(1)
  await create_timer(.2).timeout;main.npcs.talk("julia");await capture("julia");main.npcs.close_dialogue()
  main.player.position=main.world.npc_records.cameron.position+Vector2(28,0);main.select_local_player(1)
  await create_timer(.2).timeout;main.npcs.talk("cameron");await capture("cameron")
 print("RECAST_SAMPLE_RENDER_OK · ",out)
 main.queue_free();await process_frame;quit()
