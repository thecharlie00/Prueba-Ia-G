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
	dice._awaiting_result = true
	dice._celebrate(dice.top_face())
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit(0)
