extends SceneTree
const Gear=preload("res://data/equipment.gd")
const Migration=preload("res://scripts/death_migration.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Codec=preload("res://scripts/save_codec.gd")
const Schema=preload("res://scripts/save_schema.gd")
var failures:=0
var checks:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func full_bag() -> Array:
 var bag=Inventory.new()
 for i in range(30):bag.slots[i]={"item":"dirt","count":99}
 return bag.to_data()
func contents(item:String,count:int) -> Array:
 var bag=Inventory.new();bag.add(item,count);return bag.to_data()
func census(state:Dictionary,item:String) -> int:
 var count:=0
 for r in state.profiles.values():
  for stack in r.inventory:
   if stack.item==item:count+=int(stack.count)
  for worn in r.life.get("equipment",{}).values():
   if worn==item:count+=1
 for chest in state.combat.chests.values():
  for stack in chest.contents:
   if stack.item==item:count+=int(stack.count)
  for worn in chest.get("equipment",{}).values():
   if worn==item:count+=1
 for queue in state.combat.get("economy",{}).get("recovery",{}).values():
  for stack in queue:
   if stack.item==item:count+=int(stack.count)
 return count
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.items.set_physics_process(false);main.survival.set_physics_process(false);main.player.set_physics_process(false);main.exploration.set_process(false);main.encounter.enabled=false
 var state:Dictionary=main.saves.capture();state.combat_rules=2
 var host:String=state.host_profile;var offline:="b".repeat(32);var orphan:="c".repeat(32);var key:="d".repeat(64)
 state.profiles[host].inventory=full_bag();state.profiles[host].life.equipment=Gear.empty();state.profiles[host].life.dead=true;state.profiles[host].life.health=0;state.profiles[host].life.unclothed=true;state.profiles[host].life.respawn=1.2
 state.profiles[offline]=state.profiles[host].duplicate(true);state.profiles[offline].life.profile=offline;state.profiles[offline].key_hash=key.sha256_text();state.profiles[offline].inventory[0]={"item":"wood","count":98}
 state.combat.chests={
  1:{"profile":host,"owner":1,"position":main.player.position,"contents":contents("wood",5),"equipment":{"head":"wood_helm","ability":"traveler_knot"}},
  2:{"profile":host,"owner":1,"position":main.player.position,"contents":contents("stone_blade",1),"equipment":{"head":"wood_helm"}},
  3:{"profile":offline,"owner":22,"position":main.player.position,"contents":contents("wood",5),"equipment":{"body":"wood_armor"}},
  4:{"profile":orphan,"owner":33,"position":main.player.position,"contents":contents("wood",7),"equipment":{"shield":"wood_shield"}}}
 state.combat.next_chest=5
 var ghost:int=main.combat.spawn_entity("spirit",main.player.position,main.player.position)
 state.combat.entities[ghost]=main.combat.entity_data(ghost);state.combat.next_entity=ghost+1
 check(Schema.validate(state)=="","legacy full bags offline owner orphan and old spirit validate")
 var bytes_before:=JSON.stringify(Codec.new().encode(state))
 var upgraded:Dictionary=Migration.upgrade(state)
 check(JSON.stringify(Codec.new().encode(state))==bytes_before,"migration never mutates original state")
 check(Schema.validate(upgraded)=="" and upgraded.combat_rules==3,"upgraded state passes current schema")
 for item in ["dirt","wood","wood_helm","wood_armor","wood_shield","stone_blade","traveler_knot"]:
  check(census(state,item)==census(upgraded,item),"migration conserves every "+item)
 check(upgraded.profiles[host].life.equipment.head=="wood_helm" and upgraded.profiles[host].life.equipment.ability=="traveler_knot","first matching old gear fills empty worn slots")
 check(upgraded.combat.economy.recovery[host].size()==3,"full inventory keeps all overflow in owner queue")
 check(upgraded.profiles[offline].inventory[0].count==99 and upgraded.combat.economy.recovery[offline][0].count==4,"offline owner merges partial stack and preserves remainder")
 check(upgraded.combat.economy.recovery.has(orphan),"unknown disconnected owner is preserved in escrow")
 check(upgraded.combat.chests.is_empty() and upgraded.combat.entities.is_empty(),"obsolete chest and spirit removed only after recovery recorded")
 check(upgraded.profiles[host].life.dead and not upgraded.profiles[host].life.unclothed and upgraded.profiles[host].life.respawn==0,"legacy death becomes downed with clothing and no timer")
 check(JSON.stringify(Codec.new().encode(Migration.upgrade(upgraded)))==JSON.stringify(Codec.new().encode(upgraded)),"repeated migration is idempotent")
 # Real legacy envelope plus a pre-existing original from the previous update.
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(main.saves.save_path.get_base_dir()))
 var envelope:=JSON.stringify({"version":1,"payload":bytes_before,"sha256":bytes_before.sha256_text()})
 var file:=FileAccess.open(main.saves.save_path,FileAccess.WRITE);file.store_string(envelope);file.close()
 file=FileAccess.open(main.saves.save_path+".pre-adventure.original",FileAccess.WRITE);file.store_string("previous-original-unchanged");file.close()
 check(main.saves.load_now(),"load upgrades old file through normal save service")
 check(FileAccess.get_file_as_string(main.saves.save_path+".pre-death-v3.original")==envelope,"new death migration keeps byte-identical original")
 check(FileAccess.get_file_as_string(main.saves.save_path+".pre-adventure.original")=="previous-original-unchanged","older immutable backup is never overwritten")
 main.player.set_physics_process(false)
 var bag=main.items.local_inventory();bag.slots[0]={"item":"","count":0}
 main.items.inventory_changed.emit(1);main.survival._physics_process(0)
 check(bag.count_item("wood")==5 and main.survival.recovery.has(host),"freeing one slot delivers only what fits")
 var checkpoint:Dictionary=main.saves.capture()
 check(main.saves.restore(checkpoint)=="","partially recovered queue reloads")
 main.player.set_physics_process(false);bag=main.items.local_inventory()
 main.survival.recover_inventory(1)
 check(bag.count_item("wood")==5,"reload never reissues already returned wood")
 bag.slots[1]={"item":"","count":0};bag.slots[2]={"item":"","count":0}
 main.survival.recover_inventory(1);main.survival.recover_inventory(1)
 check(not main.survival.recovery.has(host) and bag.count_item("wood_helm")==1 and bag.count_item("stone_blade")==1,"remaining old items return exactly once")
 check(main.player.equipment.head=="wood_helm" and main.player.equipment.ability=="traveler_knot","recovery does not duplicate worn gear")
 main.add_player(2,main.world.safe_spawn_position());main.get_node("Players/2").set_physics_process(false)
 check(main.saves.authorize(orphan,"e".repeat(64))=="","unregistered old owner can authenticate normally")
 main.saves.attach_peer(2,orphan,"e".repeat(64));main.survival._physics_process(0);main.survival._physics_process(0)
 check(main.items.inventory_for(2).count_item("wood")==7 and main.items.inventory_for(2).count_item("wood_shield")==1 and not main.survival.recovery.has(orphan),"orphan escrow is claimed only by matching stable profile")
 main.add_player(3,main.world.safe_spawn_position());main.get_node("Players/3").set_physics_process(false)
 main.saves.attach_peer(3,offline,key)
 var offline_bag=main.items.inventory_for(3);offline_bag.slots[1]={"item":"","count":0};main.survival.recover_inventory(3)
 check(offline_bag.count_item("wood")==103 and main.get_node("Players/3").equipment.body=="wood_armor","offline owner later receives exact money-independent items")
 check(main.survival.recovery.is_empty(),"all recovery queues clear after successful delivery")
 var public:Dictionary=main.combat.snapshot(true)
 check(not public.economy.has("recovery"),"private recovery queue is omitted from network bootstrap")
 check(main.saves.save_now() and main.saves.load_now(),"migrated state saves and loads through disk")
 check(main.items.local_inventory().count_item("wood")==5 and main.player.equipment.head=="wood_helm","disk reload never reconstructs migrated chest loot")
 main.queue_free();await process_frame;print("DEATH_MIGRATION_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
