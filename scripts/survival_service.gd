extends Node2D
signal coin_changed(id:int,data:Dictionary)
signal recovery_changed(id:int)
const Rules=preload("res://data/survival.gd")
var main:Node2D
var coins:Dictionary={}
var next_id:=1
var recovery:Dictionary={}
var recovery_dirty:Dictionary={}
var recovering:=false
var intents:Dictionary={}
var channels:Dictionary={}
var input_target:=0
var intent_clock:=0.0
var watching:=0
var layer:CanvasLayer
var down_panel:PanelContainer
var message:Label
var observe:Button
var prompt:Label
var wallet:Label
func _ready() -> void:
 main=get_parent();_build_ui()
 main.items.inventory_changed.connect(func(id):
  if not recovering:recovery_dirty[id]=true)
func player(id:int) -> CharacterBody2D:return main.get_node("Players").get_node_or_null(str(id))
func safe_position(at:Vector2) -> Vector2:
 var cell:Vector2i=main.world.cell_at(at)
 if cell.x>=1 and cell.x<main.world.world_width-1 and cell.y>=1 and cell.y<main.world.world_depth-1 and main.world.block_at(cell)==-1:return at
 return main.world.safe_spawn_position(clampi(cell.x,2,main.world.world_width-3))
func spawn_money(amount:int,at:Vector2) -> int:
 if not main.combat.authoritative() or amount<=0 or amount>Rules.MAX_MONEY:return -1
 var id:=next_id;next_id+=1
 set_coin(id,{"amount":amount,"position":safe_position(at),"velocity":Vector2(0,-50),"age":0.0})
 coin_changed.emit(id,coin_data(id));return id
func coin_data(id:int) -> Dictionary:
 var c=coins[id]
 return {"amount":c.amount,"position":c.position,"velocity":c.velocity,"age":c.age}
func set_coin(id:int,data:Dictionary) -> void:
 if data.is_empty():
  if coins.has(id):remove_child(coins[id]);coins[id].queue_free();coins.erase(id)
  return
 if not coins.has(id):
  var c:=CharacterBody2D.new();c.set_script(preload("res://scripts/coin.gd"));add_child(c);coins[id]=c
 var c=coins[id];c.amount=int(data.amount);c.position=data.position;c.velocity=data.velocity;c.age=float(data.age)
 next_id=maxi(next_id,id+1)
func snapshot(private:bool=false) -> Dictionary:
 var result:={"coins":{},"next_id":next_id}
 for id in coins:result.coins[id]=coin_data(id)
 if private:result.recovery=recovery.duplicate(true)
 return result
func restore(state:Dictionary) -> void:
 for id in coins.keys():set_coin(id,{})
 intents.clear();channels.clear();input_target=0;watching=0
 recovery_dirty.clear()
 for p in main.get_node("Players").get_children():recovery_dirty[int(str(p.name))]=true
 next_id=int(state.get("next_id",1));recovery=state.get("recovery",{}).duplicate(true)
 for id in state.get("coins",{}):set_coin(id,state.coins[id])
func motion() -> Dictionary:
 var result:Dictionary={}
 for id in coins:result[id]=coins[id].position
 return result
func apply_motion(data:Dictionary) -> void:
 for id in data:
  if coins.has(id):coins[id].position=data[id]
func recover_inventory(id:int) -> void:
 recovery_dirty.erase(id)
 var p=player(id)
 if p==null or not recovery.has(p.profile_id):return
 var bag=main.items.inventory_for(id);var remainder:Array=[];var changed:=false
 for stack in recovery[p.profile_id]:
  var left:int=bag.add(stack.item,stack.count)
  changed=changed or left!=stack.count
  if left>0:remainder.append({"item":stack.item,"count":left})
 if remainder.is_empty():recovery.erase(p.profile_id)
 else:recovery[p.profile_id]=remainder
 if changed:
  recovering=true;main.items.inventory_changed.emit(id);recovering=false
 var count:=0
 for stack in remainder:count+=int(stack.count)
 if p.recovery_count!=count:
  p.recovery_count=count;main.combat.player_changed.emit(id,main.combat.player_data(p))
func respawn_request(id:int) -> bool:
 if not main.combat.authoritative():return false
 var p=player(id)
 if p==null or not p.dead:return false
 cancel_helper(id);cancel_target(id)
 main.encounter.withdraw(p.profile_id)
 main.combat.respawn(p)
 if main.combat_zone.active and main.combat_zone.contains_body(p):
  p.position=main.world.safe_spawn_position(maxi(2,main.combat_zone.bounds.position.x-4));p.life_revision+=1;main.combat.player_changed.emit(id,main.combat.player_data(p))
 if p==main.player:main.input_latched=true
 return true
func intent(id:int,target:int,held:bool) -> void:
 if not main.combat.authoritative():return
 if not held:intents.erase(id);cancel_helper(id);return
 var p=player(id);var t=player(target)
 if id==target or p==null or t==null or t.get_meta("attempt_paused",false) or p.dead or not t.dead:return
 intents[id]={"target":target,"until":Time.get_ticks_msec()+Rules.INTENT_TIMEOUT_MS}
func cancel_target(target:int) -> void:
 if not channels.has(target):return
 var helper=player(channels[target].helper)
 if helper!=null:
  if helper.fighter.mode=="help":helper.fighter.reset()
  helper.help_progress=0;main.combat.player_changed.emit(int(str(helper.name)),main.combat.player_data(helper))
 var body=player(target)
 if body!=null:body.help_progress=0;main.combat.player_changed.emit(target,main.combat.player_data(body))
 channels.erase(target)
func cancel_helper(id:int) -> void:
 for target in channels.keys():
  if channels[target].helper==id:cancel_target(target)
func help_valid(id:int,target:int) -> bool:
 var p=player(id);var t=player(target)
 if p==null or t==null or p.dead or not t.dead or p.move_command!=0 or p.jump_command:return false
 if p.fighter.mode not in ["idle","help"]:return false
 if p.position.distance_to(t.position)>Rules.HELP_RADIUS:return false
 if main.items.inventory_for(id).count_item(Rules.HELP_ITEM)<1:return false
 return main.combat.line_clear(p.position+Vector2(0,-5),t.position+Vector2(0,-5))
func tick_help(delta:float) -> void:
 for target in channels.keys():
  var id:int=channels[target].helper
  if not intents.has(id) or intents[id].target!=target or intents[id].until<Time.get_ticks_msec() or not help_valid(id,target):cancel_target(target)
 for id in intents.keys():
  if intents[id].until<Time.get_ticks_msec():intents.erase(id);continue
  var target:int=intents[id].target
  if channels.has(target) or not help_valid(id,target):continue
  var p=player(id);var t=player(target);p.facing=1 if t.position.x>=p.position.x else -1;main.items.cancel_medicine(p);p.fighter.begin("help",Vector2(p.facing,0),1e8)
  channels[target]={"helper":id,"elapsed":0.0}
 for target in channels.keys():
  var channel:Dictionary=channels[target];var p=player(channel.helper);var t=player(target)
  channel.elapsed+=delta;p.help_progress=minf(1,channel.elapsed/Rules.HELP_SECONDS);t.help_progress=p.help_progress
  if channel.elapsed+0.000001>=Rules.HELP_SECONDS:
   if main.items.inventory_for(channel.helper).remove_item(Rules.HELP_ITEM,1):
    main.items.inventory_changed.emit(channel.helper)
    t.dead=false;t.health=maxi(1,ceili(t.resources.max_health*Rules.REVIVE_HEALTH));t.revive_immunity=Rules.REVIVE_IMMUNITY;t.hurt_immunity=0;t.life_revision+=1;t.fighter.reset();t.velocity=Vector2.ZERO
    main.combat.player_changed.emit(target,main.combat.player_data(t))
   cancel_target(target)
  elif p.resource_sync<=0:
   p.resource_sync=.1;main.combat.player_changed.emit(channel.helper,main.combat.player_data(p));main.combat.player_changed.emit(target,main.combat.player_data(t))
func tick_coins(delta:float) -> void:
 for id in coins.keys():
  var c=coins[id];c.age+=delta;c.velocity.y=minf(500,c.velocity.y+850*delta);c.move_and_slide()
  if c.position.y>main.world.world_depth*16+32 or c.position.x<0 or c.position.x>main.world.world_width*16:c.position=safe_position(c.position);c.velocity=Vector2.ZERO
  if c.age<Rules.PICKUP_DELAY:continue
  var recipient:Node2D=null
  for p in main.get_node("Players").get_children():
   if int(str(p.name))>0 and not p.dead and p.money<Rules.MAX_MONEY and p.position.distance_to(c.position)<Rules.PICKUP_RADIUS and main.combat.line_clear(p.position+Vector2(0,-5),c.position):recipient=p;break
  if recipient==null:
   for mob in main.combat.entities.values():
    if mob.kind!="spirit" and mob.money<Rules.MAX_MONEY and mob.position.distance_to(c.position)<Rules.PICKUP_RADIUS and main.combat.line_clear(mob.position+Vector2(0,-5),c.position):recipient=mob;break
  if recipient==null:continue
  var amount:=mini(c.amount,Rules.MAX_MONEY-int(recipient.money));recipient.money+=amount;c.amount-=amount
  if recipient is CharacterBody2D and recipient.get_script()==preload("res://scripts/enemy.gd"):
   main.combat.entity_changed.emit(recipient.entity_id,main.combat.entity_data(recipient.entity_id))
  else:main.combat.player_changed.emit(int(str(recipient.name)),main.combat.player_data(recipient))
  if c.amount==0:set_coin(id,{});coin_changed.emit(id,{})
  else:coin_changed.emit(id,coin_data(id))
func _physics_process(delta:float) -> void:
 if not is_instance_valid(main.network) or not main.combat.authoritative():return
 tick_help(delta);tick_coins(delta)
 for id in recovery_dirty.keys():recover_inventory(id)
 for p in main.get_node("Players").get_children():
  if not p.dead and main.combat_zone.active and not main.encounter.can_damage(p.profile_id) and main.combat_zone.contains_body(p):
   p.position=main.world.safe_spawn_position(maxi(2,main.combat_zone.bounds.position.x-4));p.velocity=Vector2.ZERO;p.life_revision+=1;main.combat.player_changed.emit(int(str(p.name)),main.combat.player_data(p))
func nearest_downed() -> int:
 if not is_instance_valid(main.player) or main.player.dead:return 0
 var nearest:=0;var distance:=Rules.HELP_RADIUS
 for p in main.get_node("Players").get_children():
  var d:float=p.position.distance_to(main.player.position)
  if p!=main.player and p.dead and d<distance and main.combat.line_clear(main.player.position+Vector2(0,-5),p.position+Vector2(0,-5)):nearest=int(str(p.name));distance=d
 return nearest
func _input(event:InputEvent) -> void:
 if not event is InputEventKey or event.physical_keycode!=KEY_E:return
 if not event.pressed:
  if input_target!=0:main.network.help_local(input_target,false);input_target=0
  return
 if event.echo or main.ui_blocked() or main.inventory_ui.opened:return
 var target:=nearest_downed()
 if target!=0:
  input_target=target;main.network.help_local(target,true);get_viewport().set_input_as_handled()
func _process(delta:float) -> void:
 if not is_instance_valid(main.player) or not is_instance_valid(main.inventory_ui):return
 var p=main.player
 if input_target!=0:
  if not Input.is_physical_key_pressed(KEY_E) or main.pause_open or main.inventory_ui.opened or p.dead:
   main.network.help_local(input_target,false);input_target=0
  else:
   intent_clock-=delta
   if intent_clock<=0:intent_clock=.1;main.network.help_local(input_target,true)
 down_panel.visible=p.dead and not main.pause_open
 wallet.text="Монеты: %d"%p.money
 if p.recovery_count>0:wallet.text+="\nВозврат старых вещей: %d"%p.recovery_count
 var target:=nearest_downed()
 prompt.visible=target!=0 and not main.pause_open and not main.inventory_ui.opened and not main.npcs.opened
 if prompt.visible:
  var has_item:bool=main.items.local_inventory().count_item(Rules.HELP_ITEM)>0
  prompt.text="E держать 4 с — помочь (Искровая перевязь)" if has_item else "Для помощи нужна Искровая перевязь"
  if p.help_progress>0:prompt.text="Поднятие: %d%%"%roundi(p.help_progress*100)
 message.text="Вы упали. Вещи сохранены.\nМожно ждать помощи без ограничения времени."
 if p.dead and p.help_progress>0:message.text="Товарищ помогает: %d%%\nПеревязь расходуется только после поднятия."%roundi(p.help_progress*100)
 if p.dead:
  var camera:Camera2D=p.get_node("Camera2D");var other=player(watching)
  camera.position=other.position-p.position+Vector2(0,-35) if other!=null else Vector2(0,-35)
 else:
  p.get_node("Camera2D").position=Vector2(0,-35);watching=0
func _build_ui() -> void:
 layer=CanvasLayer.new();layer.layer=6;add_child(layer)
 wallet=Label.new();wallet.theme=preload("res://scripts/visuals/art_direction.gd").theme();wallet.position=Vector2(230,14);wallet.add_theme_font_size_override("font_size",12);wallet.add_theme_color_override("font_outline_color",Color("18252e"));wallet.add_theme_constant_override("outline_size",2);wallet.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(wallet)
 prompt=Label.new();prompt.position=Vector2(180,440);prompt.add_theme_font_size_override("font_size",14);prompt.add_theme_color_override("font_outline_color",Color("18252e"));prompt.add_theme_constant_override("outline_size",2);prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(prompt)
 down_panel=PanelContainer.new();down_panel.theme=preload("res://scripts/visuals/art_direction.gd").theme();down_panel.position=Vector2(264,150);down_panel.custom_minimum_size=Vector2(440,0);layer.add_child(down_panel);down_panel.hide()
 var box:=VBoxContainer.new();down_panel.add_child(box)
 message=Label.new();message.add_theme_font_size_override("font_size",13);box.add_child(message)
 observe=Button.new();observe.text="Наблюдать за товарищем";observe.pressed.connect(cycle_watch);box.add_child(observe)
 var button:=Button.new();button.text="Возродиться у старта";button.pressed.connect(func():main.input_latched=true;main.network.respawn_local());box.add_child(button)
func cycle_watch() -> void:
 var ids:Array=[]
 for p in main.get_node("Players").get_children():
  if p!=main.player:ids.append(int(str(p.name)))
 if ids.is_empty():watching=0;observe.text="Других игроков нет";return
 watching=ids[(ids.find(watching)+1)%ids.size()];observe.text="Наблюдение: отключившийся товарищ" if watching<0 else "Наблюдение: игрок %d"%watching
