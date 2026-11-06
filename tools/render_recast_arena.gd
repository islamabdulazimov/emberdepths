extends SceneTree
var main:Node2D
func _initialize() -> void:call_deferred("run")
func shot(name:String) -> void:
 main._process(0);main.sky._process(1.0/30)
 await create_timer(.15).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/"+name+".png")
func run() -> void:
 main=load("res://scenes/combat_arena.tscn").instantiate();root.add_child(main)
 main.spawn_practice_boss();main.set_physics_process(false);main.combat.set_physics_process(false);main.player.set_physics_process(false);main.items.set_physics_process(false);main.exploration.set_process(false);main.interaction.set_process(false)
 main.player.equipment={"weapon":"wood_sword","head":"wood_helm","body":"wood_armor","legs":"wood_legs","shield":"wood_shield"};main.items.local_inventory().load_data([])
 var boss=main.encounter.actor;boss.set_physics_process(false);boss.set_process(false)
 boss.phase="intro";boss.phase_elapsed=1.1;boss.phase_duration=2.2;boss._process(0)
 main.combat.world_time=80;main.boss_ui.refresh();main.interaction._process(0);main.fps_label.hide()
 await shot("recast-andrew-in-game")
 main.combat.world_time=165
 await shot("recast-andrew-lighting")
 boss.phase="super_flight";boss.phase_elapsed=.4;boss.phase_duration=1;boss.locked_target=main.player.position+Vector2(0,10);boss.indicator_active=true;boss._process(0)
 await shot("recast-andrew-warning")
 print("RECAST_ARENA_RENDER_OK")
 main.queue_free();await process_frame;quit()
