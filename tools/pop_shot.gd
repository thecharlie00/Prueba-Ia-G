extends SceneTree
## Captura del número del dado justo después de mostrarse. Uso: -- <salida.png>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 40:
		await process_frame
	var dice: Dice3D = current_scene.get_node("Objects/Dice")
	dice._celebrate(5)
	for i in 12:
		await process_frame
	var pop: DicePop = dice._pop
	print("pop visible=%s escala=%s pos=%s" % [pop.visible, pop.scale, pop.position])
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit(0)
