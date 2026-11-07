extends SceneTree
## Captura del menú en edición demo. Uso: xvfb-run godot --path . --script res://tools/demo_menu_shot.gd -- salida.png


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	root.get_node("Edition").demo = true
	root.get_node("Edition").notice = "Esa mesa está en el juego completo. La demo incluye la mesa libre, la brisca y el parchís."
	change_scene_to_file("res://scenes/Menu.tscn")
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
