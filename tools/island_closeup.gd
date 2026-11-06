extends SceneTree
## Captura de cerca de la isla con algunas piezas colocadas, para revisar el arte.
## Uso: godot --path . --resolution 1280x720 --script res://tools/island_closeup.gd -- salida.png


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var view: IslandView = (load("res://scenes/Island.tscn") as PackedScene).instantiate()
	root.add_child(view)
	for i in 30:
		await process_frame
	var base := view._vertex_position(10)
	var colors := view.PLAYER_COLORS
	var a := view._spawn_piece("settlement", colors[0], base + Vector3(0, 0.12, 0))
	var b := view._spawn_piece("city", colors[1], view._vertex_position(14) + Vector3(0, 0.15, 0))
	var c := view._spawn_piece("road", colors[2], view._edge_position(16) + Vector3(0, 0.1, 0))
	var d := view._spawn_piece("city", colors[3], view._vertex_position(20) + Vector3(0, 0.15, 0))
	var e := view._spawn_piece("settlement", colors[2], view._vertex_position(24) + Vector3(0, 0.12, 0))
	for i in 90:
		await process_frame
	var camera := Camera3D.new()
	view.add_child(camera)
	var target := view._vertex_position(14)
	camera.global_position = target + Vector3(0.35, 0.45, 0.7)
	camera.look_at(target)
	camera.make_current()
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
