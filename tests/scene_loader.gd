extends SceneTree
## Verifica SceneLoader: carga en hilo aparte, cambio directo en headless, reinicio de escena
## y que la pantalla de carga está montada y traducida.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loader: Node = root.get_node("SceneLoader")
	_check(loader != null, "autoload SceneLoader")
	_check(not loader.call("_wants_screen"), "en headless no se muestra la pantalla")

	# Carga en hilo aparte (la ruta que se usa con ventana).
	var packed: PackedScene = await loader.call("_load", "res://scenes/Credits.tscn")
	_check(packed != null, "carga en segundo plano devuelve la escena")
	var cached: PackedScene = await loader.call("_load", "res://scenes/Credits.tscn")
	_check(cached == packed, "una escena ya cargada sale de la caché")

	# En headless go() cambia de escena directamente, como antes.
	loader.call("go", "res://scenes/Credits.tscn")
	for i in 4:
		await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/Credits.tscn", "go() cambia de escena")
	var before := current_scene
	loader.call("reload")
	for i in 4:
		await process_frame
	_check(current_scene != before and current_scene.scene_file_path == "res://scenes/Credits.tscn", "reload() reinicia la escena")
	_check(not loader.get("busy"), "no queda ocupado")

	# Pantalla montada y oculta.
	_check(not loader.get("visible"), "la pantalla empieza oculta")
	var screen := loader.get_node_or_null("LoadingScreen") as Control
	_check(screen != null and screen.mouse_filter == Control.MOUSE_FILTER_STOP, "la pantalla bloquea el ratón")
	for face in range(1, 7):
		var pips: Array = loader.call("_pips", face)
		_check(pips.size() == face, "el dado tiene %d puntos en la cara %d" % [face, face])

	# Textos traducidos.
	TranslationServer.set_locale("en")
	_check(TranslationServer.translate("Cargando…") == "Loading…", "«Cargando…» traducido")
	for tip in loader.get("TIPS"):
		_check(TranslationServer.translate(str(tip)) != str(tip), "consejo traducido: %s" % tip)
	TranslationServer.set_locale("es")

	if _failures > 0:
		push_error("scene_loader: %d fallos" % _failures)
		quit(1)
	else:
		print("scene_loader: OK")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		printerr("  FALLO  ", label)
