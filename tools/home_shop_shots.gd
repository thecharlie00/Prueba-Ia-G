extends SceneTree
## Capturas de Dadazon, el armario, los paquetes y la habitación decorada.
## Uso: xvfb-run godot --path . --script res://tools/home_shop_shots.gd -- carpeta


func _initialize() -> void:
	_run.call_deferred()


func _shot(out: String, key: String) -> void:
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(key + ".png"))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shop_shots"
	DirAccess.make_dir_recursive_absolute(out)
	if "--es" in args:
		root.get_node("Locale").set_language("es", false)
	HomePrefs.path = "user://shots_home.cfg"
	DirAccess.remove_absolute(HomePrefs.path)
	HomePrefs.add_coins(400)
	change_scene_to_file("res://scenes/Home.tscn")
	await _shot(out, "_warmup")
	var home := current_scene as Home
	home.open_shop()
	await _shot(out, "tienda")
	home.shop.buy_item("botito")
	home.shop.buy_item("corona")
	home.shop.close_shop()
	home.pawn.position = Vector3(-5.6, 0, 0.6)
	await _shot(out, "paquetes")
	for item in home.items.duplicate():
		if item.id == "paquete":
			item.use()
	await _shot(out, "abiertos")
	# Todo puesto.
	var config := ConfigFile.new()
	config.load(HomePrefs.path)
	config.set_value("home", "placed", DecorItems.SLOTS.keys())
	config.set_value("home", "owned", ShopCatalog.ITEMS.keys())
	config.set_value("home", "accessory", "pajarita")
	config.save(HomePrefs.path)
	change_scene_to_file("res://scenes/Home.tscn")
	await _shot(out, "_warmup2")
	home = current_scene as Home
	home.pawn.position = Vector3(0.5, 0, 4.2)
	await _shot(out, "decorada")
	home.pawn.position = Vector3(7.0, 0, -4.3)
	home.open_wardrobe()
	await _shot(out, "armario")
	DirAccess.remove_absolute(HomePrefs.path)
	quit(0)
