extends SceneTree
const Schema = preload("res://scripts/save_schema.gd")
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func physics_ready() -> void:
 await physics_frame
 await physics_frame

func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.set_physics_process(false)
 main.combat.spawning_enabled = false
 main.encounter.enabled = false
 main.items.set_physics_process(false)
 main.player.set_physics_process(false)
 var world = main.world
 var player = main.player
 var service = main.items
 var bag = service.local_inventory()
 var anchor := Vector2i(98,21)
 for x in range(94,104):
  for y in range(17,22): world.apply_edit(Vector2i(x,y),-1)
  world.apply_edit(Vector2i(x,22),0)
 world.solid.update_internals()
 player.position = Vector2(1544,342)
 await physics_ready()
 bag.add("wood",4)
 check_result(service.craft(1,"wood_wall").begins_with("Создано") and bag.count_item("wood_wall") == 4,"One wood crafts four background walls")
 check_result(service.craft(1,"wood_door").begins_with("Создано") and bag.item_at(0) == "wood_door" and bag.count_item("wood") == 0,"Three wood crafts one door without a workbench")
 var wall := Vector2i(96,21)
 check_result(service.place_selected(player,wall,1) and world.wall_at(wall) == 3 and world.walls.get_cell_source_id(wall) == 2 and world.block_at(wall) == -1,"Wood walls use their own stable background ID and source")
 check_result(not world.walls.collision_enabled,"Background wood never blocks player movement")
 check_result(service.use_primary(player,wall,1) and service.drops.values()[0].item_id == "wood_wall","Removing a wood wall returns wood wall rather than stone")
 for id in service.drops.keys(): service.set_drop(id,{})
 service.place_selected(player,wall,1)
 bag.add("torch",1)
 check_result(service.place_selected(player,wall,2) and world.torches.has(wall),"Wood background supports an existing torch")
 bag.add("wood_door",1)
 player.position.x = world.cell_center(anchor).x
 check_result(not service.place_selected(player,anchor,0) and bag.count_item("wood_door") == 2,"Door cannot be placed inside the player")
 player.position.x = 1544
 var mob: int = main.combat.spawn_entity("ashling",Vector2(1576,352))
 check_result(not service.place_selected(player,anchor,0),"Door cannot be placed inside an ordinary enemy")
 main.combat.set_entity(mob,{})
 check_result(not service.place_selected(player,Vector2i(110,21),0),"Distant door placement is rejected")
 var floor := anchor+Vector2i.DOWN
 world.apply_edit(floor,-1)
 check_result(not service.place_selected(player,anchor,0),"Door requires a solid floor")
 world.apply_edit(floor,0)
 check_result(service.place_selected(player,anchor,0) and bag.count_item("wood_door") == 1,"One placed door consumes exactly one item")
 var door = world.door_at(anchor)
 check_result(door != null and world.door_at(anchor+Vector2i.UP) == door and world.door_at(anchor+Vector2i.UP*2) == door and world.door_at(anchor+Vector2i.UP*3) == null,"All three footprint cells resolve to one door")
 check_result(not service.place_selected(player,anchor,0) and bag.count_item("wood_door") == 1,"Overlapping door placement costs nothing")
 await physics_ready()
 var blocker := Vector2i(97,21)
 world.apply_edit(blocker,2)
 world.solid.update_internals()
 await physics_ready()
 check_result(not service.toggle_door(player,anchor,9),"Intervening terrain blocks interaction with a closed door")
 world.apply_edit(blocker,-1)
 world.solid.update_internals()
 await physics_ready()
 player.submit_command(1,false)
 player.set_physics_process(true)
 for i in range(50): await physics_frame
 player.set_physics_process(false)
 check_result(player.position.x < 1568 and player.is_on_floor(),"Closed door physically stops a walking player")
 player.position = Vector2(1608,342)
 mob = main.combat.spawn_entity("ashling",Vector2(1544,352))
 main.combat.set_physics_process(true)
 for i in range(120): await physics_frame
 main.combat.set_physics_process(false)
 check_result(main.combat.entities[mob].position.x < 1568 and player.health == 100,"Closed door stops an ordinary enemy from reaching the player")
 main.combat.set_entity(mob,{})
 player.position = Vector2(1544,342)
 player.velocity = Vector2.ZERO
 player.dead = true
 check_result(not service.toggle_door(player,anchor,9),"Dead players cannot operate doors")
 player.dead = false
 check_result(not service.toggle_door(player,anchor,0),"Door interaction requires an empty selected slot")
 check_result(service.toggle_door(player,anchor,9) and door.opened,"Empty-slot interaction opens the door from any part")
 check_result(not service.toggle_door(player,anchor,9) and door.opened,"Immediate repeat is debounced on the host")
 await physics_ready()
 player.submit_command(1,false)
 player.set_physics_process(true)
 for i in range(50): await physics_frame
 player.set_physics_process(false)
 check_result(player.position.x > 1590,"Opened door permits actual passage")
 player.position = Vector2(1576,342)
 door.ready_at = 0
 check_result(not service.toggle_door(player,anchor,9) and door.opened,"Door never closes through a player in its opening")
 player.position = Vector2(1544,342)
 player.velocity = Vector2.ZERO
 mob = main.combat.spawn_entity("ashling",Vector2(1576,352))
 check_result(not service.toggle_door(player,anchor,9),"Door never closes through an ordinary enemy")
 main.combat.set_entity(mob,{})
 var boss = load("res://scenes/andrew.tscn").instantiate()
 boss.definition = load("res://data/bosses.gd").ANDREW
 boss.state = load("res://scripts/boss_state.gd").new()
 boss.state.begin(boss.definition,1)
 boss.encounter = main.encounter
 main.encounter.state = boss.state
 main.encounter.actor = boss
 main.encounter.add_child(boss)
 boss.position = Vector2(1576,352)
 boss.set_physics_process(false)
 check_result(not service.toggle_door(player,anchor,9),"Door never closes through Andrew")
 main.encounter.end_fight("test_cleanup")
 main.combat.set_chest(999,{"owner":1,"profile":main.saves.profile_id,"position":world.cell_center(anchor),"contents":service.Inventory.new().to_data()})
 check_result(not service.toggle_door(player,anchor,9),"A death chest inside the passage prevents closing")
 main.combat.set_chest(999,{})
 check_result(service.toggle_door(player,anchor,9) and not door.opened,"Empty opening can be closed again")
 bag.add("wood_block",1)
 check_result(not service.place_selected(player,anchor,3),"Solid blocks cannot occupy a door footprint")
 bag.add("torch",1)
 check_result(not service.place_selected(player,anchor,2),"Torches cannot occupy a door footprint")
 check_result(service.place_selected(player,anchor,1) and world.wall_at(anchor) == 3,"Background wall can fill the space behind a door")
 door.ready_at = 0
 service.toggle_door(player,anchor,9)
 check_result(not service.place_selected(player,anchor,3),"An open doorway remains reserved against solid construction")
 main.saves.save_path = "user://tests/shelter.json"
 check_result(main.saves.save_now(),"Wood walls and open door state save to disk")
 var saved: Dictionary = main.saves.capture()
 world.apply_door(anchor,-1)
 world.apply_decoration("wall",wall,-1)
 check_result(main.saves.load_now() and world.door_at(anchor).opened and world.wall_at(wall) == 3,"Load restores open passage and correct wood wall type")
 player = main.player
 player.set_physics_process(false)
 player.position = Vector2(1544,342)
 var bad := saved.duplicate(true)
 bad.world.doors[anchor] = "open"
 check_result(main.saves.restore(bad) != "" and world.door_at(anchor).opened,"Invalid door state is rejected before mutating the world")
 bad = saved.duplicate(true)
 bad.world.doors[anchor+Vector2i.UP] = false
 check_result(Schema.validate(bad) != "","Overlapping saved door footprints are rejected")
 bad = saved.duplicate(true)
 bad.world.blocks[anchor] = 4
 check_result(Schema.validate(bad) != "","Door and solid block overlap is rejected by save schema")
 var legacy := saved.duplicate(true)
 legacy.world.erase("doors")
 check_result(main.saves.restore(legacy) == "" and world.doors.is_empty(),"Old saves without doors load normally")
 main.saves.restore(saved)
 player = main.player
 player.set_physics_process(false)
 player.position = Vector2(1544,342)
 check_result(service.use_primary(player,anchor,9) and world.doors.is_empty(),"Mining an open door removes the complete structure")
 check_result(service.drops.size() == 1 and service.drops.values()[0].item_id == "wood_door" and service.drops.values()[0].count == 1,"Door removal drops exactly one door item")
 check_result(not service.remove_door(player,anchor,9) and service.drops.size() == 1,"Repeated removal cannot duplicate the door")
 for id in service.drops.keys(): service.set_drop(id,{})
 world.apply_door(anchor,0)
 check_result(not world.character_fits(Vector2(1576,342)),"Safe restore detects a player inside a closed door")
 check_result(world.character_fits(world.safe_spawn_position(98)),"Respawn chooses space outside closed doors")
 check_result(service.use_primary(player,floor,9) and world.doors.is_empty(),"Removing supporting floor detaches the whole door")
 var door_drops := 0
 for drop in service.drops.values():
  if drop.item_id == "wood_door": door_drops += drop.count
 check_result(door_drops == 1,"Unsupported door returns one item without duplication")
 print("Shelter failures: ",failures)
 quit(1 if failures else 0)
