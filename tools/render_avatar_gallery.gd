extends SceneTree
var main:Node2D
var actors:Array=[]
var title:Label
func _initialize() -> void:call_deferred("run")
func label(parent:Node,text:String,at:Vector2,size:int=12) -> Label:
 var l:=Label.new();l.theme=preload("res://scripts/visuals/art_direction.gd").theme();l.text=text;l.position=at;l.add_theme_font_size_override("font_size",size);parent.add_child(l);return l
func shot(path:String) -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(path)
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.items.set_physics_process(false);main.interaction.set_process(false);main.exploration.set_process(false);main.encounter.enabled=false
 main.get_node("Players").hide();main.world.hide();main.get_node("HUD").hide();main.survival.layer.hide();main.inventory_ui.hide()
 var layer:=CanvasLayer.new();layer.layer=15;main.add_child(layer)
 var bg:=ColorRect.new();bg.color=Color("18252e");bg.size=Vector2(960,540);layer.add_child(bg)
 title=label(layer,"МОДЕЛИ И ПРИЧЁСКИ",Vector2(18,12),19)
 var holder:=Node2D.new();layer.add_child(holder)
 var a=preload("res://data/appearance.gd")
 for col in range(6):label(layer,["Короткая","Набок","Кудри","Распущенные","Коса","Хвост"][col],Vector2(160+col*128,47),11)
 for row in range(6):
  var gender:String="male" if row<3 else "female";var build:String=a.BUILDS[row%3]
  label(layer,("Мужская" if row<3 else "Женская")+"\n"+a.BUILD_NAMES[row%3],Vector2(18,91+row*70),12)
  for col in range(6):
   var p=load("res://scenes/player.tscn").instantiate();p.appearance={"gender":gender,"build":build,"hair":a.HAIRS[col],"hair_color":col,"skin":row%5};p.get_node("Camera2D").enabled=false;p.collision_layer=0;p.collision_mask=0;holder.add_child(p);p.get_node("Camera2D").enabled=false;p.set_physics_process(false);p.position=Vector2(184+col*128,125+row*70);p.scale=Vector2(1.5,1.5);actors.append(p)
 var out:="/tmp/ember-avatar-gallery";DirAccess.make_dir_recursive_absolute(out+"/frames")
 await shot(out+"/fits-and-hair.png")
 for p in actors:p.equipment.merge({"head":"wood_helm","body":"wood_armor","legs":"wood_legs","shield":"wood_shield","weapon":"wood_sword"},true)
 title.text="ПОСАДКА ДЕРЕВЯННОГО КОМПЛЕКТА"
 await shot(out+"/fitted-armor.png")
 for p in actors:p.queue_free()
 actors.clear();await process_frame
 # Six live Player renderers, identical scale, settings and action clock.
 for row in range(6):
  var p=load("res://scenes/player.tscn").instantiate();p.appearance={"gender":"male" if row<3 else "female","build":a.BUILDS[row%3],"hair":"long_braid" if row%2 else "short_swept","hair_color":row,"skin":row%5};p.get_node("Camera2D").enabled=false;p.collision_layer=0;p.collision_mask=0;holder.add_child(p);p.set_physics_process(false);p.get_node("Camera2D").enabled=false;p.position=Vector2(175+row%3*260,240+floori(row/3.0)*230);p.scale=Vector2(3,3);p.equipment.weapon="wood_sword";actors.append(p)
 for child in layer.get_children():
  if child is Label and child!=title:child.hide()
 label(layer,"Мужская",Vector2(18,125),13)
 label(layer,"Женская",Vector2(18,355),13)
 for col in range(3):label(layer,a.BUILD_NAMES[col],Vector2(135+col*260,90),13)
 for f in range(420):
  var action:="Покой";var t:=f/60.0
  for p in actors:
   p.dead=false;p.health=100;p.velocity=Vector2.ZERO;p.fighter.reset();p.visual_idle_clock=t;p.visual_death_age=maxf(0,t-4.8)
   p.visual_grounded=true;p.visual_landing=0;p.visual_hurt=0
   if f>=48 and f<120:p.velocity=Vector2(115,0);p.visual_clock=t*115/(20/.42)*TAU;action="Бег"
   elif f>=120 and f<150:p.velocity.y=-180;p.visual_grounded=false;p.visual_air_time=.2;action="Прыжок"
   elif f>=150 and f<174:p.velocity.y=180;p.visual_grounded=false;action="Падение"
   elif f>=174 and f<204:p.fighter.mode="attack";p.fighter.elapsed=(f-174)/60.0;p.fighter.duration=.47;p.held_item="wood_sword";action="Удар"
   elif f>=204 and f<232:p.fighter.mode="roll";p.fighter.elapsed=(f-204)/60.0;p.fighter.duration=.44;action="Перекат"
   elif f>=232 and f<264:p.fighter.mode="hurt";p.fighter.elapsed=(f-232)/60.0;p.fighter.duration=.54;action="Получение урона"
   elif f>=264 and f<330:p.dead=true;p.health=0;p.visual_death_age=(f-264)/60.0;action="Упавший · дыхание"
   elif f>=330 and f<372:p.revive_immunity=1.5;p.self_modulate.a=.58;action="После поднятия"
   elif f>=372:p.revive_immunity=0;p.self_modulate.a=1;p.equipment.merge({"head":"wood_helm","body":"wood_armor","legs":"wood_legs","shield":"wood_shield"},true);action="В броне"
   p.visual_speed=p.velocity.x;p.visual_action_time=p.fighter.elapsed;p.set_process(false);p.queue_redraw()
  title.text=action+" · три телосложения каждой модели"
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"/frames/%04d.png"%f)
 main.queue_free();await process_frame;print("AVATAR_GALLERY_OK");quit()
