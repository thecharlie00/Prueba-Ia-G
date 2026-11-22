extends SceneTree
## La habitación jugable: el peón anda y choca, cada mueble abre lo que debe, la demo
## bloquea salas y taller, el espejo y el tocadiscos funcionan, y Tab/Esc son atajos.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Intro.tscn", "el juego arranca en la intro")
	HomePrefs.path = "user://prueba_home_room.cfg"
	DirAccess.remove_absolute(HomePrefs.path)
	HomePrefs.set_classic_menu(false)
	var home := await _open_home()
	_check(home.items.size() == 10, "la habitación tiene 10 objetos (tiene %d)" % home.items.size())
	_check(home.find_nearest() != null and home.find_nearest().id == "mesa", "al empezar, la mesa con los bots está al alcance")
	var prompt := home.find_child("Prompt", true, false) as Button
	_check(prompt != null and prompt.visible, "se ve la etiqueta para usar la mesa")

	# Andar: el peón se mueve con un destino y no atraviesa la pared.
	var start := home.pawn.position
	home.pawn.walk_to(Vector3(-5, 0, 4.5))
	await _physics(60)
	_check(home.pawn.position.distance_to(start) > 2.0, "el peón anda hacia el destino")
	home.pawn.walk_to(Vector3(-20, 0, 2))
	await _physics(150)
	_check(home.pawn.position.x > -9.0, "las paredes paran al peón (x=%.2f)" % home.pawn.position.x)

	# Cada objeto: se llega andando por clic y queda al alcance.
	for item in home.items:
		home.pawn.position = item.approach + Vector3(0, 0.05, 0)
		await _physics(4)
		var near := home.find_nearest()
		_check(near == item, "desde su sitio se alcanza «%s» (se alcanza «%s»)" % [item.id, near.id if near else "nada"])

	# Armario, ordenador y tocadiscos no cambian de escena.
	_item(home, "armario").use()
	await _frames(2)
	_check(home.wardrobe.visible and not home.pawn.input_enabled, "el armario abre el panel del peón")
	home.wardrobe.close_wardrobe()
	_item(home, "ordenador").use()
	await _frames(2)
	_check(home.shop.visible, "el ordenador abre Dadazon")
	home.shop.close_shop()
	var sfx := root.get_node("Sfx")
	var sound_before: bool = sfx.get("enabled") == true
	_item(home, "tocadiscos").use()
	await _frames(2)
	_check((sfx.get("enabled") == true) != sound_before, "el tocadiscos enciende o apaga el sonido")
	sfx.set_enabled(sound_before)
	_item(home, "corcho").use()
	await _frames(2)
	_check(home.settings_panel.visible and not home.pawn.input_enabled, "el corcho abre los ajustes y para al peón")
	home.close_settings()

	# Demo: salas y taller bloqueados; la estantería sí abre.
	var edition := root.get_node("Edition")
	var demo_before: bool = edition.get("demo") == true
	edition.set("demo", true)
	home = await _open_home()
	for id in ["puerta", "taller"]:
		var locked := _item(home, id)
		_check(locked.locked, "en la demo «%s» está bloqueado" % id)
		locked.use()
		await _frames(3)
		_check(current_scene == home, "en la demo «%s» no sale de la habitación" % id)
	for id in ["mesa", "estanteria", "pizarra"]:
		_check(not _item(home, id).locked, "en la demo «%s» se abre" % id)
	edition.set("demo", demo_before)

	# Cada objeto que lleva a otra pantalla, y la vuelta.
	for id in ["mesa", "estanteria"]:
		home = await _open_home()
		_item(home, id).use()
		await _frames(8)
		_check(current_scene.scene_file_path == Home.SCENES[id], "«%s» abre %s" % [id, Home.SCENES[id].get_file()])
		var nav := root.get_node("SessionNavigation")
		_check(nav.back_target("res://scenes/ModeSelect.tscn") == "res://scenes/Home.tscn", "desde «%s», Volver lleva a la habitación" % id)

	# Atajos: Tab abre el menú clásico.
	home = await _open_home()
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	home._unhandled_input(tab)
	await _frames(8)
	_check(current_scene.scene_file_path == Home.CLASSIC_PATH, "Tab abre el menú clásico")

	# Preferencia de menú clásico.
	HomePrefs.set_classic_menu(true)
	_check(root.get_node("SessionNavigation").home_scene() == "res://scenes/BotMenu.tscn", "con menú clásico, el inicio es la portada")
	HomePrefs.set_classic_menu(false)
	_check(root.get_node("SessionNavigation").home_scene() == "res://scenes/Home.tscn", "sin menú clásico, el inicio es la habitación")

	DirAccess.remove_absolute(HomePrefs.path)
	HomePrefs.path = HomePrefs.DEFAULT_PATH
	if _failed:
		quit(1)
	else:
		print("home_room: ok")
		quit(0)


func _open_home() -> Home:
	change_scene_to_file("res://scenes/Home.tscn")
	await _frames(8)
	return current_scene as Home


func _item(home: Home, id: String) -> Interactable:
	for item in home.items:
		if item.id == id:
			return item
	_check(false, "no existe el objeto «%s»" % id)
	return null


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _physics(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
