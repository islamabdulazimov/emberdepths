extends SceneTree
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var args := OS.get_cmdline_user_args()
 if not args.has("--with-save") or not args.has("--profile=expansion_restart"):
  push_error("This disk test requires its isolated expansion_restart profile")
  quit(1)
  return
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.combat.set_physics_process(false)
 main.interaction.set_process(false)
 main.items.set_physics_process(false)
 main.exploration.set_process(false)
 main.player.set_physics_process(false)
 main.encounter.enabled = false
 var opened := Vector2i(73,57)
 var removed := Vector2i(73,65)
 var mined := Vector2i(180,80)
 var built := Vector2i(180,79)
 if args[0] == "write":
  main.exploration.initialize_loot()
  main.player.position = Vector2(1144,918)
  main.player.velocity = Vector2.ZERO
  main.storage.chests[opened].inventory.load_data([])
  main.storage.chests[opened].known_empty = true
  main.storage.chests[opened].opened = true
  main.storage.destroy(removed)
  main.world.apply_edit(mined,-1)
  main.world.apply_edit(built,4)
  var id: int = main.combat.spawn_entity("seamling",Vector2(1224,1056))
  main.combat.entities[id].site_guard = true
  main.world.site_progress.root_shelter_38.guards = 1
  check_result(main.saves.save_now(),"Expanded world writes a complete atomic save")
  check_result(main.world.generator_version == 2 and main.storage.chests.size() == 9,"Writer uses generator2 and removes the actual loot container")
  check_result(not main.items.drops.is_empty(),"Destroying the generated chest spills real resources before saving")
 else:
  check_result(main.world.generator_version == 2 and main.world.world_width == 384 and main.world.world_depth == 160,"Fresh process loads saved generator2 without an expanded-world launch flag")
  check_result(main.player.position == Vector2(1144,918),"Fresh process restores the saved underground position")
  check_result(main.storage.chests.has(opened) and main.storage.chests[opened].opened and main.storage.empty(main.storage.chests[opened]),"Fresh process keeps the opened empty chest")
  check_result(not main.storage.chests.has(removed) and main.storage.chests.size() == 9,"Fresh process keeps the destroyed generated chest absent")
  check_result(main.world.block_at(mined) == -1 and main.world.block_at(built) == 4,"Fresh process retains mined and placed terrain")
  check_result(main.combat.entities.size() == 1 and main.combat.entities.values()[0].kind == "seamling" and main.combat.entities.values()[0].site_guard,"Fresh process restores a real original guard")
  check_result(not main.items.drops.is_empty(),"Fresh process retains spilled chest loot")
  var original := FileAccess.get_sha256(main.saves.save_path)
  main.exploration.initialize_loot()
  main.exploration.activate_guards()
  check_result(main.storage.chests.size() == 9 and main.storage.empty(main.storage.chests[opened]) and main.combat.entities.size() == 1,"Visiting restored ruins cannot duplicate loot, removed chests or the existing guard")
  check_result(FileAccess.get_sha256(main.saves.save_path) == original,"Read/visit checks leave the on-disk world bytes untouched")
 main.queue_free()
 await process_frame
 print("Expansion restart failures: ",failures)
 quit(1 if failures else 0)
