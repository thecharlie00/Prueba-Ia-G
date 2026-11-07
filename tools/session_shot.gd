extends SceneTree
## Abre la mesa libre como escena actual (con los botones de sesión), tira un dado y captura
## justo cuando salta el número. Uso: -- <salida.png>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 40:
		await process_frame
	var dice: Dice3D = current_scene.get_node("Objects/Dice")
	var meter := root.get_node_or_null("PerfMeter")
	if meter != null and OS.get_cmdline_user_args().size() > 1:
		meter.get_node("PerfPanel").visible = true
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	dice.roll()
	while dice._awaiting_result:
		await process_frame
	for i in 3:
		await process_frame
	if meter != null:
		meter._refresh()
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit(0)
