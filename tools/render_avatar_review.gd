extends SceneTree
var main:Node2D
var actors:Array=[]
var labels:Array[Label]=[]
func _initialize() -> void:call_deferred("run")
func capture(path:String) -> void:
 for i in range(actors.size()):labels[i].position=actors[i].get_global_transform_with_canvas().origin+Vector2(-45,-98)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.items.set_physics_process(false);main.interaction.set_process(false);main.exploration.set_process(false);main.encounter.enabled=false;main.combat.world_time=90;main.get_node("HUD").hide();main.survival.layer.hide();main.inventory_ui.hide()
 for x in range(78,120):
  for y in range(6,25):main.world.apply_edit(Vector2i(x,y),-1)
  main.world.apply_edit(Vector2i(x,25),0)
 for tree in main.world.trees:tree.active=false
 main.world.solid.update_internals()
 main.add_player(2,Vector2(1576,390));actors=[main.player,main.get_node("Players/2")]
 var layer:=CanvasLayer.new();main.add_child(layer)
 for i in range(2):
  var p=actors[i];p.position=Vector2(1480+i*76,390);p.set_physics_process(false);p.appearance={"gender":"male" if i==0 else "female","build":"normal","hair":"short","hair_color":0,"skin":1};p.equipment=preload("res://data/equipment.gd").empty();p.equipment.weapon="wood_sword";p.facing=1
  var label:=Label.new();label.theme=preload("res://scripts/visuals/art_direction.gd").theme();label.text="Мужская" if i==0 else "Женская";label.add_theme_font_size_override("font_size",13);label.add_theme_color_override("font_outline_color",Color("18252e"));label.add_theme_constant_override("outline_size",2);layer.add_child(label);labels.append(label)
 main.items.local_inventory().load_data([])
 var camera:Camera2D=main.player.get_node("Camera2D");camera.position=Vector2(38,-35);camera.position_smoothing_enabled=false
 for i in range(5):await process_frame
 var out:="/tmp/ember-avatar-review";DirAccess.make_dir_recursive_absolute(out+"/frames")
 await capture(out+"/normal.png")
 for p in actors:p.equipment.merge({"head":"wood_helm","body":"wood_armor","legs":"wood_legs","shield":"wood_shield"},true)
 await capture(out+"/normal-armored.png")
 for p in actors:p.equipment=preload("res://data/equipment.gd").empty();p.equipment.weapon="wood_sword"
 for f in range(180):
  for i in range(2):
   var p=actors[i];p.velocity=Vector2(115 if f>=60 and f<120 else 0,0);p.position.x=1480+i*76+(maxi(0,mini(f-60,60))/60.0*115)
   p.fighter.reset()
   if f>=120 and f<149:p.fighter.mode="attack";p.fighter.elapsed=(f-120)/60.0;p.fighter.duration=.47;p.held_item="wood_sword"
   p.visual_clock=(f-60)/60.0*115/(20.0/.42)*TAU if f>=60 and f<120 else 0
  main._process(0);await capture(out+"/frames/%04d.png"%f)
 main.queue_free();await process_frame;print("AVATAR_NORMAL_REVIEW_OK");quit()
