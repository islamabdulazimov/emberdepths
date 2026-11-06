extends "res://tests/altar_smoke.gd"
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);freeze(main)
 for size in ["small","large"]:
  for seed_value in [1,72419,918273]:
   main.world.configure_new(size);main.world.world_seed=seed_value;main.world.generate()
   main.encounter.journal.apply({});var before:Dictionary=main.world.changes.duplicate(true)
   main.encounter.ensure_altar();var at:Vector2=main.encounter.journal.altar;var cell:Vector2i=main.world.cell_at(at)
   check(at!=Vector2.ZERO and main.world.character_fits(at+Vector2(0,-10)) and main.world.block_at(cell)>=0,"supported accessible altar %s seed %d"%[size,seed_value])
   check(cell.y<=main.world.heights[cell.x]+3 and absi(cell.x-main.world.world_width/2)>=20,"surface altar outside immediate spawn %s %d"%[size,seed_value])
   var intersects:=false
   for site in main.world.sites:
    if site.rect.has_point(cell):intersects=true
   check(not intersects and before==main.world.changes,"altar preserves structures and terrain %s %d"%[size,seed_value])
   main.player.position=at+Vector2(-32,-10)
   check(main.encounter._find_spawn([main.player],main.encounter.arena_bounds())!=null or main.encounter._find_spawn_positions([at+Vector2(32,-10)],main.encounter.arena_bounds())!=null,"boss can appear near natural altar %s %d"%[size,seed_value])
 main.queue_free();await process_frame;print("ALTAR_WORLDS_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
