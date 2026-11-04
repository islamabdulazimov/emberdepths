extends SceneTree
var failures := 0
var events: Array = []
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")

func run() -> void:
 var role := OS.get_cmdline_user_args()[0]
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.spawning_enabled = false
 main.player.set_physics_process(false)
 var anchor := Vector2i(98,21)
 var wall := Vector2i(97,21)
 var builder_id := [0]
 if role == "host":
  for x in range(94,104):
   for y in range(17,22): main.world.apply_edit(Vector2i(x,y),-1)
   main.world.apply_edit(Vector2i(x,22),0)
  main.world.solid.update_internals()
  main.player.position = Vector2(1528,342)
  main.network.peer_admitted.connect(func(id):
   var body = main.get_node("Players").get_node(str(id))
   body.set_physics_process(false)
   if builder_id[0] == 0:
    builder_id[0] = id
    body.position = Vector2(1544,342)
    main.items.inventory_for(id).add("wood",4)
   else: body.position = Vector2(1512,342))
  main.items.door_changed.connect(func(_anchor,value):
   events.append(value)
   if value == 1: print("DOOR_OPEN"))
  check_result(main.network.host_game() == OK,"Shelter host starts")
 else: main.network.join_game("127.0.0.1")
 var start := Time.get_ticks_msec()
 var crafted_wall := false
 var crafted_door := false
 var checked_guard := false
 var invalid_tick := 0
 var opened_once := false
 var saw_open := false
 var saw_closed := false
 var saw_removed := false
 var held_until := 0
 var inside_until := 0
 var moved_inside := false
 var saw_inside := false
 var blocked_tick := 0
 var checked_blocked := false
 var outside_tick := 0
 var close_sent := false
 var late_checked := false
 while Time.get_ticks_msec()-start < (8500 if role == "host" else (6500 if role == "builder" else 5500)):
  await process_frame
  if not main.network.active or not main.network.connected: continue
  var door = main.world.door_at(anchor)
  if door != null and door.opened: saw_open = true
  if saw_open and door != null and not door.opened: saw_closed = true
  if saw_closed and door == null: saw_removed = true
  if role == "host":
   if door != null and door.opened and not moved_inside:
    moved_inside = true
    main.get_node("Players").get_node(str(builder_id[0])).position = Vector2(1576,342)
    inside_until = Time.get_ticks_msec()+1200
   if moved_inside and inside_until > 0 and Time.get_ticks_msec() >= inside_until:
    inside_until = 0
    main.get_node("Players").get_node(str(builder_id[0])).position = Vector2(1544,342)
  elif role == "builder":
   var bag = main.items.local_inventory()
   if not crafted_wall:
    main.network.craft_local("wood_wall")
    crafted_wall = true
   if bag.count_item("wood_wall") > 0 and not crafted_door:
    main.network.craft_local("wood_door")
    crafted_door = true
   if main.world.wall_at(wall) != 3:
    main.network.submit_local(0,false,wall,2,1,1.0/60.0)
   elif door == null and not saw_closed:
    main.network.submit_local(0,false,anchor,2,0,1.0/60.0)
   elif door != null and not opened_once:
    main.network.submit_local(0,false,anchor,0,9,1.0/60.0)
    if not checked_guard:
     checked_guard = true
     check_result(not main.items.toggle_door(main.player,anchor,9) and not main.items.remove_door(main.player,anchor,9),"Client cannot operate or remove doors locally")
     main.network.toggle_door_local(anchor,1)
     invalid_tick = Time.get_ticks_msec()
    elif Time.get_ticks_msec()-invalid_tick > 300:
     check_result(not door.opened,"Host rejects interaction with a nonempty selected slot")
     main.network.toggle_door_local(anchor,9)
     opened_once = true
   elif door != null and door.opened:
    main.network.submit_local(0,false,anchor,2,9,1.0/60.0)
    if absf(main.player.position.x-1576) < 1:
     saw_inside = true
     if blocked_tick == 0:
      main.network.toggle_door_local(anchor,9)
      blocked_tick = Time.get_ticks_msec()
     elif not checked_blocked and Time.get_ticks_msec()-blocked_tick > 300:
      checked_blocked = true
      check_result(door.opened,"Host rejects closing through a remote player")
    elif saw_inside and not close_sent:
     if outside_tick == 0: outside_tick = Time.get_ticks_msec()
     if Time.get_ticks_msec()-outside_tick > 450:
      check_result(door.opened,"Held right-button command never repeatedly toggles the door")
      close_sent = true
      main.network.toggle_door_local(anchor,9)
   elif door != null and saw_closed:
    main.network.submit_local(0,false,anchor,1,9,1.0/60.0)
   else: main.network.submit_local(0,false,anchor,0,9,1.0/60.0)
  elif not late_checked:
   late_checked = true
   check_result(door != null and door.opened and main.world.wall_at(wall) == 3,"Late bootstrap restores the open door and wood background")
 var returned := 0
 for drop in main.items.drops.values():
  if drop.item_id == "wood_door": returned += drop.count
 check_result(saw_open and saw_closed and saw_removed,"Open close and removal synchronize on "+role)
 check_result(main.world.wall_at(wall) == 3,"Wood wall remains independent of door state on "+role)
 check_result(returned == 1,"Removal returns a single shared door item on "+role)
 if role == "host":
  check_result(events == [0,1,0,-1],"Only validated door transitions are broadcast")
  check_result(main.items.local_inventory().count_item("wood_wall") == 0,"Builder recipe never alters host inventory")
 if role == "builder":
  check_result(checked_blocked and close_sent,"Remote occupied-opening and release scenario completes")
  check_result(main.items.local_inventory().count_item("wood_wall") == 3 and main.items.local_inventory().count_item("wood_door") == 0,"Host crafting and placement consume exact personal items")
  main.network.stop()
  await create_timer(0.4).timeout
  check_result(main.world.doors.is_empty() and main.world.wall_at(wall) == -1 and main.items.local_inventory().count_item("wood_wall") == 0,"Leaving restores own world without importing shelter items")
 print("Shelter network ",role," failures: ",failures)
 quit(1 if failures else 0)
