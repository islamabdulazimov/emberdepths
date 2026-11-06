extends SceneTree
const Sizes=preload("res://data/world_sizes.gd")
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
 else:print("PASS ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 main.set_physics_process(false);main.combat.set_physics_process(false);main.encounter.enabled=false
 main.exploration.set_process(false);main.player.set_physics_process(false);main.items.set_physics_process(false)
 for size in ["small","large"]:
  for seed_value in [72419,12,90551,777,123456]:
   main.world.configure_new(size);main.world.world_seed=seed_value;main.world.generate();await process_frame;await physics_frame;main.world.solid.update_internals();main.npcs.sync()
   var cfg:Dictionary=Sizes.DEFINITIONS[size]
   var settlements:=0;var dungeons:=0;var separated:=true;var clear:=true;var footprint:=0
   for i in range(main.world.sites.size()):
    var site:Dictionary=main.world.sites[i];footprint+=site.rect.get_area()
    if site.kind=="settlement":settlements+=1
    else:
     dungeons+=1
     var y:int=site.rect.end.y-2
     for x in range(site.rect.position.x-5,site.rect.position.x+3):clear=clear and main.world.character_fits(Vector2(x*16+8,y*16-10))
    for j in range(i):separated=separated and Sizes.separated(site.rect,main.world.sites[j].rect)
   print("WORLD ",size," seed=",seed_value," settlements=",settlements," dungeons=",dungeons)
   check(settlements==cfg.settlements and dungeons<=cfg.dungeons and dungeons>0,"global budgets "+size+str(seed_value))
   check(separated and float(footprint)/(cfg.width*cfg.depth)<0.06,"edge spacing and natural majority")
   check(clear,"local dungeon entrance has full character clearance")
   check(main.world.npc_records.size()==2 and main.npcs.actors.size()==2,"one Julia and one Cameron")
   var supported:=true
   for id in main.world.npc_records:
    var at:Vector2=main.world.npc_records[id].position
    supported=supported and main.world.character_fits(at) and main.world.block_at(main.world.cell_at(at+Vector2(0,10.1)))>=0 and absf(at.x-main.world.spawn_position().x)>400
   check(supported,"residents grounded outside safe start")
   var plans:Array=main.world.sites.duplicate(true);var records:Dictionary=main.world.npc_records.duplicate(true)
   main.world.generate();await process_frame;await physics_frame;main.npcs.sync()
   check(main.world.sites==plans and main.world.npc_records==records and main.npcs.actors.size()==2,"seed reproducible without duplicate structures or residents")
   var saved:Dictionary=main.saves.capture()
   check(preload("res://scripts/save_schema.gd").validate(saved)=="","new dimensions and NPC save schema")
 var record:Dictionary=main.world.npc_records.julia
 main.player.position=record.position+Vector2(24,0);main.world.solid.update_internals();await physics_frame
 main.input_latched=false
 check(main.npcs.talk("julia") and main.npcs.speech.text==preload("res://data/residents.gd").DEFINITIONS.julia.lines[0],"Julia first local dialogue")
 check(main.ui_blocked() and not main.interaction.can_use_mouse(),"dialogue consumes attacks and mining")
 main.npcs.close_dialogue();check(main.input_latched,"closing dialogue latches mouse")
 check(main.npcs.talk("julia") and main.npcs.speech.text==preload("res://data/residents.gd").DEFINITIONS.julia.lines[1],"repeated dialogue advances line")
 main.npcs.close_dialogue();main.player.position=main.world.npc_records.cameron.position+Vector2(20,0)
 check(main.npcs.talk("cameron"),"Cameron has own dialogue")
 main.npcs.close_dialogue()
 var save:Dictionary=main.saves.capture();var before:Dictionary=main.world.npc_records.duplicate(true)
 check(main.saves.restore(save)=="" and main.world.npc_records==before,"NPC positions and IDs roundtrip")
 await process_frame;main.npcs.sync();await process_frame
 check(main.npcs.actors.size()==2,"restore and revisit never duplicate residents")
 main.queue_free();await process_frame
 print("NATURAL_WORLD_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
