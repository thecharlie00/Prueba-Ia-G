extends SceneTree
## Abre una escena, espera unos fotogramas y guarda una captura PNG.
## Necesita un renderizador real (no --headless); en Linux sin pantalla se puede usar xvfb-run.
## Uso:
##   godot --path . --resolution 1280x720 --script res://tools/screenshot.gd -- res://scenes/Main.tscn salida.png [fotogramas]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Uso: -- <escena.tscn> <salida.png> [fotogramas]")
		quit(2)
		return
	var frames := int(args[2]) if args.size() > 2 else 90
	var packed: PackedScene = load(args[0])
	if packed == null:
		push_error("No se pudo cargar %s" % args[0])
		quit(1)
		return
	root.add_child(packed.instantiate())
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(args[1])
	quit(0 if error == OK else 1)
