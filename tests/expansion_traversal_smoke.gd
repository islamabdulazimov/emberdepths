extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.set_physics_process(false)
 main.combat.set_physics_process(false)
 main.items.set_physics_process(false)
 main.interaction.set_process(false)
 main.exploration.set_process(false)
 main.encounter.enabled = false
 for seed_value in [72419,12,90551]:
  main.world.configure_expanded()
  main.world.world_seed = seed_value
  main.world.generate()
  main.world.solid.update_internals()
  var x0 := 88+posmod(seed_value,3)
  var y0: int = main.world.heights[x0]
  var floor_y: int = main.world.sites[0].rect.end.y-2
  var last_x := x0+(floor_y-y0)*2
  # The short cave/step junction removes two stair treads. Test the actual
  # existing jump returning uphill, rather than assuming tile clearance is enough.
  var gap_x := last_x-4
  main.player.position = Vector2((gap_x+1)*16+8,floor_y*16-10)
  main.player.velocity = Vector2.ZERO
  main.player.move_command = 0
  main.player.reset_physics_interpolation()
  for i in range(3): await physics_frame
  main.player.submit_command(-1,true)
  for i in range(40): await physics_frame
  main.player.submit_command(0,false)
  var ok: bool = main.player.position.x < gap_x*16 and main.player.position.y <= (floor_y-2)*16-9
  print("PASS: Original jump climbs the junction for seed ",seed_value)
  if not ok:
   push_error("Junction cannot be climbed with the original jump")
   quit(1)
   return
 main.queue_free()
 await process_frame
 quit()
