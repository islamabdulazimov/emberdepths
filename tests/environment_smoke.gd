extends SceneTree
const Trees = preload("res://data/trees.gd")
const Daylight = preload("res://data/daylight.gd")
const Schema = preload("res://scripts/save_schema.gd")
var failures := 0

func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ", message)
 else:
  failures += 1
  push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.interaction.set_process(false)
 main.combat.set_physics_process(false)
 main.combat.spawning_enabled = false
 main.player.set_physics_process(false)
 var world = main.world
 var initial: Array = world.tree_snapshot()
 check_result(initial.size() >= 10, "Surface has a forest rather than isolated decoration")
 check_result(initial == Trees.generate(world), "Same seed recreates identical tree locations and variants")
 var safe := true
 var grounded := true
 var heights: Dictionary = {}
 var forms: Dictionary = {}
 for tree in initial:
  safe = safe and absi(tree.cell.x - world.world_width / 2) >= 11
  grounded = grounded and tree.active and world.block_at(tree.cell) in [0,1] and tree.cell.y == world.heights[tree.cell.x]
  for y in range(tree.cell.y - tree.height, tree.cell.y):
   grounded = grounded and world.block_at(Vector2i(tree.cell.x,y)) == -1
  heights[tree.height] = true
  forms[tree.form] = true
 check_result(safe, "Tree roots and crowns leave the multiplayer spawn area clear")
 check_result(grounded, "Generated trees stand on soil with a clear trunk corridor")
 check_result(heights.size() > 1 and forms.size() == 3, "Tree heights and crown forms vary")
 world.world_seed += 1
 check_result(initial != Trees.generate(world), "Different seed changes forest layout")
 world.world_seed -= 1
 check_result(not is_equal_approx(Trees.wind(initial[0],4), Trees.wind(initial[1],4)), "Neighbours have different wind phases")
 check_result(Trees.wind(initial[0],4) == Trees.wind(initial[0],4), "Wind is repeatable at the shared world time")
 var tree: Dictionary = initial[0]
 var at := Vector2(tree.cell.x * 16 + 8,tree.cell.y * 16 - 10)
 var near := Trees.sound_level([tree], at)
 check_result(near > 0 and Trees.sound_level([tree],at + Vector2(300,0)) == 0, "Rustle fades completely beyond listening distance")
 check_result(Trees.sound_level([tree],at + Vector2(0,100)) == 0, "Surface rustle cannot follow player into deep caves")
 var crowd: Array = []
 for i in range(100): crowd.append(tree)
 check_result(Trees.sound_level(crowd,at) <= 1 and main.world.forest.get_child_count() == 1, "Dense forest is capped and uses only one audio voice")
 check_result(main.world.forest.rustle.stream is AudioStreamWAV and main.world.forest.rustle.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Original leaf audio is loaded as a looping stream")
 main.player.position = at
 main.world.forest._process(1)
 check_result(main.world.forest.rustle.volume_db <= Trees.MAX_VOLUME_DB, "Audio output stays below the shared volume cap")
 world.apply_edit(tree.cell,-1)
 check_result(not world.trees[0].active, "Removing supporting ground retires a tree immediately")
 world.apply_edit(tree.cell,0)
 check_result(not world.trees[0].active, "Replacing soil cannot resurrect removed tree state")
 var stored: Array = world.tree_snapshot()
 world.trees[0].active = true
 check_result(not stored[0].active, "Tree snapshot is detached from live mutations")
 world.restore_trees(stored)
 main.combat.world_time = 208.0
 main.saves.save_path = "user://tests/trees.json"
 check_result(main.saves.save_now(), "Tree records and shared sky time save to disk")
 world.trees.clear()
 main.combat.world_time = 90.0
 check_result(main.saves.load_now() and world.tree_snapshot() == stored and main.combat.world_time == 208.0, "Disk reload restores exact forest variants removal state and night")
 var saved: Dictionary = main.saves.capture()
 var invalid := saved.duplicate(true)
 invalid.world.trees[0].height = "bad"
 check_result(main.saves.restore(invalid) != "" and world.tree_snapshot() == stored, "Malformed tree rejected before world mutation")
 invalid = saved.duplicate(true)
 invalid.world.trees.append(invalid.world.trees[0].duplicate())
 check_result(Schema.validate(invalid) != "", "Duplicate tree columns are rejected")
 var legacy := saved.duplicate(true)
 legacy.world.erase("trees")
 legacy.world.blocks[tree.cell] = -1
 check_result(main.saves.restore(legacy) == "" and not world.trees[0].active, "Old saves receive deterministic trees with mined supports respected")
 var empty := saved.duplicate(true)
 empty.world.trees = []
 check_result(main.saves.restore(empty) == "" and world.trees.is_empty(), "An explicitly empty saved forest stays empty")
 check_result(Daylight.sample(90).sun_alpha == 1 and Daylight.sample(90).moon_alpha == 0 and Daylight.sample(90).stars == 0, "Noon shows sun with neither moon nor stars")
 check_result(Daylight.sample(210).moon_alpha == 1 and Daylight.sample(210).sun_alpha == 0 and Daylight.sample(210).stars == 1, "Midnight shows moon and stars without sun")
 var size := Vector2(960,540)
 var sunrise := Daylight.orbit(0,size)
 var noon := Daylight.orbit(0.5,size)
 var sunset := Daylight.orbit(1,size)
 check_result(sunrise.x < noon.x and noon.x < sunset.x and noon.y < sunrise.y and is_equal_approx(sunrise.y,sunset.y), "Celestial bodies rise and set along a smooth arc")
 check_result(Daylight.sample(210).ambient.r < Daylight.sample(90).ambient.r, "Surface light uses the same day night phase as sky")
 check_result(Daylight.sample(172).horizon.r > Daylight.sample(90).horizon.r, "Sunset horizon gains warm colours")
 check_result(Daylight.sample(225).stars > Daylight.sample(235).stars and Daylight.sample(235).stars > Daylight.sample(239).stars, "Stars fade gradually before dawn")
 var wrap_a: Dictionary = Daylight.sample(239.999)
 var wrap_b: Dictionary = Daylight.sample(0.001)
 check_result(wrap_a.top.is_equal_approx(wrap_b.top) and wrap_a.ambient.is_equal_approx(wrap_b.ambient), "Dawn colours remain continuous across clock wrap")
 check_result(Daylight.sample(90) == Daylight.sample(330), "Sky repeats from the existing 240 second cycle")
 main.combat.world_time = 90
 main.player.position = world.spawn_position()
 main._process(0)
 var light: Color = main.ambient.color
 var sky_transform: Transform2D = main.sky.get_global_transform_with_canvas()
 var sun := Daylight.orbit(Daylight.sample(main.combat.world_time).sun_progress,size)
 main.player.position.x += 200
 main.player.get_node("Camera2D").reset_smoothing()
 main.player.get_node("Camera2D").force_update_scroll()
 main._process(0)
 check_result(sky_transform == main.sky.get_global_transform_with_canvas() and sun == Daylight.orbit(Daylight.sample(main.combat.world_time).sun_progress,size) and light == main.ambient.color and main.sky.get_parent().layer < 0, "Camera travel cannot move sky orbit or alter surface time")
 check_result(main.combat.world_time == 90, "Visual updates never advance their own world clock")
 print("Environment failures: ",failures)
 quit(1 if failures else 0)
