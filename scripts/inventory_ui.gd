extends CanvasLayer
const Art=preload("res://scripts/visuals/art_direction.gd")
const Recipes=preload("res://data/recipes.gd")
const Items=preload("res://data/items.gd")
const Gear=preload("res://data/equipment.gd")
var main:Node2D
var opened:=false
var source_slot:=-1
var quick_buttons:Array[Button]=[]
var bag_buttons:Array[Button]=[]
var storage_buttons:Array[Button]=[]
var gear_buttons:Dictionary={}
var bag:PanelContainer
var crafting:PanelContainer
var gear_panel:PanelContainer
var storage_panel:PanelContainer
var feedback:Label
var recipe_buttons:Dictionary={}
var clock:=0.0
var storage_anchor:=Vector2i(-1,-1)
var storage_requested:=false
var storage_slots:Array=[]
var storage_revision:=0
var source_box:=false
var notice_left:=0.0
var visual_alpha:=0.0
var slot_styles:Array[StyleBoxFlat]=[]
var art_theme:Theme
var tooltip:PanelContainer
var tooltip_label:Label
var hovered:Button
var gear_portrait:Control
func panel(at:Vector2,width:float,title:String) -> VBoxContainer:
 var frame:=PanelContainer.new();frame.theme=art_theme;frame.position=at;frame.custom_minimum_size.x=width;add_child(frame)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);frame.add_child(box)
 var label:=Label.new();label.text=title;label.add_theme_font_size_override("font_size",17);box.add_child(label)
 return box
func slot(domain:String,index:int,gear:String="") -> Button:
 var button:=Button.new();button.set_script(preload("res://scripts/ui/item_slot.gd"));button.ui=self;button.domain=domain;button.index=index;button.gear_slot=gear;button.theme=art_theme;button.custom_minimum_size=Vector2(38,42)
 return button
func _ready() -> void:
 main=get_parent();art_theme=Art.theme();layer=3
 for selected in [false,true]:
  var style:=Art.panel(Color("263a44") if selected else Color("17232e"),Color("d0ae79") if selected else Color("40565d"));style.set_border_width_all(2 if selected else 1);slot_styles.append(style)
 var quick:=HBoxContainer.new();quick.position=Vector2(264,480);quick.add_theme_constant_override("separation",3);add_child(quick)
 for i in range(10):
  var button:=slot("bag",i);button.slot_number=str((i+1)%10);quick.add_child(button);quick_buttons.append(button);button.pressed.connect(func():main.interaction.selected_slot=i)
 var layout:=panel(Vector2(178,106),426,"ПОХОДНАЯ СУМКА  /  30")
 bag=layout.get_parent()
 var grid:=GridContainer.new();grid.columns=10;grid.add_theme_constant_override("h_separation",3);grid.add_theme_constant_override("v_separation",3);layout.add_child(grid)
 for i in range(30):
  var button:=slot("bag",i);grid.add_child(button);bag_buttons.append(button);button.pressed.connect(func():_click_slot(i))
 var hint:=Label.new();hint.text="Перетащи предмет или выбери два слота.\nShift + клик: экипировать / быстро перенести.";hint.add_theme_font_size_override("font_size",12);layout.add_child(hint)
 var gear_layout:=panel(Vector2(20,106),146,"СНАРЯЖЕНИЕ")
 gear_panel=gear_layout.get_parent()
 gear_portrait=Control.new();gear_portrait.set_script(preload("res://scripts/ui/portrait.gd"));gear_portrait.custom_minimum_size=Vector2(120,98);gear_portrait.appearance=main.player.appearance;gear_layout.add_child(gear_portrait)
 for key in Gear.SLOTS:
  var row:=HBoxContainer.new();gear_layout.add_child(row)
  var button:=slot("gear",0,key);row.add_child(button);gear_buttons[key]=button;button.pressed.connect(func():_gear_click(key))
  var label:=Label.new();label.text=Gear.LABELS[key];label.add_theme_font_size_override("font_size",12);row.add_child(label)
 var craft_list:=panel(Vector2(622,106),318,"РЕМЕСЛО")
 crafting=craft_list.get_parent()
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(296,306);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;craft_list.add_child(scroll)
 var recipes:=VBoxContainer.new();scroll.add_child(recipes)
 var recipe_order:Array=["wood_sword","wood_shield","wood_helm","wood_armor","wood_legs"]
 for key in Recipes.DEFINITIONS:
  if key not in recipe_order:recipe_order.append(key)
 for recipe_id in recipe_order:
  var button:=Button.new();button.custom_minimum_size=Vector2(280,60);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",12);button.clip_text=true;button.icon=Items.icon(Recipes.DEFINITIONS[recipe_id].output);button.add_theme_constant_override("icon_max_width",24);button.expand_icon=true;recipes.add_child(button);recipe_buttons[recipe_id]=button;button.pressed.connect(func():_craft(recipe_id))
 var store:=panel(Vector2(622,106),318,"ОБЩИЙ СУНДУК")
 storage_panel=store.get_parent()
 var storage_grid:=GridContainer.new();storage_grid.columns=6;storage_grid.add_theme_constant_override("h_separation",4);storage_grid.add_theme_constant_override("v_separation",4);store.add_child(storage_grid)
 for i in range(30):
  var button:=slot("chest",i);button.custom_minimum_size=Vector2(44,44);storage_grid.add_child(button);storage_buttons.append(button);button.pressed.connect(func():_storage_click(true,i))
 feedback=Label.new();feedback.position=Vector2(180,372);feedback.size=Vector2(426,62);feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.add_theme_font_size_override("font_size",12);feedback.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(feedback)
 tooltip=PanelContainer.new();tooltip.theme=art_theme;tooltip.mouse_filter=Control.MOUSE_FILTER_IGNORE;tooltip.custom_minimum_size.x=285;add_child(tooltip)
 tooltip_label=Label.new();tooltip_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;tooltip_label.custom_minimum_size.x=265;tooltip_label.add_theme_font_size_override("font_size",12);tooltip_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;tooltip.add_child(tooltip_label);tooltip.hide()
 for frame in [bag,crafting,storage_panel,gear_panel,feedback]:frame.hide()
 refresh()

func toggle() -> void:
 main.input_latched=true
 var pending := storage_requested and not opened
 if storage_requested or storage_anchor != Vector2i(-1,-1): main.network.close_storage_local()
 reset_storage()
 if pending: return
 opened = not opened
 source_slot = -1
 gear_panel.visible=opened
 bag.visible = opened
 crafting.visible = opened
 feedback.visible = opened
 refresh()

func _click_slot(index: int) -> void:
 if Input.is_physical_key_pressed(KEY_SHIFT):quick_move("bag",index);return
 if main.network.stopping or main.player.dead:
  return
 if storage_anchor != Vector2i(-1,-1):
  _storage_click(false,index)
  return
 var inventory = main.items.local_inventory()
 if source_slot == -1:
  if inventory.slots[index].count > 0:
   source_slot = index
 elif source_slot == index:
  source_slot = -1
 else:
  if main.network.active:
   main.network.transfer_local(source_slot, index)
  else:
   main.items.transfer(int(str(main.player.name)), source_slot, index)
  source_slot = -1
 refresh()

func _process(delta: float) -> void:
 if is_instance_valid(main.get("hud_help_label")):main.hud_help_label.visible=not opened and not main.pause_open
 gear_panel.visible=opened
 if is_instance_valid(hovered) and hovered.is_visible_in_tree() and hovered.item!="" and (opened or hovered in quick_buttons):
  tooltip.show();tooltip.position=(get_viewport().get_mouse_position()+Vector2(16,16)).clamp(Vector2(4,4),get_viewport().get_visible_rect().size-tooltip.size-Vector2(4,4))
 else:tooltip.hide()
 visual_alpha = move_toward(visual_alpha,1.0 if opened else 0.0,delta*9)
 for panel in [bag,crafting,storage_panel]: panel.modulate.a = visual_alpha
 notice_left = maxf(0,notice_left-delta)
 if not opened: feedback.visible = notice_left > 0
 clock += delta
 if clock >= 0.1:
  clock = 0.0
  refresh()

func refresh() -> void:
 if not is_instance_valid(main.player):
  return
 var inventory = main.items.local_inventory()
 for key in gear_buttons:
  _paint(gear_buttons[key],{"item":main.player.equipment[key],"count":0 if main.player.equipment[key]=="" else 1},"",false)
 if is_instance_valid(gear_portrait):
  gear_portrait.body.equipment=main.player.equipment.duplicate()
  gear_portrait.body.appearance=main.player.appearance.duplicate()
  gear_portrait.body.unclothed=main.player.unclothed
 for i in range(10):
  _paint(quick_buttons[i], inventory.slots[i], str((i + 1) % 10), i == main.interaction.selected_slot)
 for recipe_id in recipe_buttons:
  var recipe: Dictionary = Recipes.DEFINITIONS[recipe_id]
  var ingredients: PackedStringArray = []
  for item_id in recipe.ingredients:
   ingredients.append("%s %d/%d" % [Items.DEFINITIONS[item_id].name, inventory.count_item(item_id), recipe.ingredients[item_id]])
  var button: Button = recipe_buttons[recipe_id]
  button.text = "%s ×%d\n%s" % [Items.DEFINITIONS[recipe.output].name, recipe.count, " · ".join(ingredients)]
  var status: String = inventory.craft_preview(recipe_id).status
  button.tooltip_text = status + "\n" + " · ".join(ingredients)
  button.disabled = status != "Можно создать" or main.player.dead or main.network.stopping or (main.network.active and not main.network.connected)
 for i in range(30):
  _paint(bag_buttons[i], inventory.slots[i], str(i + 1), i == source_slot and not source_box)
 if storage_anchor != Vector2i(-1,-1) and storage_slots.size() == 30:
  for i in range(30): _paint(storage_buttons[i],storage_slots[i],str(i+1),source_box and i == source_slot)

func reset_storage() -> void:
 storage_requested = false
 storage_anchor = Vector2i(-1,-1)
 storage_slots = []
 storage_revision = 0
 source_slot = -1
 source_box = false
 if is_instance_valid(storage_panel): storage_panel.hide()
 if is_instance_valid(crafting): crafting.visible = opened

func apply_storage_view(anchor: Vector2i, contents: Array, revision: int, message: String = "") -> void:
 if anchor == Vector2i(-1,-1):
  reset_storage()
  if message != "":
   feedback.text = message
   notice_left = 2.5
   feedback.show()
  return
 if not storage_requested: return # Ignore a delayed open after Esc/cancellation.
 if revision != storage_revision or anchor != storage_anchor: source_slot = -1
 storage_anchor = anchor
 storage_slots = contents.duplicate(true)
 storage_revision = revision
 opened = true
 bag.show()
 crafting.hide()
 storage_panel.show()
 feedback.text = message if message != "" else "ЛКМ по стопке → ЛКМ по ячейке назначения · Esc: закрыть"
 feedback.show()
 refresh()

func _storage_click(from_box: bool, index: int) -> void:
 if Input.is_physical_key_pressed(KEY_SHIFT):quick_move("chest" if from_box else "bag",index);return
 if main.network.stopping or main.player.dead or storage_anchor == Vector2i(-1,-1): return
 var slots: Array = storage_slots if from_box else main.items.local_inventory().slots
 if source_slot == -1:
  if slots[index].count > 0:
   source_slot = index
   source_box = from_box
 elif source_box == from_box and source_slot == index:
  source_slot = -1
 else:
  main.network.move_storage_local(storage_anchor,source_box,source_slot,from_box,index,storage_revision)
  source_slot = -1
 refresh()

func _paint(button:Button,value:Dictionary,_number:String,selected:bool) -> void:
 button.item=value.item;button.amount=value.count;button.text="";button.tooltip_text="";button.queue_redraw()
 button.add_theme_stylebox_override("normal",slot_styles[1 if selected else 0])

func _craft(recipe_id: String) -> void:
 if main.network.stopping or main.player.dead:
  return
 if main.network.active:
  main.network.craft_local(recipe_id)
 else:
  show_craft_result(main.items.craft(int(str(main.player.name)), recipe_id))

func show_craft_result(message: String) -> void:
 feedback.text = message
 refresh()

func hover(button:Button) -> void:
 hovered=button
 if button.item=="":return
 var d:Dictionary=Items.DEFINITIONS[button.item]
 var lines:String=d.name+"\n"+Items.description(button.item)+"\n"+Items.stats(button.item)
 var equip:String=d.get("equip_slot","")
 if equip!="":
  var worn:String=main.player.equipment[equip]
  lines+="\nНадето: "+(Items.DEFINITIONS[worn].name+"\n"+Items.stats(worn) if worn!="" else "ничего")
 tooltip_label.text=lines
func unhover(button:Button) -> void:
 if hovered==button:hovered=null;tooltip.hide()
func _gear_click(key:String) -> void:
 var inventory=main.items.local_inventory()
 if source_slot>=0 and not source_box and Items.DEFINITIONS.get(inventory.item_at(source_slot),{}).get("equip_slot","")!=key:
  feedback.text="Этот предмет не подходит: "+Gear.LABELS[key];feedback.show();return
 if source_slot==-1:
  var free:=false
  for entry in inventory.slots:free=free or entry.item==""
  if not free:feedback.text="В сумке нет места — освободи слот. Предмет остался надетым.";feedback.show();return
 if source_slot>=0 and not source_box:main.network.equip_local(source_slot,key);source_slot=-1
 else:main.network.equip_local(-1,key)
 refresh()
func can_drop(target:Button,data:Variant) -> bool:
 if not data is Dictionary or data.get("ui")!=self or not opened or main.player.dead or main.network.stopping:return false
 if data.domain=="chest" and data.revision!=storage_revision:return false
 if data.domain=="bag" and main.items.local_inventory().item_at(data.index)!=data.item:return false
 if data.domain=="gear" and main.player.equipment.get(data.slot,"")!=data.item:return false
 if target.domain=="gear":return data.domain=="bag" and Items.DEFINITIONS.get(data.item,{}).get("equip_slot","")==target.gear_slot
 if data.domain=="gear":return target.domain=="bag" and (target.item=="" or Items.DEFINITIONS.get(target.item,{}).get("equip_slot","")==data.slot)
 return true
func drop(target:Button,data:Dictionary) -> void:
 if not can_drop(target,data):return
 if target.domain=="gear":main.network.equip_local(data.index,target.gear_slot)
 elif data.domain=="gear":main.network.unequip_into_local(data.slot,target.index)
 elif target.domain=="chest" or data.domain=="chest":main.network.move_storage_local(storage_anchor,data.domain=="chest",data.index,target.domain=="chest",target.index,storage_revision)
 else:main.network.transfer_local(data.index,target.index)
 source_slot=-1;refresh()
func quick_move(domain:String,index:int) -> void:
 if main.player.dead or main.network.stopping:return
 var from_box:=domain=="chest"
 var source:Array=storage_slots if from_box else main.items.local_inventory().slots
 if index<0 or index>=source.size() or source[index].count==0:return
 var item:String=source[index].item
 if storage_anchor==Vector2i(-1,-1) and Items.DEFINITIONS[item].has("equip_slot"):
  main.network.equip_local(index,Items.DEFINITIONS[item].equip_slot);refresh();return
 if storage_anchor!=Vector2i(-1,-1):main.network.quick_move_local(index,storage_anchor,from_box,storage_revision)
 else:main.network.quick_move_local(index)
 source_slot=-1;refresh()
