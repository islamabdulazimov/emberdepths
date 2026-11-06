extends SceneTree
const Atlas=preload("res://scripts/visuals/actor_atlas.gd")
var app:Node
var out:="/tmp/ember-quality-review"
class Gallery extends Node2D:
 var time:=0.0
 func _draw() -> void:
  for i in range(6):
   var x:=100+(i%3)*310;var y:=190+(i/3)*245
   draw_rect(Rect2(x-80,y+3,210,2),Color("465e65"))
   var row:=int(time/0.5)%7
   var frame:=int(fposmod(time,0.5)/0.5*Atlas.COUNTS[row])
   draw_set_transform(Vector2(x,y),0,Vector2(3,3))
   # Atlas helper resets the transform; region drawn here keeps the review scale.
   draw_texture_rect_region(Atlas.TEXTURES[Atlas.TEXTURES.keys()[i]],Rect2(-32,-46,64,48),Rect2(frame*64,row*48,64,48))
   draw_set_transform_matrix(Transform2D.IDENTITY)
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run() -> void:
 app=root.get_node("GameApp")
 DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,720)
 var menu=load("res://scenes/menu.tscn").instantiate();root.add_child(menu)
 await shot("main-menu")
 menu.show_character_creator();menu.name_input.text="Эйра";menu.gender.select(1);menu.hair.select(1);menu.skin.select(3);menu.portrait.update_appearance(menu.creator_appearance())
 await shot("character-creator")
 var demo:Dictionary=app.create_character("Эйра",{"gender":"female","hair":"long","skin":3})
 app.create_character("Нор",{"gender":"male","hair":"short","skin":0})
 var demo_world:Dictionary=app.create_world(demo,"Угасший берег","small")
 app.create_world(demo,"Своды тишины","large")
 menu.show_characters();await shot("character-list")
 menu.selected=demo;menu.show_worlds();await shot("world-list")
 menu.show_settings();await shot("video-settings")
 var options=menu.box.get_child(menu.box.get_child_count()-1)
 options.resolution.select(0);options.apply_settings()
 var previous:=Vector2i(app.video.width,app.video.height)
 var start:=Time.get_ticks_msec()
 while app.resolution_pending and Time.get_ticks_msec()-start<17000:await process_frame
 if app.resolution_pending or DisplayServer.window_get_size()!=previous:push_error("Native 15-second resolution rollback failed");quit(1);return
 print("REAL_RESOLUTION_TIMEOUT_OK")
 menu.queue_free();await process_frame
 app.select_world(demo,demo_world,true)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.exploration.set_process(false);main.player.set_physics_process(false);main.interaction.set_process(false);main.encounter.enabled=false;main.fps_label.hide()
 main.world.configure_new();main.world.generate();await process_frame;main.world.solid.update_internals();main.npcs.sync();main.exploration.initialize_loot()
 main.combat.world_time=80
 main.player.appearance={"gender":"female","hair":"long","skin":3}
 main.player.position=main.world.npc_records.julia.position+Vector2(30,0)
 main.select_local_player(1)
 await create_timer(0.25).timeout;await shot("inhabited-settlement")
 var key:=InputEventKey.new();key.physical_keycode=KEY_E;key.keycode=KEY_E;key.pressed=true;Input.parse_input_event(key)
 await process_frame
 key=InputEventKey.new();key.physical_keycode=KEY_E;key.keycode=KEY_E;key.pressed=false;Input.parse_input_event(key)
 if not main.npcs.opened:push_error("E did not open nearby dialogue");quit(1);return
 await shot("julia-dialogue")
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;Input.parse_input_event(click)
 key=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.keycode=KEY_ESCAPE;key.pressed=true;Input.parse_input_event(key)
 await process_frame
 if main.npcs.opened or not main.ui_blocked() or main.interaction.can_use_mouse():push_error("Dialogue close did not latch held mouse");quit(1);return
 click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=false;Input.parse_input_event(click)
 key=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.keycode=KEY_ESCAPE;key.pressed=false;Input.parse_input_event(key)
 await process_frame
 print("REAL_NPC_KEYBOARD_AND_MOUSE_LATCH_OK")
 main.player.position=main.world.npc_records.cameron.position+Vector2(30,0);main.select_local_player(1)
 await create_timer(0.25).timeout;main.npcs.talk("cameron");await shot("cameron-dialogue")
 main.npcs.close_dialogue();main.get_node("HUD").hide();main.inventory_ui.hide();main.npcs.layer.hide()
 main.player.get_node("Camera2D").enabled=false
 var overview:=Camera2D.new();main.add_child(overview);overview.position=Vector2(main.world.world_width*8,main.world.world_depth*8);overview.zoom=Vector2.ONE*960.0/(main.world.world_width*16);overview.make_current();overview.force_update_scroll()
 await create_timer(0.15).timeout;await shot("natural-world-overview")
 main.queue_free();await process_frame
 RenderingServer.set_default_clear_color(Color("18252e"))
 var gallery:=Gallery.new();root.add_child(gallery)
 for i in range(6):
  var label:=Label.new();label.position=Vector2(20+i%3*310,25+i/3*245);label.text=Atlas.TEXTURES.keys()[i];gallery.add_child(label)
 var heading:=Label.new();heading.position=Vector2(20,510);heading.text="idle · move · preparation · contact · recovery · hurt · death / original pixel atlases";gallery.add_child(heading)
 DirAccess.make_dir_recursive_absolute(out+"/frames")
 for frame in range(420):
  gallery.time=frame/60.0;gallery.queue_redraw()
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"/frames/frame-%04d.png"%frame)
  if frame==80:root.get_texture().get_image().save_png(out+"/creature-animation-gallery.png")
 print("QUALITY_REVIEW_OK")
 gallery.queue_free();await process_frame;quit()
