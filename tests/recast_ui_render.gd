extends SceneTree
var failures:=0
var checks:=0
var main:Node2D
var last_mouse:=Vector2.ZERO
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func mouse(at:Vector2,pressed:int=-1) -> void:
 var physical:Vector2=root.get_screen_transform()*at
 Input.warp_mouse(physical)
 var move:=InputEventMouseMotion.new();move.position=physical;move.global_position=physical;move.relative=physical-last_mouse;last_mouse=physical;move.button_mask=MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0;Input.parse_input_event(move)
 if pressed!=-1:
  var e:=InputEventMouseButton.new();e.position=physical;e.global_position=physical;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed==1;Input.parse_input_event(e)
func key(code:Key,pressed:bool) -> void:
 var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e)
func drag(source:Control,target:Control) -> void:
 var from:=source.get_global_rect().get_center();var to:=target.get_global_rect().get_center()
 mouse(from);await process_frame;mouse(from,1);await process_frame
 for i in range(6):mouse(from.lerp(to,(i+1)/6.0));await process_frame
 mouse(to,0);await process_frame;await process_frame
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.player.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false
 for i in range(4):await process_frame
 var bag=main.items.local_inventory();bag.load_data([]);bag.add("wood_helm",1);bag.add("wood_shield",1);bag.add("wood_sword",1)
 key(KEY_ESCAPE,true);await process_frame;key(KEY_ESCAPE,false);await process_frame
 check(main.inventory_ui.opened,"real Esc opens rebuilt inventory")
 main.inventory_ui.refresh();await process_frame
 await drag(main.inventory_ui.bag_buttons[0],main.inventory_ui.gear_buttons.head)
 check(main.player.equipment.head=="wood_helm" and bag.item_at(0)=="","actual mouse drag equips helmet without copy")
 key(KEY_SHIFT,true);await process_frame
 var at:Vector2=main.inventory_ui.bag_buttons[1].get_global_rect().get_center();mouse(at,1);await process_frame;mouse(at,0);await process_frame;key(KEY_SHIFT,false);await process_frame
 check(main.player.equipment.shield=="wood_shield" and bag.item_at(1)=="","real Shift click equips shield")
 check(main.player.resources.stamina==100 and main.player.fighter.mode=="idle","Shift inside inventory never rolls or attacks")
 await drag(main.inventory_ui.gear_buttons.head,main.inventory_ui.bag_buttons[5])
 check(main.player.equipment.head=="" and bag.item_at(5)=="wood_helm","actual drag unequips into selected bag cell")
 await drag(main.inventory_ui.bag_buttons[2],main.inventory_ui.gear_buttons.head)
 check(main.player.equipment.head=="" and bag.item_at(2)=="wood_sword","wrong gear slot rejects drag without loss")
 # Full inventory with an equipped item: a click must not destroy or drop it.
 bag.load_data([])
 for i in range(30):bag.slots[i]={"item":"dirt","count":99}
 main.player.equipment.head="wood_helm";main.inventory_ui.refresh();await process_frame
 at=main.inventory_ui.gear_buttons.head.get_global_rect().get_center();mouse(at,1);await process_frame;mouse(at,0);await process_frame
 check(main.player.equipment.head=="wood_helm" and bag.count_item("dirt")==2970,"full bag rejects actual unequip click")
 for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=size;await process_frame;await process_frame
  var ui=main.inventory_ui
  var viewport:=root.get_visible_rect()
  var fits:=true
  for panel in [ui.bag,ui.gear_panel,ui.crafting]:fits=fits and viewport.encloses(panel.get_global_rect())
  check(fits,"inventory panels fit "+str(size))
  mouse(viewport.size-Vector2(2,2));await process_frame
  ui.hover(ui.gear_buttons.head)
  for i in range(3):await process_frame
  check(viewport.encloses(ui.tooltip.get_global_rect()),"tooltip stays on screen "+str(size))
  check(ui.tooltip_label.text.contains("Надето") and ui.tooltip_label.text.contains("Защита"),"tooltip compares equipped stats")
  root.get_texture().get_image().save_png("/tmp/recast-inventory-%dx%d.png"%[size.x,size.y])
  ui.unhover(ui.gear_buttons.head)
 check(not main.interaction.can_use_mouse(),"inventory interface blocks world use")
 mouse(main.inventory_ui.bag_buttons[0].get_global_rect().get_center(),1);await process_frame
 key(KEY_ESCAPE,true);await process_frame;key(KEY_ESCAPE,false);await process_frame
 check(not main.inventory_ui.opened and main.input_latched and not main.interaction.can_use_mouse(),"closing inventory with held mouse never attacks or mines")
 mouse(Vector2(300,300),0);await process_frame
 main.queue_free();await process_frame;print("RECAST_UI_RENDER_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
