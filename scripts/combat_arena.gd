extends "res://scripts/main.gd"
var floor_y := 26
var arena_controls: HBoxContainer
var arena_camera: Camera2D
func _ready() -> void:
 super._ready()
 combat.spawning_enabled = false
 combat.world_time = 165
 combat_zone.preset = Rect2i(80,14,32,14)
 player.get_node("Camera2D").enabled = false
 arena_camera = Camera2D.new()
 arena_camera.position = Vector2(96*16,280)
 arena_camera.zoom = Vector2(1.5,1.5)
 add_child(arena_camera)
 arena_camera.make_current()
 # This branch never opens, locks or saves the real player's profile.
 saves.save_button.get_parent().hide()
 saves.status = "Учебная арена · медная рамка защищает блоки во время боя · не сохраняется"
 saves.save_label.position = Vector2(14,516)
 saves.save_label.size = Vector2(930,20)
 saves.save_label.add_theme_color_override("font_outline_color",Color("18252e"))
 saves.save_label.add_theme_constant_override("outline_size",2)
 network_status.hide()
 for child in $HUD.get_children():
  if child is HBoxContainer: child.hide()
 var row := HBoxContainer.new()
 arena_controls = row
 row.position = Vector2(14,188)
 row.theme = preload("res://scripts/visuals/art_direction.gd").theme()
 $HUD.add_child(row)
 for entry in [["Пепельник",spawn_practice_enemy],["Andrew",spawn_practice_boss],["Сброс арены",reset_arena],["В свой мир",leave_arena]]:
  var button := Button.new()
  button.text = entry[0]
  button.focus_mode = Control.FOCUS_NONE
  button.pressed.connect(entry[1])
  row.add_child(button)
 reset_arena()
 spawn_practice_enemy()

func prepare_ground() -> void:
 for x in range(72,121):
  world.heights[x] = floor_y
  for y in range(12,floor_y): world.apply_edit(Vector2i(x,y),-1)
  for y in range(floor_y,floor_y+3): world.apply_edit(Vector2i(x,y),2)
 for tree in world.trees: tree.active = false
 for x in range(80,113):
  for y in range(18,floor_y): world.apply_decoration("wall",Vector2i(x,y),2)
 for x in [80,88,96,104,111]: world.apply_decoration("torch",Vector2i(x,24),1)
 for torch in world.torches.values(): torch.base_energy = 0.6
 world.solid.update_internals()

func reset_arena() -> void:
 encounter.reset_run()
 for id in combat.entities.keys(): combat.set_entity(id,{})
 for id in combat.chests.keys(): combat.set_chest(id,{})
 for id in items.drops.keys(): items.set_drop(id,{})
 if inventory_ui.opened: inventory_ui.toggle()
 world.generate()
 prepare_ground()
 player.fighter.reset()
 combat.respawn(player)
 player.position = Vector2(90*16+8,floor_y*16-10)
 player.reset_physics_interpolation()
 player.unclothed = false
 player.hurt_immunity = 0 # A fresh practice trial should demonstrate the first real hit/parry.
 player.medicine_cooldown = 0
 player.roll_cooldown=0
 player.guard_cooldown=0
 player.block_requires_release=false
 player.equipment["ability"]="traveler_knot"
 var bag = items.local_inventory()
 bag.load_data([])
 for entry in [["stone_blade",1],["stone_pick",1],["stone",30],["stone_wall",20],["torch",8],["spark_balm",6],["wood",44]]: bag.add(entry[0],entry[1])
 interaction.selected_slot = 0
 arena_camera.force_update_scroll()

func spawn_practice_enemy() -> void:
 if is_instance_valid(encounter.actor):
  encounter.notice = "Завершите бой с Andrew или сбросьте арену"
  return
 for enemy in combat.entities.values():
  if enemy.kind == "ashling": return
 combat.spawn_entity("ashling",Vector2(94*16+8,floor_y*16))

func spawn_practice_boss() -> void:
 if is_instance_valid(encounter.actor): return
 reset_arena()
 for id in combat.entities.keys(): combat.set_entity(id,{})
 encounter.used_once = false
 encounter.kills = 3
 encounter.pending = true
 encounter.try_spawn()

func leave_arena() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn")
func _request_close() -> void: get_tree().quit()

func _process(delta: float) -> void:
 super._process(delta)
 if is_instance_valid(arena_controls): arena_controls.visible = not inventory_ui.opened
