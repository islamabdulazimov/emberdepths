extends Node
signal committed(id:int)
const Gear=preload("res://data/equipment.gd")
const Items=preload("res://data/items.gd")
var main:Node2D
func _ready() -> void:main=get_parent()
func move(id:int,index:int,slot:String) -> bool:
 if not main.combat.authoritative() or slot not in Gear.SLOTS:return false
 var body=main.get_node("Players").get_node_or_null(str(id))
 if body==null or body.dead or body.fighter.mode not in ["idle","block"]:return false
 var bag=main.items.inventory_for(id)
 var previous:String=body.equipment[slot]
 if index==-1:
  if previous=="":return false
  var trial=preload("res://scripts/inventory.gd").new();trial.load_data(bag.to_data())
  if trial.add(previous,1)!=0:return false
  bag.load_data(trial.to_data());body.equipment[slot]=""
 else:
  if index<0 or index>=30:return false
  var item:String=bag.item_at(index)
  if Items.DEFINITIONS.get(item,{}).get("equip_slot","")!=slot:return false
  body.equipment[slot]=item
  bag.slots[index]={"item":previous,"count":0 if previous=="" else 1}
 if body.fighter.mode=="block":body.fighter.reset()
 committed.emit(id);main.items.inventory_changed.emit(id);main.combat.player_changed.emit(id,main.combat.player_data(body))
 return true
func block(id:int,held:bool) -> void:
 if not main.combat.authoritative():return
 var body=main.get_node("Players").get_node_or_null(str(id))
 if body==null:return
 if not held:
  if body.fighter.mode=="block":body.fighter.reset();main.combat.player_changed.emit(id,main.combat.player_data(body))
 elif not body.dead and body.fighter.mode=="idle" and body.equipment.shield!="" and body.resources.stamina>=1:
  main.items.cancel_medicine(body);body.work_remaining=0;body.swing_remaining=0;body.fighter.begin("block",Vector2(body.facing,0),1.0);main.combat.player_changed.emit(id,main.combat.player_data(body))

func into_bag(id:int,slot:String,index:int) -> bool:
 if not main.combat.authoritative() or slot not in Gear.SLOTS or index<0 or index>=30:return false
 var body=main.get_node("Players").get_node_or_null(str(id))
 if body==null or body.dead or body.fighter.mode not in ["idle","block"]:return false
 var bag=main.items.inventory_for(id)
 if bag.item_at(index)!="":return move(id,index,slot)
 var item:String=body.equipment[slot]
 if item=="":return false
 bag.slots[index]={"item":item,"count":1};body.equipment[slot]=""
 if body.fighter.mode=="block":body.fighter.reset()
 committed.emit(id);main.items.inventory_changed.emit(id);main.combat.player_changed.emit(id,main.combat.player_data(body));return true

func starter(id:int) -> void:
 # Called only in the one-time creation branch, never on load or respawn.
 var body=main.get_node("Players").get_node_or_null(str(id))
 if body==null:return
 body.equipment={"weapon":"","head":"wood_helm","body":"wood_armor","legs":"wood_legs","shield":"wood_shield"}
 main.items.inventory_for(id).add("wood_sword",1)
 committed.emit(id);main.items.inventory_changed.emit(id);main.combat.player_changed.emit(id,main.combat.player_data(body))
