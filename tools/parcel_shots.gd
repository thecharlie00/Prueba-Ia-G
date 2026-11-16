extends SceneTree
## Secuencia de capturas de un pedido de Dadazon cayendo del cielo.
## Uso: xvfb-run godot --path . --script res://tools/parcel_shots.gd -- carpeta


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://parcel_shots"
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("Locale").set_language("es", false)
	HomePrefs.path = "user://shots_parcel.cfg"
	DirAccess.remove_absolute(HomePrefs.path)
	change_scene_to_file("res://scenes/Home.tscn")
	for i in 30:
		await process_frame
	var home := current_scene as Home
	home.pawn.position = Vector3(-3.6, 0, 1.6)
	home.pawn.rotation.y = -PI / 2.0
	home.open_shop()
	home.shop.buy_item("cactus")
	home.shop.close_shop()
	while home.get("_parcels").is_empty():
		await process_frame
	var elapsed := 0.0
	for at in [0.35, 0.75, 1.1, 1.9, 2.45, 2.62, 2.85, 3.3, 4.0]:
		# Tiempo de juego (no real): con render por software van pocos fotogramas por segundo.
		await create_timer(at - elapsed).timeout
		elapsed = at
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join("caida_%04d.png" % int(at * 100)))
	DirAccess.remove_absolute(HomePrefs.path)
	quit(0)
