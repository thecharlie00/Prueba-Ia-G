extends SceneTree
## Diseñador de interfaz del editor de juegos: modelo (UiLayout), vista en modo diseño y en
## modo juego (UiLayoutView) y su uso desde el editor (añadir, editar, guardar, cargar, probar).

const SAVE_PATH := "user://test_interfaz.json"
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_model()
	await _view()
	await _editor()
	if _failed:
		quit(1)
	else:
		print("ui_designer: ok")
		quit(0)


func _model() -> void:
	var layout := UiLayout.new()
	var text := layout.add("text")
	var counter := layout.add("counter")
	var button := layout.add("button")
	_check(layout.elements.size() == 3 and layout.add("video").is_empty(), "solo se añaden tipos conocidos")
	_check(int(text["anchor"]) == 4, "un elemento en el centro se sujeta al centro")
	# Arrastrado a una esquina, se sujeta a esa esquina y no se sale de la pantalla.
	button["pos"] = Vector2(5000, 5000)
	layout.reanchor(button)
	_check(int(button["anchor"]) == 8, "cerca de la esquina inferior derecha se sujeta a ella")
	_check((button["pos"] as Vector2) + (button["size"] as Vector2) == UiLayout.REFERENCE, "no se sale de la pantalla")
	# En una ventana más ancha sigue pegado a su esquina y no se deforma.
	var wide := UiLayout.rect_on(button, Vector2(2560, 720))
	_check(is_equal_approx(wide.end.x, 2560.0) and wide.size == button["size"], "en panorámico sigue en su esquina: %s" % wide)
	var double := UiLayout.rect_on(button, Vector2(2560, 1440))
	_check(double.size == (button["size"] as Vector2) * 2.0, "con el doble de ventana mide el doble")
	# Destinos de las acciones.
	_check(layout.targets_for("add", int(button["id"])).size() == 1, "sumar solo apunta a contadores")
	_check(layout.targets_for("toggle", int(button["id"])).size() == 2, "mostrar/ocultar apunta a cualquier otro")
	button["action"] = "add"
	button["target"] = int(counter["id"])
	# Guardar y cargar.
	var record: Variant = JSON.parse_string(JSON.stringify(layout.to_record()))
	var copy := UiLayout.from_record(record)
	_check(copy != null and copy.elements.size() == 3, "el diseño sobrevive a JSON")
	_check(copy != null and copy.find(int(button["id"]))["pos"] == button["pos"], "con las posiciones")
	_check(copy != null and int(copy.add("panel")["id"]) > int(button["id"]), "los ids nuevos no chocan")
	for change in [
		["type", "script"], ["image", "user://otra/cosa.png"], ["image", "user://creador/imagenes/../../x.png"],
		["font_size", 900], ["color", "rojo"], ["action", "borrar_todo"], ["target", 999], ["pos", [-50, 0]],
	]:
		var forged: Dictionary = (record as Dictionary).duplicate(true)
		forged["elements"][2][change[0]] = change[1]
		_check(UiLayout.from_record(forged) == null, "se rechaza %s = %s" % change)
	# Al quitar un contador, el botón que lo usaba se queda sin destino.
	layout.remove(int(counter["id"]))
	_check(int(button["target"]) == 0, "quitar el destino limpia la acción")


func _view() -> void:
	var layout := UiLayout.new()
	var counter := layout.add("counter")
	var plus := layout.add("button")
	plus["action"] = "add"
	plus["target"] = int(counter["id"])
	var dice := layout.add("button")
	dice["action"] = "roll"
	dice["target"] = int(counter["id"])
	var panel := layout.add("panel")
	var hide := layout.add("button")
	hide["action"] = "toggle"
	hide["target"] = int(panel["id"])
	var view := UiLayoutView.new()
	root.add_child(view)
	view.size = Vector2(1280, 720)
	# Diseño: se arrastra y se cambia de tamaño; los botones no hacen nada.
	view.show_layout(layout, true)
	await process_frame
	var node := view.node_for(int(plus["id"]))
	_check(node != null and node.size == plus["size"], "cada elemento se dibuja con su tamaño")
	var before: Vector2 = plus["pos"]
	view.begin_drag(int(plus["id"]), Vector2(10, 10), Vector2(600, 300))
	view.drag_to(Vector2(400, 240))
	view.end_drag()
	_check((plus["pos"] as Vector2).is_equal_approx(before + Vector2(-200, -60)), "arrastrar mueve el elemento")
	_check(view.selected_id == int(plus["id"]), "y lo deja seleccionado")
	var size_before: Vector2 = plus["size"]
	view.begin_drag(int(plus["id"]), size_before - Vector2(4, 4), Vector2(500, 500))
	view.drag_to(Vector2(560, 520))
	view.end_drag()
	_check((plus["size"] as Vector2).is_equal_approx(size_before + Vector2(60, 20)), "tirar de la esquina cambia el tamaño")
	view._run_action(int(plus["id"]))
	_check(view.counter_value(int(counter["id"])) == 0, "en diseño los botones no actúan")
	# Juego: los botones funcionan sobre una copia del estado.
	view.show_layout(layout, false)
	await process_frame
	(view.node_for(int(plus["id"])).get_child(0) as Button).pressed.emit()
	(view.node_for(int(plus["id"])).get_child(0) as Button).pressed.emit()
	_check(view.counter_value(int(counter["id"])) == 2, "el botón suma al contador")
	var shown := view.node_for(int(counter["id"])).find_child("Value", true, false) as Label
	_check(shown != null and shown.text == "2", "y el contador lo enseña")
	(view.node_for(int(counter["id"])).find_child("Minus", true, false) as Button).pressed.emit()
	_check(view.counter_value(int(counter["id"])) == 1, "el contador tiene su propio −")
	view._run_action(int(dice["id"]))
	_check(view.counter_value(int(counter["id"])) in range(1, 7), "el dado deja de 1 a 6")
	view._run_action(int(hide["id"]))
	_check(not view.node_for(int(panel["id"])).visible, "el botón oculta el panel")
	view._run_action(int(hide["id"]))
	_check(view.node_for(int(panel["id"])).visible, "y lo vuelve a mostrar")
	_check(int(counter["value"]) == 0, "probar no cambia el diseño")
	# A media pantalla, el contenido se escala entero (misma proporción que a tamaño completo).
	view.size = Vector2(640, 360)
	await process_frame
	var half := view.node_for(int(plus["id"]))
	_check(half.size.is_equal_approx((plus["size"] as Vector2) * 0.5), "a media pantalla el elemento mide la mitad")
	_check((half.get_child(0) as Control).scale.is_equal_approx(Vector2(0.5, 0.5)), "y su contenido se escala con él")
	view.queue_free()
	await process_frame


func _editor() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".previous"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in 10:
		await process_frame
	var editor := current_scene
	editor.ui_save_path = SAVE_PATH
	_check(editor.find_child("AddUi_button", true, false) != null, "el editor ofrece añadir elementos de interfaz")
	var counter_id: int = editor.add_ui_element("counter")
	var button_id: int = editor.add_ui_element("button")
	_check(editor.ui_layout.elements.size() == 2 and editor.ui_view.selected_id == button_id, "se añaden y quedan seleccionados")
	_check(editor._ui_inspector.visible and not editor._piece_inspector.visible, "aparece el inspector de interfaz")
	editor.set_ui_property("text", "Sumar punto")
	editor.set_ui_property("bg", "58c08f")
	editor.set_ui_property("action", "add")
	var button: Dictionary = editor.ui_layout.find(button_id)
	_check(button["text"] == "Sumar punto" and button["bg"] == "58c08f", "el inspector cambia texto y color")
	_check(int(button["target"]) == counter_id, "al elegir «sumar» apunta al contador que hay")
	_check((editor.ui_view.node_for(button_id).get_child(0) as Button).text == "Sumar punto", "y la pantalla lo refleja")
	_check(editor.save_ui_layout(), "la interfaz se guarda")
	editor.remove_ui_element()
	_check(editor.ui_layout.elements.size() == 1 and not editor._ui_inspector.visible, "se puede quitar un elemento")
	_check(editor.load_ui_layout() and editor.ui_layout.elements.size() == 2, "y se recupera al cargar")
	# Probar: sin paneles del editor y con la interfaz funcionando.
	editor._toggle_mode()
	_check(not editor._docks.visible and editor._resume_button.visible, "al probar se apartan los paneles del editor")
	editor.ui_view._run_action(button_id)
	_check(editor.ui_view.counter_value(counter_id) == 1, "la interfaz diseñada funciona al probar")
	editor._toggle_mode()
	_check(editor._docks.visible and editor.ui_view.design and editor.ui_view.counter_value(counter_id) == 0, "al volver a editar, todo como estaba")
	editor._back_to_menu()
	for i in 5:
		await process_frame
	for path in [SAVE_PATH, SAVE_PATH + ".previous"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
