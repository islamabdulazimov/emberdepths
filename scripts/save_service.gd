extends Node
const Codec = preload("res://scripts/save_codec.gd")
const Schema = preload("res://scripts/save_schema.gd")
const AUTOSAVE_SECONDS := 30.0
const MAX_FILE_BYTES := 64 * 1024 * 1024
var main: Node2D
var automatic := true
var profile_name := "default"
var profile_id := ""
var profile_key := "" # Never included in world snapshots or logs.
var identity_error := ""
var status := ""
var restore_notice := ""
var write_blocked := false
var profiles: Dictionary = {}
var peer_profiles: Dictionary = {}
var return_state: Dictionary = {}
var return_encounter: Dictionary = {}
var elapsed := 0.0
var save_path := ""
var save_label: Label
var save_button: Button
var load_button: Button
var new_button: Button
var owns_lock := false
var lock_path := ""
var new_dialog: ConfirmationDialog

func _ready() -> void:
 main = get_parent()
 if main.has_meta("combat_test"):
  automatic = false
  write_blocked = true
  profile_name = "arena"
  profile_id = "0".repeat(32)
  profile_key = "0".repeat(64)
  peer_profiles[1] = profile_id
  return
 if not GameApp.selected_world.is_empty(): profile_name=GameApp.selected_world.profile
 automatic = not OS.get_cmdline_args().has("--script") or OS.get_cmdline_user_args().has("--with-save")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--profile="):
   var candidate := arg.trim_prefix("--profile=")
   var ascii_name := true
   for character in candidate:
    if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_":
     ascii_name = false
   if candidate.length() > 0 and candidate.length() <= 20 and candidate.is_valid_identifier() and ascii_name:
    profile_name = candidate
 save_path = "user://saves/world_%s.json" % profile_name
 _lock_profile()
 _identity()
 peer_profiles[1] = profile_id

func _lock_profile() -> void:
 var directory := ProjectSettings.globalize_path("user://profiles")
 if DirAccess.make_dir_recursive_absolute(directory) != OK:
  identity_error = "Не удалось открыть каталог профилей"
  write_blocked = true
  status = identity_error
  return
 lock_path = directory.path_join(profile_name + ".lock")
 var error := DirAccess.make_dir_absolute(lock_path)
 if error != OK and FileAccess.file_exists(lock_path.path_join("pid")):
  var owner := FileAccess.get_file_as_string(lock_path.path_join("pid")).strip_edges()
  if owner.is_valid_int() and int(owner) > 0 and not _pid_alive(int(owner)):
   DirAccess.remove_absolute(lock_path.path_join("pid"))
   DirAccess.remove_absolute(lock_path)
   error = DirAccess.make_dir_absolute(lock_path)
 if error != OK:
  identity_error = "Профиль уже открыт. Для другого окна используйте --profile=friend"
  write_blocked = true
  status = identity_error
  return
 owns_lock = true
 var file := FileAccess.open(lock_path.path_join("pid"), FileAccess.WRITE)
 if file == null:
  identity_error = "Не удалось заблокировать профиль для записи"
  write_blocked = true
  status = identity_error
  return
 file.store_string(str(OS.get_process_id()))
 file.close()

func _pid_alive(pid: int) -> bool:
 if pid == OS.get_process_id():
  return true
 # On Unix Godot's is_process_running may only track child processes.
 # /proc answers the actual process existence question without spawning tools.
 if OS.has_feature("linux"):
  return DirAccess.dir_exists_absolute("/proc/%d" % pid)
 if OS.has_feature("windows"):
  return OS.is_process_running(pid)
 if OS.has_feature("macos"):
  var output: Array = []
  return OS.execute("/bin/kill", ["-0", str(pid)], output, true) == 0
 # If this platform cannot establish that the owner exited, protect the file.
 return true

func _exit_tree() -> void:
 if owns_lock:
  DirAccess.remove_absolute(lock_path.path_join("pid"))
  DirAccess.remove_absolute(lock_path)

func _identity() -> void:
 var path := "user://profiles/%s.json" % profile_name
 if FileAccess.file_exists(path):
  var parser := JSON.new()
  var parsed := parser.parse(FileAccess.get_file_as_string(path))
  var data: Variant = parser.data if parsed == OK else null
  if data is Dictionary and Schema.hex_id(data.get("id"), 32) and Schema.hex_id(data.get("key"), 64):
   profile_id = data.id
   profile_key = data.key
   return
  identity_error = "Повреждён локальный профиль. Восстановите файл profiles/%s.json" % profile_name
  write_blocked = true
  status = identity_error
  return
 if identity_error != "":
  return
 var crypto := Crypto.new()
 profile_id = crypto.generate_random_bytes(16).hex_encode()
 profile_key = crypto.generate_random_bytes(32).hex_encode()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://profiles"))
 var file := FileAccess.open(path, FileAccess.WRITE)
 if file == null:
  identity_error = "Не удалось записать локальный профиль"
  write_blocked = true
  status = identity_error
  return
 file.store_string(JSON.stringify({"id": profile_id, "key": profile_key}))
 file.flush()
 var err := file.get_error()
 file.close()
 if err != OK:
  identity_error = "Ошибка записи локального профиля"
  write_blocked = true
  status = identity_error

func startup() -> void:
 _build_ui()
 if identity_error != "":
  return
 main.player.profile_id = profile_id
 _capture_peer(1)
 if automatic:
  if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
   load_now()
  else:
   status = "Новый мир · автосохранение каждые 30 с"
 else:
  status = "Автосохранение выключено тестовым запуском"

func _build_ui() -> void:
 var row := HBoxContainer.new()
 row.theme = preload("res://scripts/visuals/art_direction.gd").theme()
 row.position = Vector2(708, 128)
 main.get_node("HUD").add_child(row)
 save_button = _button(row, "Сохранить", "Сохранить мир и всех персонажей на хосте", func(): save_now())
 load_button = _button(row, "Загрузить", "Вернуть мир, вещи и позицию к последнему сохранению. Текущие несохранённые изменения заменятся.", func(): load_now())
 new_button = _button(row, "Новый", "Начать новый мир с архивированием предыдущего", func(): new_dialog.popup_centered())
 save_label = Label.new()
 save_label.position = Vector2(14, 445)
 save_label.size = Vector2(680, 20)
 save_label.clip_text = true
 save_label.add_theme_font_size_override("font_size", 13)
 main.get_node("HUD").add_child(save_label)
 new_dialog = ConfirmationDialog.new()
 new_dialog.title = "Начать новый мир?"
 new_dialog.dialog_text = "Текущий мир будет сохранён в архив, затем начнётся новый.\nПерсонаж начнёт с пустым инвентарём."
 new_dialog.ok_button_text = "Архивировать и начать"
 new_dialog.confirmed.connect(new_world)
 main.get_node("HUD").add_child(new_dialog)

func _button(parent: Node, title: String, hint: String, action: Callable) -> Button:
 var button := Button.new()
 button.text = title
 button.tooltip_text = hint
 button.focus_mode = Control.FOCUS_NONE
 button.add_theme_font_size_override("font_size", 12)
 parent.add_child(button)
 button.pressed.connect(action)
 return button

func _process(delta: float) -> void:
 if is_instance_valid(save_label):
  save_label.text = status
  save_label.tooltip_text = status
  save_button.disabled = not can_save() or write_blocked
  load_button.disabled = main.network.active or main.network.stopping or identity_error != ""
  new_button.disabled = main.network.active or main.network.stopping or identity_error != ""
 if automatic and can_save() and not write_blocked:
  elapsed += delta
  if elapsed >= AUTOSAVE_SECONDS:
   elapsed = 0
   save_now()

func can_save() -> bool:
 if main.has_meta("combat_test"): return false
 return identity_error == "" and is_instance_valid(main.network) and not main.network.stopping and (not main.network.active or (main.network.connected and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.is_server()))

func _capture_peer(peer_id: int) -> void:
 if not peer_profiles.has(peer_id):
  return
 var body = main.get_node("Players").get_node_or_null(str(peer_id))
 if body == null:
  return
 var id: String = peer_profiles[peer_id]
 var digest: String = profiles.get(id, {}).get("key_hash", profile_key.sha256_text() if peer_id == 1 else "")
 var selected: int = main.interaction.selected_slot if peer_id == 1 and is_instance_valid(main.interaction) else int(main.network.commands.get(peer_id, {}).get("slot", profiles.get(id, {}).get("selected", 0)))
 profiles[id] = {"key_hash": digest, "inventory": main.items.inventory_for(peer_id).to_data(), "life": main.combat.player_data(body), "selected": selected}
 if body.fighter.mode=="block":profiles[id].life.guard_cooldown=preload("res://data/equipment.gd").SHIELD.recovery
 profiles[id].life.erase("action") # Combat input is transient, never resumed by loading.
 profiles[id].life["help_progress"]=0.0
 profiles[id].life["medicine_progress"] = 0.0 # Pending self-use is never committed by loading/rejoining.

func authorize(id: String, key: String) -> String:
 if not Schema.hex_id(id, 32) or not Schema.hex_id(key, 64):
  return "Неверный профиль"
 if peer_profiles.values().has(id):
  return "Этот персонаж уже в игре. Для второго окна используйте другой --profile"
 if profiles.has(id) and profiles[id].key_hash != key.sha256_text():
  return "Ключ персонажа не совпадает"
 if not profiles.has(id) and profiles.size() >= 64:
  return "Достигнут предел персонажей мира"
 return ""

func attach_peer(peer_id: int, id: String, key: String) -> int:
 var fresh := not profiles.has(id)
 peer_profiles[peer_id] = id
 var body = main.get_node("Players").get_node(str(peer_id))
 body.profile_id = id
 if fresh:
  profiles[id] = {"key_hash": key.sha256_text()}
  _capture_peer(peer_id)
 else:
  var record: Dictionary = profiles[id]
  main.items.inventory_for(peer_id).load_data(record.inventory)
  _restore_life(peer_id, record.life)
 for chest_id in main.combat.chests:
  var chest = main.combat.chests[chest_id]
  if chest.owner_profile == id:
   chest.owner_id = peer_id
   main.combat.chest_changed.emit(chest_id, main.combat.chest_data(chest_id, true))
 main.survival.recovery_dirty[peer_id]=true
 return int(profiles[id].get("selected", 0))

func detach_peer(peer_id: int) -> void:
 _capture_peer(peer_id)
 peer_profiles.erase(peer_id)
 main.items.inventories.erase(peer_id)

func checkpoint() -> void:
 if automatic and can_save() and not write_blocked:
  save_now()

func capture() -> Dictionary:
 for peer_id in peer_profiles:
  _capture_peer(peer_id)
 var combat: Dictionary = main.combat.snapshot(true,true)
 combat.players = {}
 for enemy in combat.entities.values():
  for key in ["attack_state","attack_elapsed","attack_facing","attack_target"]: enemy.erase(key)
 combat["spawn_timer"] = main.combat.spawn_timer
 combat["spawn_sequence"] = main.combat.spawn_sequence
 combat["next_entity"] = main.combat.next_entity_id
 combat["next_chest"] = main.combat.next_chest_id
 return {"format": 1, "combat_rules":3, "generator": main.world.generator_version, "host_profile": profile_id, "world": {"seed": main.world.world_seed, "width": main.world.world_width, "depth": main.world.world_depth, "blocks": main.world.changes.duplicate(true), "walls": main.world.wall_changes.duplicate(true), "torches": main.world.torches.keys(), "trees": main.world.tree_snapshot(), "doors": main.world.door_snapshot(), "storage": main.storage.snapshot(),"storage_opened":main.storage.opened_snapshot(),"npcs":main.world.npc_records.duplicate(true),"sites":main.world.site_progress.duplicate(true)}, "profiles": profiles.duplicate(true), "drops": main.items.snapshot(), "next_drop": main.items.next_drop_id, "combat": combat}

func _restore_life(peer_id: int, life: Dictionary) -> void:
 var body = main.get_node("Players").get_node(str(peer_id))
 # Force position application even when a saved alive character has revision 0.
 body.life_revision = -1
 main.combat.apply_player_state(peer_id, life)
 body.medicine_progress = 0
 body.medicine_slot = -1
 body.medicine_latch = -1
 var relocated: bool = not main.world.character_fits(body.position)
 if relocated:
  body.position = main.world.safe_spawn_position()
  body.velocity = Vector2.ZERO
 if peer_id == 1:
  var cell: Vector2i = main.world.cell_at(body.position)
  restore_notice = "Вы (%d, %d)" % [cell.x, cell.y]
  if relocated:
   restore_notice += " · точка занята блоком, выбрана безопасная"
  elif body.dead:
   restore_notice += " · сохранено упавшее состояние; выберите помощь или возрождение"
  var camera: Camera2D = body.get_node("Camera2D")
  body.reset_physics_interpolation()
  camera.align()
  camera.reset_smoothing()
  camera.reset_physics_interpolation()
  camera.force_update_scroll()

func restore(state: Dictionary) -> String:
 var error: String = Schema.validate(state)
 if error != "":
  return error
 if state.host_profile != profile_id or state.profiles[profile_id].key_hash != profile_key.sha256_text():
  return "Мир принадлежит другому локальному профилю"
 state=preload("res://scripts/death_migration.gd").upgrade(state)
 error=Schema.validate(state)
 if error!="":return error
 main.encounter.cancel_for_load()
 main.world.generator_version = int(state.generator)
 main.world.world_seed = state.world.seed
 main.world.world_width = state.world.width
 main.world.world_depth = state.world.depth
 main.world.generate()
 for cell in state.world.blocks:
  main.world.apply_edit(cell, state.world.blocks[cell])
 for cell in state.world.walls:
  main.world.apply_decoration("wall", cell, state.world.walls[cell])
 for cell in state.world.torches:
  main.world.apply_decoration("torch", cell, 1)
 if state.world.has("trees"):
  main.world.restore_trees(state.world.trees)
 main.world.restore_doors(state.world.get("doors",{}))
 main.storage.restore(state.world.get("storage",{}))
 main.world.site_progress = state.world.get("sites",{}).duplicate(true)
 main.world.npc_records=state.world.get("npcs",{}).duplicate(true)
 main.npcs.sync()
 for anchor in state.world.get("storage_opened",[]):
  if main.storage.chests.has(anchor): main.storage.chests[anchor].opened = true
 main.world.solid.update_internals()
 main.items.inventories.clear()
 main.items.load_drops(state.drops)
 main.items.next_drop_id = state.next_drop
 main.items.attack_ready_at.clear()
 main.items.attack_profiles.clear()
 main.items.tool_ready_at.clear()
 main.reset_players()
 main.add_player(1, main.world.safe_spawn_position())
 main.select_local_player(1)
 main.combat.apply_snapshot(state.combat)
 main.combat.spawn_timer = state.combat.spawn_timer
 main.combat.spawn_sequence = state.combat.spawn_sequence
 main.combat.next_entity_id = state.combat.next_entity
 main.combat.next_chest_id = state.combat.next_chest
 main.combat.last_night = main.combat.is_night()
 profiles = state.profiles.duplicate(true)
 for record in profiles.values():
  for field in ["stamina","max_stamina","stamina_delay"]:record.life.erase(field)
  record.life.equipment=preload("res://data/equipment.gd").clean(record.life.get("equipment",{}))
 peer_profiles = {1: profile_id}
 main.items.inventory_for(1).load_data(profiles[profile_id].inventory)
 _restore_life(1, profiles[profile_id].life)
 main.interaction.selected_slot = int(profiles[profile_id].selected)
 main.interaction.mining_time = 0
 main.interaction.mining_cell = Vector2i(-1, -1)
 if main.inventory_ui.opened:
  main.inventory_ui.toggle()
 main.inventory_ui.source_slot = -1
 main.inventory_ui.refresh()
 return ""

func _read(path: String) -> Dictionary:
 if not FileAccess.file_exists(path):
  return {"error": "Файл не найден"}
 var file := FileAccess.open(path, FileAccess.READ)
 if file == null or file.get_length() > MAX_FILE_BYTES:
  return {"error": "Файл недоступен или слишком велик"}
 var text := file.get_as_text()
 file.close()
 var envelope_parser := JSON.new()
 if envelope_parser.parse(text) != OK:
  return {"error": "Повреждён заголовок JSON"}
 var envelope: Variant = envelope_parser.data
 if not envelope is Dictionary or not envelope.has_all(["version", "payload", "sha256"]) or envelope.version != 1 or not envelope.payload is String or not envelope.sha256 is String:
  return {"error": "Неверный заголовок сохранения"}
 if envelope.payload.sha256_text() != envelope.sha256:
  return {"error": "Контрольная сумма не совпадает"}
 var parser := JSON.new()
 if parser.parse(envelope.payload) != OK:
  return {"error": "Повреждён JSON"}
 var codec = Codec.new()
 var state: Variant = codec.decode(parser.data)
 if codec.error != "":
  return {"error": codec.error}
 var error: String = Schema.validate(state)
 if error != "":
  return {"error": error}
 return {"error": "", "state": state}

func _stamp() -> String:
 return "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]

func _archive(path: String) -> bool:
 if not FileAccess.file_exists(path):
  return true
 return DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".archive_" + _stamp())) == OK

func save_now() -> bool:
 if not can_save() or write_blocked:
  status = "Сохраняет хост" if main.network.active and not multiplayer.is_server() else "Запись заблокирована: " + (identity_error if identity_error != "" else "сначала восстановите мир или начните новый")
  return false
 var state := capture()
 var error: String = Schema.validate(state)
 if error != "":
  status = "Ошибка сохранения: " + error
  return false
 var codec = Codec.new()
 var payload := JSON.stringify(codec.encode(state), "", true, true)
 var text := JSON.stringify({"version": 1, "payload": payload, "sha256": payload.sha256_text()})
 if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
  status = "Сохранение превысило допустимый размер"
  return false
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir())) != OK:
  status = "Не удалось создать каталог сохранений"
  return false
 var temporary := save_path + ".tmp"
 var file := FileAccess.open(temporary, FileAccess.WRITE)
 if file == null:
  status = "Не удалось открыть файл для записи"
  return false
 file.store_string(text)
 file.flush()
 var write_error := file.get_error()
 file.close()
 if write_error != OK or _read(temporary).error != "":
  status = "Ошибка проверки записанного файла; старый мир сохранён"
  return false
 if FileAccess.file_exists(save_path):
  if _read(save_path).error == "":
   if DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bak.tmp")) != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".bak.tmp"), ProjectSettings.globalize_path(save_path + ".bak")) != OK:
    status = "Не удалось обновить резервную копию; старый мир сохранён"
    return false
  elif not _archive(save_path):
   status = "Не удалось архивировать повреждённый файл"
   return false
 if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(save_path)) != OK:
  status = "Не удалось завершить запись; старый файл сохранён"
  return false
 elapsed = 0
 var saved_cell: Vector2i = main.world.cell_at(main.player.position)
 GameApp.touch_world()
 status = "Сохранено в (%d, %d) · %s" % [saved_cell.x, saved_cell.y, Time.get_time_string_from_system()]
 return true

func load_now() -> bool:
 if main.network.active or main.network.stopping or identity_error != "":
  status = "Для загрузки сначала отключите сетевую сессию" if identity_error == "" else identity_error
  return false
 var result := _read(save_path)
 var backup := false
 if result.error != "":
  result = _read(save_path + ".bak")
  backup = result.error == ""
 if result.error != "":
  write_blocked = true
  status = "Мир не загружен. Файлы сохранены, автозапись заблокирована: " + result.error
  return false
 # Keep original bytes before the first rules upgrade, in addition to rotating .bak.
 if int(result.state.get("combat_rules",1))<3:
  var original:=save_path+".pre-adventure.original"
  var source_path:=save_path+".bak" if backup else save_path
  if not FileAccess.file_exists(original) and DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path),ProjectSettings.globalize_path(original))!=OK:
   write_blocked=true
   status="Не удалось сохранить оригинал перед обновлением правил; загрузка отменена"
   return false
 if preload("res://scripts/death_migration.gd").required(result.state):
  var death_original:=save_path+".pre-death-v3.original"
  var death_source:=save_path+".bak" if backup else save_path
  if not FileAccess.file_exists(death_original) and DirAccess.copy_absolute(ProjectSettings.globalize_path(death_source),ProjectSettings.globalize_path(death_original))!=OK:
   write_blocked=true;status="Не удалось сохранить исходный файл перед переносом вещей";return false
 var error := restore(result.state)
 if error != "":
  write_blocked = true
  status = "Мир не загружен: " + error
  return false
 write_blocked = false
 elapsed = 0
 status = ("Восстановлено из резервной копии" if backup else "Мир загружен") + " · " + restore_notice
 return true

func new_world() -> void:
 if main.network.active or main.network.stopping or identity_error != "":
  return
 if not write_blocked and not save_now():
  status = "Новый мир не начат: не удалось сохранить текущий прогресс"
  return
 if FileAccess.file_exists(save_path) and not _archive(save_path):
  status = "Не удалось архивировать старый мир"
  return
 if FileAccess.file_exists(save_path + ".bak") and not _archive(save_path + ".bak"):
  status = "Не удалось архивировать резервную копию"
  return
 # No old player/entity data may bleed into the new world.
 main.encounter.reset_run()
 profiles.clear()
 if not OS.get_cmdline_args().has("--script") or OS.get_cmdline_user_args().has("--expanded-world"):
  if OS.get_cmdline_user_args().has("--expanded-world"): main.world.configure_expanded()
  else: main.world.configure_new(GameApp.selected_world.get("size","small"))
 main.world.world_seed = posmod(main.world.world_seed + 1, 2147483647)
 main.world.generate()
 main.items.inventories.clear()
 main.items.load_drops({})
 main.items.next_drop_id = 1
 main.reset_players()
 main.add_player(1, main.world.safe_spawn_position())
 main.select_local_player(1)
 main.combat.apply_snapshot({"time": 0.0, "entities": {}, "chests": {}, "players": {}})
 main.combat.spawn_timer = 40
 main.combat.spawn_sequence = 0
 main.combat.next_entity_id = 1
 main.combat.next_chest_id = 1
 peer_profiles = {1: profile_id}
 write_blocked = false
 _capture_peer(1)
 save_now()

func begin_visit() -> bool:
 if identity_error != "":
  status = identity_error
  return false
 if automatic and not save_now():
  return false
 return_state = capture()
 return_encounter = main.encounter.snapshot()
 return true

func end_visit() -> void:
 if not return_state.is_empty():
  var error := restore(return_state)
  return_state.clear()
  if error == "" and not return_encounter.is_empty(): main.encounter.apply(return_encounter)
  return_encounter.clear()
  status = "Возврат в свой одиночный мир" if error == "" else "Ошибка возврата: " + error
