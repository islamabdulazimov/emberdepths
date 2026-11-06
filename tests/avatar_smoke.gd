extends SceneTree
const A=preload("res://data/appearance.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var legacy:={"gender":"female","hair":"long","skin":4}
 var old:Dictionary=A.clean(legacy)
 check(A.valid(legacy) and old.build=="normal" and old.hair_color==0 and old.hair=="long" and old.skin==4,"legacy appearance receives compatible defaults")
 var count:=0;var all_valid:=true
 for gender in ["male","female"]:
  for build in A.BUILDS:
   for hair in A.HAIRS:
    for color in range(A.HAIR_COLORS.size()):
     for skin in range(5):
      var look:={"gender":gender,"build":build,"hair":hair,"hair_color":color,"skin":skin}
      all_valid=all_valid and A.valid(look) and A.clean(look)==look;count+=1
 check(all_valid and count==1080,"all 1080 cosmetic combinations validate and normalize identically")
 for bad in [{"build":"giant"},{"hair":"unknown"},{"hair_color":99},{"hair_color":NAN},{"skin":INF},{"gender":"unknown"}]:
  var value:Dictionary=A.DEFAULT.duplicate();value.merge(bad,true)
  check(not A.valid(value),"reject invalid cosmetic choice "+str(bad.keys()))
 var injected:Dictionary=A.DEFAULT.duplicate();injected.speed=999
 check(not A.clean(injected).has("speed"),"normalization strips gameplay fields from cosmetics")
 var menu=load("res://scenes/menu.tscn").instantiate();root.add_child(menu);menu.show_character_creator();await process_frame
 check(menu.gender.item_count==2 and menu.body_build.item_count==3 and menu.hair.item_count==6 and menu.hair_color.item_count==6 and menu.skin.item_count==5,"creator exposes all agreed choices")
 menu.gender.select(1);menu.body_build.select(2);menu.hair.select(4);menu.hair_color.select(2);menu.skin.select(4)
 var selected:Dictionary=menu.creator_appearance();menu.portrait.update_appearance(selected)
 check(menu.portrait.body.appearance==selected and selected.build=="sturdy" and selected.hair=="long_braid","preview reads selected full appearance")
 menu.portrait.set_preview("run");menu.portrait._process(.2)
 check(menu.portrait.body.velocity.x==115 and not menu.portrait.body.is_physics_processing(),"run preview animates without physical movement")
 menu.portrait.set_preview("attack");menu.portrait._process(.13)
 check(menu.portrait.body.fighter.mode=="attack" and menu.portrait.body.held_item=="wood_sword","attack preview uses real action and weapon renderer")
 menu.portrait.set_preview("idle");menu.portrait._process(0)
 check(menu.portrait.body.fighter.mode=="idle" and menu.portrait.body.velocity==Vector2.ZERO,"idle preview clears action")
 menu.name_input.text="Облик";menu.save_character()
 check(menu.selected.appearance==selected,"new character persists every chosen field")
 var character:Dictionary=menu.selected.duplicate(true)
 menu.queue_free();await process_frame
 var app=root.get_node("GameApp");app.selected_character=character;app.selected_world={}
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.survival.set_physics_process(false);main.items.set_physics_process(false);main.player.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false
 check(main.player.appearance==selected,"real game receives identical full appearance")
 main.equipment_service.starter(1)
 var resources:Dictionary=main.player.resources.snapshot()
 var collider:Vector2=main.player.get_node("Collision").shape.size
 for gender in ["male","female"]:
  for build in A.BUILDS:
   var look:Dictionary=selected.duplicate();look.gender=gender;look.build=build;main.player.appearance=look
   check(main.player.get_node("Collision").shape.size==collider and collider==Vector2(10,28) and main.player.resources.snapshot()==resources,"unchanged collision and resources for "+gender+" "+build)
 main.player.appearance=selected
 var state:Dictionary=main.saves.capture()
 check(preload("res://scripts/save_schema.gd").validate(state)=="","save schema accepts complete new appearance")
 main.player.appearance=A.DEFAULT.duplicate()
 check(main.saves.restore(state)=="" and main.player.appearance==selected,"world save restore keeps every appearance field")
 main.player.set_physics_process(false)
 main.player.hurt_immunity=0;main.combat.damage_player(1,10000,main.player.position,true)
 check(main.player.dead and main.player.appearance==selected,"downing never resets body build or hair color")
 main.survival.respawn_request(1)
 check(not main.player.dead and main.player.appearance==selected,"respawn retains the selected appearance")
 var invalid:Dictionary=main.saves.capture();invalid.profiles[invalid.host_profile].life.appearance.build="invalid"
 check(preload("res://scripts/save_schema.gd").validate(invalid)!="","save schema rejects invalid new appearance")
 main.queue_free();await process_frame;print("AVATAR_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
