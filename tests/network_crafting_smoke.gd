extends SceneTree
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok:
  print("PASS: ", message)
 else:
  failures += 1
  push_error(message)

func _initialize() -> void:
 call_deferred("run")

func slot_for(inventory: RefCounted, item_id: String) -> int:
 for i in range(10):
  if inventory.item_at(i) == item_id:
   return i
 return 0

func run() -> void:
 var role := OS.get_cmdline_user_args()[0]
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 var fixture_given := false
 if role == "host":
  main.multiplayer.peer_connected.connect(func(id):
   if not fixture_given:
    fixture_given = true
    var inventory = main.items.inventory_for(id)
    inventory.add("stone", 16)
    inventory.add("dirt", 8)
    inventory.add("emberstone", 2)
    main.items.inventory_changed.emit(id))
  check_result(main.network.host_game() == OK, "Crafting host opens ENet server")
 else:
  main.network.join_game("127.0.0.1")
 var cell := Vector2i(98, 21)
 var started := Time.get_ticks_msec()
 var phase := 0
 var phase_time := 0
 var saw_wall := false
 var saw_torch := false
 var saw_swing := false
 var saw_removed := false
 var late_checked := false
 var before_invalid: Array = []
 while Time.get_ticks_msec() - started < (8000 if role == "host" else (7000 if role == "builder" else 5000)):
  await process_frame
  if not main.network.active or not main.network.connected:
   continue
  var inventory = main.items.local_inventory()
  if main.world.wall_at(cell) == 1:
   saw_wall = true
  if main.world.torches.has(cell):
   saw_torch = true
  if saw_wall and saw_torch and main.world.wall_at(cell) == -1 and not main.world.torches.has(cell):
   saw_removed = true
  for body in main.get_node("Players").get_children():
   if str(body.name) != "1" and body.swing_remaining > 0:
    saw_swing = true
  if role == "late" and not late_checked:
   late_checked = true
   check_result(main.world.wall_at(cell) == 1 and main.world.torches.has(cell), "Late snapshot restores built wall and torch")
   check_result(main.world.torches[cell].light.enabled, "Late client creates torch light")
   check_result(inventory.count_item("stone_pick") == 0 and inventory.count_item("stone_blade") == 0, "Crafted equipment remains private to builder")
  if role != "builder":
   continue
  var mode := 0
  var slot := 0
  var target := cell
  match phase:
   0:
    if inventory.count_item("stone") == 16:
     for recipe in ["stone_pick", "stone_blade", "torch", "dirt_wall"]:
      main.network.craft_local(recipe)
     phase = 1
   1:
    if inventory.count_item("torch") == 3 and inventory.count_item("dirt_wall") == 4:
     check_result(inventory.count_item("stone_pick") == 1 and inventory.count_item("stone_blade") == 1, "Host crafts both equipment items for client")
     check_result(inventory.count_item("stone") == 5 and inventory.count_item("dirt") == 3 and inventory.count_item("emberstone") == 1, "Network crafting consumes exact recipe ingredients")
     before_invalid = inventory.to_data()
     main.network.craft_local("forged_recipe")
     phase = 2
   2:
    if main.inventory_ui.feedback.text == "Неизвестный рецепт":
     check_result(inventory.to_data() == before_invalid, "Forged recipe rejected without inventory mutation")
     phase = 3
     phase_time = Time.get_ticks_msec()
   3:
    mode = 2
    slot = slot_for(inventory, "torch")
    target = Vector2i(0, 0)
    if Time.get_ticks_msec() - phase_time > 350:
     check_result(inventory.count_item("torch") == 3 and not main.world.torches.has(target), "Host rejects distant decoration without consuming item")
     phase = 4
   4:
    mode = 2
    slot = slot_for(inventory, "dirt_wall")
    if saw_wall:
     phase = 5
   5:
    mode = 2
    slot = slot_for(inventory, "torch")
    if saw_torch and inventory.count_item("torch") == 2 and inventory.count_item("dirt_wall") == 3:
     check_result(true, "Wall and torch consume one item each on host")
     phase = 6
   6:
    mode = 1
    slot = slot_for(inventory, "stone_blade")
    if main.get_node("Players").get_child_count() == 3 and Time.get_ticks_msec() - started > 4500:
     phase = 7
   7:
    mode = 1
    slot = slot_for(inventory, "torch")
    if not main.world.torches.has(cell):
     phase = 8
   8:
    mode = 1
    slot = slot_for(inventory, "dirt_wall")
    if main.world.wall_at(cell) == -1:
     phase = 9
  main.network.submit_local(0.0, false, target, mode, slot, 1.0 / 60.0)
 check_result(saw_wall and saw_torch, "Built wall and torch replicate to " + role)
 check_result(saw_swing, "Weapon swing replicates to " + role)
 check_result(saw_removed, "Decoration removal replicates to " + role)
 if role == "builder":
  check_result(phase == 9, "Builder completes crafting and placement cycle")
 if role == "late":
  check_result(late_checked, "Late client completed bootstrap")
 print("NETWORK CRAFT ", role, " failures: ", failures)
 quit(1 if failures else 0)
