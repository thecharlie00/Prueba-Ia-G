extends SceneTree
## Dadazon y el armario: comprar descuenta fichas, el pedido llega en una caja a la puerta,
## abrirla coloca la decoración (o te pone la ropa), todo se guarda, y se ganan fichas jugando.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	HomePrefs.path = "user://prueba_home_shop.cfg"
	DirAccess.remove_absolute(HomePrefs.path)
	_check(HomePrefs.coins() == HomePrefs.STARTING_COINS, "se empieza con %d fichas" % HomePrefs.STARTING_COINS)
	_check(HomePrefs.owns("gorro") and HomePrefs.owns("gafas"), "gorro y gafas vienen de serie")
	for id in ShopCatalog.ITEMS:
		_check(ResourceLoader.exists(ShopCatalog.thumb_path(id)), "Dadazon tiene foto de «%s»" % id)
		if ShopCatalog.kind(id) == ShopCatalog.DECOR:
			_check(DecorItems.SLOTS.has(id), "«%s» tiene sitio en la habitación" % id)

	var home := await _open_home()
	home.open_shop()
	await _frames(2)
	_check(home.shop.visible and not home.pawn.input_enabled, "el ordenador abre la tienda y para al peón")
	_check(home.shop.find_child("Product_sofa", true, false) != null, "la tienda enseña el sofá")
	_check(not home.shop.buy_item("trofeo") or HomePrefs.coins() >= 0, "comprar no deja fichas negativas")
	DirAccess.remove_absolute(HomePrefs.path)
	_check(not HomePrefs.buy("botito", 240), "sin fichas suficientes no se compra")
	_check(home.shop.buy_item("cactus"), "se compra el cactus")
	_check(HomePrefs.coins() == HomePrefs.STARTING_COINS - 40, "el cactus cuesta 40 fichas")
	_check(not HomePrefs.buy("cactus", 40), "no se compra dos veces")
	_check(home.shop.buy_item("cono"), "se compra el gorro de fiesta")
	home.shop.close_shop()
	await _frames(4)
	_check(home.pawn.input_enabled, "al cerrar la tienda el peón vuelve a andar")
	var parcels := home.items.filter(func(i: Interactable) -> bool: return i.id == "paquete")
	_check(parcels.size() == 2, "llegan dos paquetes a la puerta (llegan %d)" % parcels.size())

	# Los paquetes siguen ahí si sales sin abrirlos.
	home = await _open_home()
	parcels = home.items.filter(func(i: Interactable) -> bool: return i.id == "paquete")
	_check(parcels.size() == 2, "los paquetes sin abrir se guardan")
	for parcel in parcels:
		parcel.use()
		await _frames(2)
	_check(HomePrefs.deliveries().is_empty(), "abiertos, no quedan pedidos")
	_check(HomePrefs.placed_decor().has("cactus"), "el cactus queda puesto")
	_check(home.find_child("Decor_cactus", true, false) != null, "el cactus aparece en la habitación")
	_check(HomePrefs.hat() == "cono", "el gorro nuevo se estrena al abrirlo")
	_check(home.pawn.meeple.get_node("Head/WearHat").get_child_count() > 0, "el peón lleva el gorro puesto")

	# La decoración sigue al volver a entrar.
	home = await _open_home()
	_check(home.find_child("Decor_cactus", true, false) != null, "la decoración se guarda")

	# Armario: color y complemento; lo que no tienes está bloqueado.
	home.open_wardrobe()
	await _frames(2)
	_check(home.wardrobe.visible, "el armario se abre")
	var locked := home.wardrobe.find_child("Wear_corona", true, false) as Button
	_check(locked != null and locked.disabled, "la corona sin comprar sale bloqueada")
	(home.wardrobe.find_child("Wear_gafas", true, false) as Button).pressed.emit()
	(home.wardrobe.find_child("Color2", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(HomePrefs.accessory() == "gafas" and HomePrefs.color_index() == 2, "el armario cambia complemento y color")
	home.wardrobe.close_wardrobe()

	# Caída animada desde el cielo: la caja aterriza y entonces se puede abrir.
	Home.force_drop_animation = true
	var falling := home.items.size()
	home.call("_spawn_parcel", "bigote", true, 0.0)
	_check(home.items.size() == falling, "mientras cae, la caja aún no se puede abrir")
	await create_timer(3.4).timeout
	_check(home.items.size() == falling + 1, "al aterrizar, la caja se puede abrir")
	await create_timer(2.0).timeout
	_check(home.find_child("Parachute", true, false) == null, "el paracaídas se va y desaparece")
	Home.force_drop_animation = false

	# Fichas por jugar: al menos un minuto, con tope.
	var nav := root.get_node("SessionNavigation")
	var before := HomePrefs.coins()
	_check(nav.award_play_time(30_000) == 0, "menos de un minuto no da fichas")
	_check(nav.award_play_time(180_000) == 15, "tres minutos dan 15 fichas")
	_check(nav.award_play_time(3_600_000) == nav.MAX_COINS_PER_GAME, "hay un tope por partida")
	_check(HomePrefs.coins() == before + 15 + nav.MAX_COINS_PER_GAME, "las fichas se suman")
	nav.last_reward = 0

	DirAccess.remove_absolute(HomePrefs.path)
	HomePrefs.path = HomePrefs.DEFAULT_PATH
	if _failed:
		quit(1)
	else:
		print("home_shop: ok")
		quit(0)


func _open_home() -> Home:
	change_scene_to_file("res://scenes/Home.tscn")
	await _frames(8)
	return current_scene as Home


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
