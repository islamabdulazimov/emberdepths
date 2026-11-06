extends SceneTree
const Schema = preload("res://scripts/save_schema.gd")
const Codec = preload("res://scripts/save_codec.gd")
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok:
  print("PASS: ", message)
 else:
  failures += 1
  push_error(message)

func _initialize() -> void:
 call_deferred("run")

func overwrite(path: String, text: String) -> void:
 var file := FileAccess.open(path, FileAccess.WRITE)
 file.store_string(text)
 file.close()

func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.spawning_enabled = false
 for i in range(90):
  await physics_frame
 main.player.set_physics_process(false)
 main.combat.set_physics_process(false)
 main.items.set_physics_process(false)
 var saves = main.saves
 saves.save_path = "user://tests/save_%d.json" % Time.get_ticks_usec()
 var player = main.player
 var original: Vector2 = player.position
 player.resources.max_health = 120
 player.resources.max_mana = 70
 player.resources.mana = 17
 player.health = 73
 player.unclothed = true
 player.since_hurt = 8.0
 player.regen_fraction = 0.5
 player.velocity = Vector2(10, 0)
 var bag = main.items.local_inventory()
 bag.add("stone", 7)
 bag.add("torch", 2)
 bag.add("stone_pick", 1)
 main.interaction.selected_slot = 2
 main.world.apply_edit(Vector2i(97, 22), -1)
 main.world.apply_edit(Vector2i(97, 21), 2)
 main.world.apply_decoration("wall", Vector2i(98, 21), 1)
 main.world.apply_decoration("torch", Vector2i(98, 21), 1)
 var drop_id: int = main.items.spawn_drop("stone", 4, original + Vector2(120, -20))
 main.items.drops[drop_id].age = 7
 main.items.drops[drop_id].velocity = Vector2(2, 3)
 var anchor := original + Vector2(80, 0)
 var spirit_id: int = main.combat.spawn_entity("spirit", anchor + Vector2(10, -10), anchor)
 main.combat.entities[spirit_id].health = 1
 var contents = load("res://scripts/inventory.gd").new()
 contents.add("stone_blade", 1)
 main.combat.set_chest(5, {"owner": 1, "profile": saves.profile_id, "position": original + Vector2(-32, 0), "contents": contents.to_data()})
 main.combat.world_time = 187.5
 main.combat.spawn_timer = 6.2
 main.combat.spawn_sequence = 3
 check_result(saves.save_now(), "Complete world writes and validates atomically")
 var expected: Dictionary = saves.capture()
 var codec = Codec.new()
 var decoded: Variant = codec.decode(JSON.parse_string(JSON.stringify(codec.encode(expected), "", true, true)))
 check_result(codec.error == "" and decoded == expected, "JSON codec preserves vectors cell keys and integer IDs")
 check_result(Schema.validate(expected) == "", "Schema accepts complete game state")
 main.world.apply_edit(Vector2i(97, 22), 2)
 main.world.apply_edit(Vector2i(97, 21), -1)
 main.world.apply_decoration("torch", Vector2i(98, 21), -1)
 main.combat.world_time = 0
 bag.load_data([])
 player.health = 100
 check_result(saves.load_now(), "Saved world loads after live state is changed")
 check_result(main.world.block_at(Vector2i(97, 22)) == -1 and main.world.block_at(Vector2i(97, 21)) == 2, "Mined air and placed solid both restore")
 check_result(main.world.wall_at(Vector2i(98, 21)) == 1 and main.world.torches.has(Vector2i(98, 21)), "Wall and enabled torch restore")
 check_result(main.items.local_inventory().count_item("stone") == 7 and main.interaction.selected_slot == 2, "Inventory and selected hotbar slot restore")
 check_result(main.player.health == 73 and main.player.unclothed and main.player.position == original and main.player.velocity == Vector2(10, 0), "Player health appearance position and velocity restore")
 check_result(main.combat.world_time == 187.5 and main.combat.is_night() and is_equal_approx(main.combat.spawn_timer, 6.2), "Night and spawn timer restore without waiting")
 check_result(main.combat.entities[spirit_id].health == 1 and main.combat.entities[spirit_id].anchor == anchor, "Wounded spirit retains health and leash anchor")
 check_result(main.combat.chests[5].contents == contents.to_data(), "Death chest contents restore")
 check_result(main.items.drops[drop_id].count == 4 and main.items.drops[drop_id].velocity == Vector2(2, 3) and main.items.drops[drop_id].age == 7, "Dropped stack physics and pickup age restore")
 check_result(main.player.resources.max_health == 120 and main.player.resources.mana == 17 and main.player.resources.max_mana == 70 and not main.combat.player_data(main.player).has("stamina"), "Disk load restores HP/mana and omits removed stamina")
 var legacy: Dictionary = expected.duplicate(true)
 for field in ["max_health", "mana", "max_mana", "stamina", "max_stamina", "stamina_delay"]:
  legacy.profiles[saves.profile_id].life.erase(field)
 for entity in legacy.combat.entities.values():
  for field in ["base_health", "max_health", "scaling_players"]: entity.erase(field)
 check_result(saves.restore(legacy) == "" and main.player.resources.mana == 50 and not main.player.resources.snapshot().has("stamina"), "Old saves load with resource defaults and no repeated enemy scaling")
 var bad: Dictionary = expected.duplicate(true)
 bad.world.blocks[Vector2i(-1, 0)] = 1
 var unchanged: Dictionary = saves.capture()
 check_result(saves.restore(bad) != "" and saves.capture() == unchanged, "Out-of-bounds edit rejected before mutating live world")
 bad = expected.duplicate(true)
 bad.profiles[saves.profile_id].inventory[0].count = 1000
 check_result(saves.restore(bad) != "", "Oversized inventory stack rejected")
 bad = expected.duplicate(true)
 bad.profiles[saves.profile_id].inventory[0].item = "unknown_item"
 check_result(saves.restore(bad) != "", "Unknown item rejected")
 bad = expected.duplicate(true)
 bad.format = 999
 check_result(saves.restore(bad) != "", "Future incompatible save version rejected")
 bad = expected.duplicate(true)
 bad.combat.entities[spirit_id].position = anchor + Vector2(200, 0)
 check_result(saves.restore(bad) != "", "Spirit outside tether rejected")
 var malformed = Codec.new()
 malformed.decode({"map": [["duplicate", 1], ["duplicate", 2]]})
 check_result(malformed.error != "", "Duplicate JSON map key rejected")
 var probe := Node.new()
 probe.set_script(load("res://scripts/save_service.gd"))
 main.add_child(probe)
 check_result(probe.profile_id == saves.profile_id and probe.profile_key.sha256_text() == saves.profile_key.sha256_text(), "Profile identity survives service recreation")
 check_result(probe.identity_error.contains("уже открыт") and not probe.can_save(), "Second instance of a profile cannot overwrite its live save")
 probe.queue_free()
 check_result(saves.authorize(saves.profile_id, saves.profile_key) != "", "Same character cannot connect twice concurrently")
 var peer_id := "f".repeat(32)
 saves.profiles[peer_id] = {"key_hash": "fixture_key".sha256_text()}
 check_result(saves.authorize(peer_id, "0".repeat(64)) != "", "Wrong reconnect key cannot claim stored character")
 saves.profiles.erase(peer_id)
 main.items.local_inventory().add("dirt", 1)
 check_result(saves.save_now() and FileAccess.file_exists(saves.save_path + ".bak"), "Second save keeps previous valid backup")
 overwrite(saves.save_path, "broken primary")
 check_result(saves.load_now() and saves.status.contains("резервной") and main.items.local_inventory().count_item("dirt") == 0, "Corrupt primary falls back to prior complete backup")
 check_result(saves.save_now() and saves._read(saves.save_path + ".bak").error == "", "Saving recovery preserves valid backup rather than corrupt primary")
 overwrite(saves.save_path, "broken primary")
 overwrite(saves.save_path + ".bak", "broken backup")
 unchanged = saves.capture()
 check_result(not saves.load_now() and saves.write_blocked and saves.capture() == unchanged, "Two corrupt files leave world unchanged and block autosave")
 check_result(not saves.save_now() and FileAccess.get_file_as_string(saves.save_path) == "broken primary", "Blocked autosave never overwrites damaged original")
 saves.new_world()
 check_result(saves._read(saves.save_path).error == "" and not saves.write_blocked and main.items.local_inventory().count_item("stone") == 0, "Explicit new world archives prior files and creates valid clean slot")
 var archived := false
 for name in DirAccess.get_files_at(saves.save_path.get_base_dir()):
  if name.contains(".archive_"):
   archived = true
 check_result(archived, "Archived prior saves remain recoverable")
 main.items.local_inventory().add("dirt", 7)
 saves.new_world()
 var archived_state: Dictionary = saves._read(saves.save_path + ".bak").state
 check_result(archived_state.profiles[saves.profile_id].inventory[0].item == "dirt" and archived_state.profiles[saves.profile_id].inventory[0].count == 7, "New world archives latest live progress before resetting")
 print("Save failures: ", failures)
 quit(1 if failures else 0)
