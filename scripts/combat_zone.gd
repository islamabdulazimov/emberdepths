extends Node2D
var bounds := Rect2i()
var preset := Rect2i()
var active := false
var main: Node2D
func _ready() -> void:
 main = get_parent()
 z_index = 5
func lock(at: Vector2, players: Array) -> void:
 bounds = preset
 if not bounds.has_area():
  var center: Vector2i = main.world.cell_at(at)
  # A local arena must never stretch across the world to a distant teammate.
  var first := maxi(0,center.x-12)
  var last := mini(main.world.world_width,center.x+13)
  var top := maxi(0,center.y-10)
  bounds = Rect2i(Vector2i(first,top),Vector2i(last-first,mini(16,main.world.world_depth-top)))
 active = true
 queue_redraw()
func unlock() -> void:
 active = false
 queue_redraw()
func blocks_edit(cell: Vector2i) -> bool: return active and bounds.has_point(cell)
func contains_body(body: CharacterBody2D) -> bool: return bounds.has_point(main.world.cell_at(body.position))
func snapshot() -> Dictionary: return {"bounds":bounds,"active":active}
func apply(data: Dictionary) -> void:
 bounds = data.get("bounds",Rect2i())
 active = data.get("active",false)
 queue_redraw()
func _draw() -> void:
 if not active: return
 var area := Rect2(Vector2(bounds.position)*16,Vector2(bounds.size)*16)
 draw_rect(area,Color(0.95,0.6,0.37,0.08))
 draw_rect(area,Color("bd8058"),false,1)
 for corner in [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]:
  draw_rect(Rect2(corner-Vector2(2,2),Vector2(4,4)),Color("e1dec2"))
 if main.has_meta("combat_test") or (is_instance_valid(main.altar) and main.encounter.journal.last.get("status","")=="active"): return # Fixed HUD legend avoids overlap with top player resources.
 draw_string_outline(ThemeDB.fallback_font,area.position+Vector2(5,12),"Арена · во время боя нельзя менять блоки",HORIZONTAL_ALIGNMENT_LEFT,-1,8,2,Color("18252e"))
 draw_string(ThemeDB.fallback_font,area.position+Vector2(5,12),"Арена · во время боя нельзя менять блоки",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("e1dec2"))
