extends SceneTree
var failures := 0
func check_result(ok: bool, message: String) -> void:
 if ok: print("PASS: ", message)
 else:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var state = load("res://scripts/boss_state.gd").new()
 check_result(state.begin({"name": "Test boss", "health": 100, "poise": 50}, 3) and state.max_health == 150, "Generic encounter freezes shared health scaling at start")
 check_result(not state.begin({"name": "Other", "health": 100, "poise": 99}, 4) and state.max_health == 150, "Existing boss cannot multiply health again")
 var ui := Control.new()
 ui.set_script(load("res://scripts/boss_ui.gd"))
 root.add_child(ui)
 ui.bind_boss(state)
 check_result(ui.visible and ui.health_bar.max_value == 150 and ui.poise_bar.visible and ui.poise_bar.max_value == 50, "Generic UI binds health and separate poise")
 state.health = 72
 state.poise = 11
 ui.refresh()
 check_result(ui.health_bar.value == 72 and ui.poise_bar.value == 11, "UI only displays model health and poise")
 var second = load("res://scripts/boss_state.gd").new()
 second.begin({"name": "No poise", "health": 80, "show_poise": false}, 1)
 ui.bind_boss(second)
 check_result(ui.title.text.begins_with("No poise") and not ui.poise_bar.visible, "Any other boss can hide poise")
 second.active = false
 ui.refresh()
 check_result(not ui.visible, "Ending encounter hides boss interface")
 var replica = load("res://scripts/boss_state.gd").new()
 replica.apply(state.snapshot())
 check_result(replica.max_health == 150 and replica.health == 72 and replica.scaling_players == 3, "Boss replication restores frozen health without recalculating")
 print("Boss UI failures: ", failures)
 quit(1 if failures else 0)
