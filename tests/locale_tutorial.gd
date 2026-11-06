extends SceneTree
## Idiomas (inglés y catalán) y tutorial jugable de la mesa libre.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Traducciones completas, sin claves repetidas y con los mismos huecos de formato.
	var keys := {}
	for row in UiStrings.ROWS:
		_check(row.size() == 3 and not row[1].is_empty() and not row[2].is_empty(), "fila completa: %s" % row[0])
		_check(not keys.has(row[0]), "clave repetida: %s" % row[0])
		keys[row[0]] = true
		for column in [1, 2]:
			for hole in ["%d", "%s"]:
				_check(row[0].count(hole) == row[column].count(hole), "huecos %s iguales en: %s" % [hole, row[0]])
	var locale := root.get_node_or_null("Locale")
	_check(locale != null, "el idioma es un autoload")
	if locale != null:
		_check(locale.language == "es", "en pruebas el idioma por defecto es español")
		locale.set_language("en", false)
		_check(TranslationServer.translate("Rebobinar") == "Rewind", "inglés: Rebobinar -> Rewind")
		locale.set_language("ca", false)
		_check(TranslationServer.translate("Guardar mesa") == "Desa la taula", "catalán: Guardar mesa")
		_check(TranslationServer.translate("Asiento %s") % "2" == "Seient 2", "las plantillas se traducen")
		var selector: OptionButton = locale.make_selector()
		_check(selector.item_count == 3 and selector.selected == 2, "el selector muestra los tres idiomas")
		selector.free()
		locale.set_language("es", false)
		_check(TranslationServer.translate("Rebobinar") == "Rebobinar", "vuelta al español")

	# Tutorial: cada paso se completa haciéndolo.
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	_check(main.get_node_or_null("Tutorial") == null, "en pruebas el tutorial no arranca solo")
	var tutorial := Tutorial.start(main)
	await process_frame
	_check(tutorial.current_id() == "grab", "el tutorial empieza por agarrar")
	main.grabber.grab_started.emit(main.get_node("Objects/Dice"))
	await create_timer(1.0).timeout
	_check(tutorial.current_id() == "orbit", "agarrar una pieza completa el primer paso")
	var rig: TabletopCamera3D = main.get_node("TabletopCamera3D")
	rig._yaw += 1.0
	await create_timer(1.0).timeout
	_check(tutorial.current_id() == "zoom", "orbitar completa el segundo paso")
	tutorial.next_step()
	_check(tutorial.current_id() == "roll", "Saltar paso avanza")
	var card := tutorial.get_node("TutorialCard") as PanelContainer
	_check(card != null and card.visible, "la tarjeta del tutorial está a la vista")
	tutorial.finish()
	await process_frame
	_check(not is_instance_valid(tutorial), "Cerrar quita el tutorial")
	_check(Tutorial.was_seen(), "el tutorial queda marcado como visto")

	if _failed:
		quit(1)
	else:
		print("locale_tutorial: ok")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
