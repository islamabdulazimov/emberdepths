extends "res://tests/recast_ui_render.gd"
var menu:Control
func choose(option:OptionButton,index:int) -> void:
 var at:=option.get_global_rect().get_center();mouse(at,1);await process_frame;mouse(at,0);await process_frame;await process_frame
 check(option.get_popup().visible,"real dropdown opens: "+option.get_parent().get_child(0).text)
 option.get_popup().set_focused_item(0);await process_frame
 for i in range(index):key(KEY_DOWN,true);await process_frame;key(KEY_DOWN,false);await process_frame
 key(KEY_ENTER,true);await process_frame;key(KEY_ENTER,false);await process_frame;await process_frame
 check(option.selected==index,"keyboard selects dropdown entry %d"%index)
func click_text(value:String) -> void:
 for control in menu.content.find_children("*","Button",true,false):
  if control.text==value:
   var at:Vector2=control.get_global_rect().get_center();mouse(at,1);await process_frame;mouse(at,0);await process_frame;await process_frame;return
 check(false,"missing actual UI button "+value)
func shot(name:String) -> void:
 await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/avatar-"+name+".png")
func run() -> void:
 root.size=Vector2i(1280,720)
 menu=load("res://scenes/menu.tscn").instantiate();root.add_child(menu);menu.show_character_creator()
 for i in range(4):await process_frame
 await choose(menu.gender,1);await choose(menu.body_build,2);await choose(menu.hair,4);await choose(menu.hair_color,2);await choose(menu.skin,4)
 var expected:={"gender":"female","build":"sturdy","hair":"long_braid","hair_color":2,"skin":4}
 check(menu.portrait.body.appearance==expected,"five actual dropdowns update complete preview")
 var before:Vector2=menu.portrait.body.position
 await click_text("Бег");await create_timer(.2).timeout
 check(menu.portrait.preview_mode=="run" and menu.portrait.body.velocity.x==115 and menu.portrait.body.position==before,"actual Run button changes animation without moving preview")
 await shot("creator-run")
 await click_text("Удар");await create_timer(.16).timeout
 check(menu.portrait.preview_mode=="attack" and menu.portrait.body.fighter.mode=="attack","actual Attack button shows live action")
 await shot("creator-attack")
 await click_text("Покой")
 check(menu.portrait.preview_mode=="idle","actual Idle button returns preview")
 for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=size;await process_frame;await process_frame
  check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(menu.content.get_global_rect()),"creator panel fits "+str(size))
  check(menu.skin.get_global_rect().end.y<menu.content.get_global_rect().end.y,"last choice remains visible "+str(size))
 root.size=Vector2i(1280,720);await process_frame;await process_frame
 menu.name_input.text="Искра";await click_text("Далее — создать мир")
 check(menu.page=="create_world" and menu.selected.appearance==expected,"actual Next button saves complete chosen appearance")
 menu.queue_free();await process_frame;print("AVATAR_CREATOR_NATIVE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
