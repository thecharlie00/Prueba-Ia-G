extends SceneTree
## Verifica la intro: arranca el juego, cualquier botón salta la animación, en el título
## entra en la habitación (o en el menú clásico) y los textos están traducidos.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Intro.tscn", "la intro es la escena de inicio")
	HomePrefs.path = "user://prueba_intro.cfg"
	DirAccess.remove_absolute(HomePrefs.path)
	HomePrefs.set_classic_menu(false)

	change_scene_to_file("res://scenes/Intro.tscn")
	for i in 3:
		await process_frame
	var intro := current_scene
	_check(intro != null and intro.scene_file_path == "res://scenes/Intro.tscn", "la intro carga")
	_check(not intro.call("is_title_shown"), "empieza con la animación")
	_check(intro.call("destination") == "res://scenes/Home.tscn", "lleva a la habitación")

	# Una tecla durante la animación salta al título, sin salir de la intro.
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key)
	await process_frame
	_check(intro.call("is_title_shown"), "una tecla salta la animación")
	_check(current_scene == intro, "saltar no sale de la intro")

	# Las pulsaciones repetidas del teclado (eco) y el movimiento del ratón no cuentan.
	var echo := InputEventKey.new()
	echo.keycode = KEY_A
	echo.pressed = true
	echo.echo = true
	var motion := InputEventMouseMotion.new()
	_check(not intro.call("_is_press", echo), "el eco de una tecla no cuenta")
	_check(not intro.call("_is_press", motion), "mover el ratón no cuenta")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	_check(intro.call("_is_press", pad), "un botón del mando cuenta")

	# En el título, un botón entra en el juego.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(10, 10)
	root.push_input(click)
	for i in 6:
		await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/Home.tscn", "en el título, un clic entra en la habitación")

	# Con el menú clásico elegido, la intro lleva al menú.
	HomePrefs.set_classic_menu(true)
	_check(load("res://scripts/ui/Intro.gd").destination() == "res://scenes/BotMenu.tscn", "con menú clásico lleva al menú")
	HomePrefs.set_classic_menu(false)
	DirAccess.remove_absolute(HomePrefs.path)

	TranslationServer.set_locale("en")
	_check(TranslationServer.translate("Pulsa cualquier botón para empezar") == "Press any button to start", "aviso del título traducido")
	TranslationServer.set_locale("es")

	if _failures > 0:
		push_error("intro_screen: %d fallos" % _failures)
		quit(1)
	else:
		print("intro_screen: OK")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		printerr("  FALLO  ", label)
