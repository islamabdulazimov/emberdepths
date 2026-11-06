extends Node
const Appearance = preload("res://data/appearance.gd")
const ROOT := "user://library"
const FPS := [30,60,120,240,0]
var selected_character: Dictionary = {}
var selected_world: Dictionary = {}
var new_game := false
var menu_error := ""
var library_warnings: Array[String] = []
var video := {"fps":240,"vsync":false,"width":1280,"height":720}
var resolution_previous := Vector2i.ZERO
var resolution_candidate := Vector2i.ZERO
var resolution_pending := false
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 load_video()
func warn(message: String) -> void:
 if message not in library_warnings:library_warnings.append(message)
func safe_id(value: Variant) -> bool:
 if not value is String or value.is_empty() or value.length() > 40: return false
 for c in value:
  if not c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_": return false
 return true
func read_json(path: String, limit: int = 1048576) -> Dictionary:
 if not FileAccess.file_exists(path): return {}
 var file := FileAccess.open(path,FileAccess.READ)
 if file == null or file.get_length() > limit: return {}
 var value: Variant = JSON.parse_string(file.get_as_text())
 return value if value is Dictionary else {}
func write_json(path: String, value: Dictionary) -> bool:
 if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
 var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file == null: return false
 file.store_string(JSON.stringify(value))
 file.flush()
 file.close()
 if FileAccess.file_exists(path):
  if DirAccess.copy_absolute(path,path+".bak") != OK: return false
 var result := DirAccess.rename_absolute(path+".tmp",path)
 if result != OK and FileAccess.file_exists(path+".bak"):
  DirAccess.remove_absolute(path)
  result = DirAccess.rename_absolute(path+".tmp",path)
  if result != OK: DirAccess.copy_absolute(path+".bak",path)
 return result == OK
func unique_id(prefix: String, folder: String) -> String:
 var value := prefix+Crypto.new().generate_random_bytes(8).hex_encode()
 while FileAccess.file_exists(ROOT+"/"+folder+"/"+value+".json"): value = prefix+Crypto.new().generate_random_bytes(8).hex_encode()
 return value
func characters() -> Array:
 var result: Array = []
 var directory := DirAccess.open(ROOT+"/characters")
 if directory == null: return result
 for file in directory.get_files():
  if not file.ends_with(".json"): continue
  var item := read_json(ROOT+"/characters/"+file)
  if safe_id(item.get("id")) and item.get("name") is String and not item.name.strip_edges().is_empty() and Appearance.valid(item.get("appearance")):
   item.appearance = Appearance.clean(item.appearance)
   result.append(item)
  else: warn("Пропущена повреждённая запись персонажа: "+file)
 result.sort_custom(func(a,b): return a.name.naturalnocasecmp_to(b.name) < 0)
 return result
func number(value: Variant, low: int, high: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
func worlds(character_id: String) -> Array:
 var result: Array = []
 var directory := DirAccess.open(ROOT+"/worlds")
 if directory == null: return result
 for file in directory.get_files():
  if not file.ends_with(".json"): continue
  var item := read_json(ROOT+"/worlds/"+file)
  if safe_id(item.get("id")) and item.get("character") == character_id and item.get("name") is String and not item.name.strip_edges().is_empty() and number(item.get("seed",0),0,2147483647) and number(item.get("last_played",0),0,4102444800) and item.get("size") in ["small","large"] and safe_id(item.get("profile")) and item.profile.length() <= 20: result.append(item)
  elif item.is_empty(): warn("Пропущена повреждённая запись мира: "+file)
 result.sort_custom(func(a,b): return int(a.get("last_played",0)) > int(b.get("last_played",0)))
 return result
func create_character(label: String, appearance: Dictionary) -> Dictionary:
 label = label.strip_edges().substr(0,32)
 if label.is_empty() or not Appearance.valid(appearance): return {}
 var item := {"id":unique_id("c","characters"),"name":label,"appearance":appearance.duplicate(true)}
 return item if write_json(ROOT+"/characters/"+item.id+".json",item) else {}
func create_world(character: Dictionary, label: String, size: String) -> Dictionary:
 label = label.strip_edges().substr(0,40)
 if not safe_id(character.get("id")) or label.is_empty() or size not in ["small","large"]: return {}
 var id := unique_id("w","worlds")
 var item := {"id":id,"character":character.id,"name":label,"size":size,"profile":id,"seed":int(Crypto.new().generate_random_bytes(4).decode_u32(0)%2147483647),"last_played":0,"legacy":false}
 return item if write_json(ROOT+"/worlds/"+id+".json",item) else {}
func select_world(character: Dictionary, world: Dictionary, creating: bool = false) -> bool:
 if world.get("character") != character.get("id"): return false
 selected_character = character.duplicate(true)
 selected_world = world.duplicate(true)
 new_game = creating
 return true
func touch_world() -> void:
 if selected_world.is_empty(): return
 selected_world.last_played = int(Time.get_unix_time_from_system())
 write_json(ROOT+"/worlds/"+selected_world.id+".json",selected_world)
func import_legacy() -> void:
 var known := {}
 var metadata := DirAccess.open(ROOT+"/worlds")
 if metadata != null:
  for record in metadata.get_files():
   var existing := read_json(ROOT+"/worlds/"+record)
   if existing.has("profile"): known[existing.profile] = true
 var directory := DirAccess.open("user://saves")
 if directory == null: return
 for file in directory.get_files():
  if not file.begins_with("world_") or not file.ends_with(".json"): continue
  var profile := file.trim_prefix("world_").trim_suffix(".json")
  if not safe_id(profile) or profile.length() > 20 or known.has(profile): continue
  var id := "legacy_"+profile
  if FileAccess.file_exists(ROOT+"/worlds/"+id+".json"): continue
  var envelope := read_json("user://saves/"+file,64*1024*1024)
  if envelope.is_empty() or not envelope.get("payload") is String or envelope.get("sha256","") != envelope.payload.sha256_text():
   warn("Старое сохранение повреждено: "+file)
   continue
  var codec = load("res://scripts/save_codec.gd").new()
  var state: Variant = codec.decode(JSON.parse_string(envelope.payload))
  if not state is Dictionary or load("res://scripts/save_schema.gd").validate(state) != "":
   warn("Не удалось прочитать старый мир: "+file)
   continue
  DirAccess.make_dir_recursive_absolute(ROOT+"/backups")
  if DirAccess.copy_absolute("user://saves/"+file,ROOT+"/backups/"+file+".original") != OK: continue
  var character := {"id":id,"name":"Путник · "+profile,"appearance":Appearance.DEFAULT.duplicate()}
  var world := {"id":id,"character":id,"name":"Прежний мир · "+profile,"size":"small" if int(state.world.width)<=512 else "large","profile":profile,"seed":int(state.world.seed),"last_played":FileAccess.get_modified_time("user://saves/"+file),"legacy":true}
  if write_json(ROOT+"/characters/"+id+".json",character): write_json(ROOT+"/worlds/"+id+".json",world)
func load_video() -> void:
 var config := ConfigFile.new()
 if config.load("user://video.cfg") == OK:
  var fps: Variant = config.get_value("video","fps",240)
  if fps in FPS: video.fps = int(fps)
  video.vsync = bool(config.get_value("video","vsync",false))
  video.width = clampi(int(config.get_value("video","width",1280)),640,7680)
  video.height = clampi(int(config.get_value("video","height",720)),360,4320)
 if DisplayServer.get_name() != "headless" and Vector2i(video.width,video.height) not in resolutions():
  var candidates := resolutions()
  var fallback: Vector2i = candidates[mini(candidates.size()-1,2)]
  video.width = fallback.x
  video.height = fallback.y
 get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
 apply_video()
func apply_video() -> void:
 Engine.max_fps = int(video.fps)
 if DisplayServer.get_name() != "headless":
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if video.vsync else DisplayServer.VSYNC_DISABLED)
  DisplayServer.window_set_size(Vector2i(video.width,video.height))
func save_video() -> void:
 var config := ConfigFile.new()
 for key in video: config.set_value("video",key,video[key])
 config.save("user://video.cfg")
func set_fps(value: int, vsync: bool) -> void:
 if value not in FPS: return
 video.fps = value
 video.vsync = vsync
 Engine.max_fps = value
 if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
 save_video()
func resolutions() -> Array[Vector2i]:
 var screen := Vector2i(1920,1080) if DisplayServer.get_name() == "headless" else DisplayServer.screen_get_size()
 var result: Array[Vector2i] = []
 for size in [Vector2i(960,540),Vector2i(1024,576),Vector2i(1280,720),Vector2i(1366,768),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]:
  if size.x <= screen.x and size.y <= screen.y: result.append(size)
 if result.is_empty(): result.append(Vector2i(640,360))
 return result
func preview_resolution(size: Vector2i) -> void:
 if resolution_pending: cancel_resolution()
 resolution_previous = Vector2i(video.width,video.height)
 resolution_candidate = size
 resolution_pending = true
 if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(size)
func confirm_resolution() -> void:
 if not resolution_pending: return
 video.width = resolution_candidate.x
 video.height = resolution_candidate.y
 resolution_pending = false
 save_video()
func cancel_resolution() -> void:
 if not resolution_pending: return
 if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution_previous)
 resolution_pending = false
