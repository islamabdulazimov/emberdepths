extends RefCounted
const Gear=preload("res://data/equipment.gd")
const Inventory=preload("res://scripts/inventory.gd")

static func required(state:Dictionary) -> bool:
 if int(state.get("combat_rules",1))<3 or not state.combat.chests.is_empty():return true
 for entity in state.combat.entities.values():
  if entity.kind=="spirit":return true
 return false

static func upgrade(original:Dictionary) -> Dictionary:
 # Pure copy: never mutate a loaded envelope or the live world before validation.
 var state:Dictionary=original.duplicate(true)
 var economy:Dictionary=state.combat.get("economy",{"coins":{},"next_id":1,"recovery":{}})
 var recovery:Dictionary=economy.get("recovery",{})
 for id in state.combat.chests:
  var chest:Dictionary=state.combat.chests[id]
  var profile:String=chest.profile
  if not recovery.has(profile):recovery[profile]=[]
  for stack in chest.contents:
   if stack.count>0:recovery[profile].append(stack.duplicate())
  for slot in Gear.SLOTS:
   var item:String=chest.get("equipment",{}).get(slot,"")
   if item=="":continue
   if state.profiles.has(profile):
    var worn:Dictionary=Gear.clean(state.profiles[profile].life.get("equipment",{}))
    if worn[slot]=="":worn[slot]=item;state.profiles[profile].life.equipment=worn;continue
   recovery[profile].append({"item":item,"count":1})
 state.combat.chests={}
 for id in state.combat.entities.keys():
  if state.combat.entities[id].kind=="spirit":state.combat.entities.erase(id)
 for profile in state.profiles:
  var record:Dictionary=state.profiles[profile]
  if int(state.get("combat_rules",1))<3:record.life.unclothed=false
  record.life.respawn=0.0;record.life.last_chest=Vector2(-1,-1)
  record.life.equipment=Gear.clean(record.life.get("equipment",{}))
  if not recovery.has(profile):continue
  var bag=Inventory.new();bag.load_data(record.inventory)
  var remainder:Array=[]
  for stack in recovery[profile]:
   var left:int=bag.add(stack.item,stack.count)
   if left>0:remainder.append({"item":stack.item,"count":left})
  record.inventory=bag.to_data()
  if remainder.is_empty():recovery.erase(profile)
  else:recovery[profile]=remainder
 economy.recovery=recovery;state.combat.economy=economy
 state.combat_rules=3
 return state
