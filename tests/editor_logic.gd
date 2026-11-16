extends SceneTree
## Lógica visual (blueprints) del editor de juegos: bloques, cables con tipos, guardado,
## ejecución al probar (eventos, flujo, acciones, datos), bloques GDScript aislados y el
## editor de bloques con deshacer.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# 1. El aislamiento de los bloques GDScript.
	_check(GdSandbox.check("var total = 0\nfor p in mesa.piezas():\n\ttotal += 1\nreturn total") == "", "un bloque normal se acepta")
	_check(GdSandbox.check("return a * 2 + b") == "", "un cálculo se acepta")
	_check(GdSandbox.check("var t = \"OS.execute\"\nreturn t.to_upper()") == "", "un texto que menciona OS no molesta")
	for bad in ["OS.execute(\"rm\", [])", "var f = FileAccess.open(\"x\", 1)", "load(\"res://x.gd\")", "mesa.get_tree()",
			"while true:\n\tpass", "func f():\n\tpass", "$Nodo", "mesa.call(\"x\")", "self.queue_free()", "preload(\"x\")",
			"Engine.get_main_loop()", "mesa._editor()", "await mesa", "ClassDB.instantiate(\"Node\")", "range(1000000000)"]:
		_check(GdSandbox.check(bad) != "", "se rechaza: %s" % bad)
	_check(GdSandbox.check("return \"sin cerrar").contains("comillas"), "avisa de comillas sin cerrar")
	var compiled := GdSandbox.compile("    var x = a + b\n    return x * 10")
	_check(compiled.has("script"), "compila con sangría de espacios")
	if compiled.has("script"):
		var instance: Object = (compiled["script"] as GDScript).new()
		_check(int(instance.call("ejecutar", null, 2, 3)) == 50, "y calcula (2 + 3) × 10")
	# (Un error de escritura real se explica al probar; aquí no se compila para no ensuciar el registro.)

	# 2. El grafo: cables con tipos, guardar y cargar, datos malos.
	var graph := LogicGraph.new()
	var start := graph.add_node("ev_inicio")
	var message := graph.add_node("ac_mensaje")
	var number := graph.add_node("da_numero")
	_check(graph.connect_ports(start, "out", message, "in"), "se une un evento con una acción")
	_check(not graph.connect_ports(number, "valor", message, "in"), "un número no entra por una entrada de flujo")
	_check(graph.connect_ports(number, "valor", message, "texto"), "un número sí entra en un texto")
	var copy := LogicGraph.from_record(JSON.parse_string(JSON.stringify(graph.to_record())))
	_check(copy != null and copy.nodes.size() == 3 and copy.links.size() == 2, "el grafo se guarda y se carga")
	_check(LogicGraph.from_record({"nodes": [{"id": 1, "type": "borrar_disco", "pos": [0, 0]}], "links": []}) == null, "un bloque desconocido se rechaza")
	_check(LogicGraph.from_record({"nodes": [{"id": 1, "type": "ev_inicio", "pos": [0, 0]}], "links": [[1, "out", 9, "in"]]}) == null, "un cable a ninguna parte se rechaza")
	_check(LogicGraph.from_record({"nodes": [{"id": 1, "type": "gd_bloque", "pos": [0, 0], "params": {"codigo": "x".repeat(5000)}}], "links": []}) == null, "un código enorme se rechaza")
	graph.remove_node(message)
	_check(graph.links.is_empty(), "al quitar un bloque se van sus cables")

	# 3. Al probar: la plantilla de cartas mezcla y reparte 5; la tecla 1 roba otra.
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in 10:
		await process_frame
	var editor := current_scene
	editor.load_template("cartas")
	_check(editor.logic.nodes.size() == 6, "la plantilla de cartas trae su lógica")
	editor._toggle_mode()
	await physics_frame
	_check(editor.logic_pieces("zona_mano", "").size() == 5, "al empezar se reparten 5 cartas a la mano")
	_check(editor.last_message.contains("1"), "y sale el mensaje de la plantilla")
	_key(editor, KEY_1)
	_check(editor.logic_pieces("zona_mano", "").size() == 6, "la tecla 1 roba otra carta")
	_check(editor.logic_pieces("MAZO", "").size() == 14, "y el mazo (buscado por su texto) tiene 14")
	editor._toggle_mode()
	_check(editor._logic_runner == null, "al volver a editar, la lógica se para")

	# 4. Botón de la interfaz → repetir 3 veces → sumar 2 a un contador.
	editor.clear_table()
	editor.logic = LogicGraph.new()
	var counter: int = editor.add_ui_element("counter")
	var button: int = editor.add_ui_element("button")
	var g: LogicGraph = editor.logic
	var on_button := g.add_node("ev_boton")
	g.nodes[on_button]["params"]["boton"] = button
	var repeat := g.add_node("fl_repetir")
	g.nodes[repeat]["params"]["veces"] = 3
	var add := g.add_node("ac_sumar")
	g.nodes[add]["params"]["contador"] = counter
	g.nodes[add]["params"]["cantidad"] = 2
	g.connect_ports(on_button, "out", repeat, "in")
	g.connect_ports(repeat, "cuerpo", add, "in")
	editor._toggle_mode()
	editor.ui_view._run_action(button)
	_check(editor.ui_view.counter_value(counter) == 6, "un botón suma 2 tres veces al contador (%d)" % editor.ui_view.counter_value(counter))
	editor._toggle_mode()

	# 5. Bloque GDScript con «mesa»: escribe en todas las piezas; un bucle enorme se corta.
	editor.logic = LogicGraph.new()
	g = editor.logic
	for i in 3:
		editor.add_piece("ficha")
	var begin := g.add_node("ev_inicio")
	var code := g.add_node("gd_bloque")
	g.nodes[code]["params"]["codigo"] = "var n = 0\nfor p in mesa.piezas():\n\tn += 1\n\tmesa.escribir(p, str(n))\nmesa.guardar(\"hechas\", n)\nreturn n"
	var show := g.add_node("ac_mensaje")
	var join := g.add_node("da_unir")
	g.nodes[join]["params"]["a"] = "Numeradas: "
	g.connect_ports(begin, "out", code, "in")
	g.connect_ports(code, "out", show, "in")
	g.connect_ports(code, "resultado", join, "b")
	g.connect_ports(join, "valor", show, "texto")
	editor._toggle_mode()
	var labels: Array = editor.logic_pieces("", "").map(func(id: String) -> String: return editor.logic_piece_label(id))
	labels.sort()
	_check(labels == ["1", "2", "3"], "el bloque GDScript escribe en las piezas: %s" % [labels])
	_check(editor.logic_variable("hechas") == 3, "guarda una variable")
	_check(editor.last_message == "Numeradas: 3", "y su resultado llega por cable al mensaje: %s" % editor.last_message)
	editor._toggle_mode()
	g.nodes[code]["params"]["codigo"] = "var n = 0\nfor i in mesa.rango(100000000):\n\tn += 1\nreturn n"
	editor._toggle_mode()
	_check(editor.last_message.begins_with("Numeradas: ") and int(editor.last_message.get_slice(": ", 1)) <= LogicHost.LOOP_BUDGET, "un bucle enorme se corta en el límite")
	editor._toggle_mode()
	g.nodes[code]["params"]["codigo"] = "OS.shell_open(\"https://example.com\")"
	editor._toggle_mode()
	_check(editor._logic_runner.errors.has(code) and editor.last_message.contains("OS"), "un bloque peligroso no se ejecuta y se avisa")
	editor._toggle_mode()

	# 6. Un círculo de flujo no cuelga: se para al límite de pasos.
	editor.logic = LogicGraph.new()
	g = editor.logic
	var loop_start := g.add_node("ev_inicio")
	var first := g.add_node("ac_variable")
	var second := g.add_node("ac_variable")
	g.connect_ports(loop_start, "out", first, "in")
	g.connect_ports(first, "out", second, "in")
	g.connect_ports(second, "out", first, "in")
	editor._toggle_mode()
	_check(editor.last_message.contains("pasos"), "un círculo de flujo se corta y se avisa")
	editor._toggle_mode()

	# 7. Soltar una pieza en una zona y tirar los dados disparan sus eventos.
	editor.clear_table()
	editor.logic = LogicGraph.new()
	g = editor.logic
	var zone: PropEntity = editor.add_piece("zona")
	zone.position = Vector3(0.8, 0, 0)
	var token: PropEntity = editor.add_piece("ficha")
	token.position = Vector3(-0.8, 0, 0)
	var on_drop := g.add_node("ev_soltar")
	g.nodes[on_drop]["params"]["zona"] = zone.entity_id
	var said := g.add_node("ac_mensaje")
	var name_of := g.add_node("da_nombre")
	g.connect_ports(on_drop, "out", said, "in")
	g.connect_ports(on_drop, "pieza", name_of, "pieza")
	g.connect_ports(name_of, "valor", said, "texto")
	var on_dice := g.add_node("ev_dados")
	var store := g.add_node("ac_variable")
	g.nodes[store]["params"]["nombre"] = "tirada"
	g.connect_ports(on_dice, "out", store, "in")
	g.connect_ports(on_dice, "total", store, "valor")
	var die: PropEntity = editor.add_piece("dado")
	die.position = Vector3(0, 0, -0.8)
	editor._toggle_mode()
	await physics_frame
	var cam: Camera3D = editor._camera
	editor._orbit = editor._orbit_goal.duplicate()
	editor._apply_orbit()
	var from := cam.unproject_position((token.get_node("Body") as Node3D).global_position + Vector3.UP * 0.04)
	var to := cam.unproject_position(Vector3(0.8, 0, 0))
	_mouse(editor, from, true)
	_motion(editor, to)
	_mouse(editor, to, false)
	_check(editor.last_message == token.entity_name, "soltar en la zona dispara su evento con la pieza: «%s»" % editor.last_message)
	editor.roll_dice([die])
	var waited := 0
	while not editor._rolling.is_empty() and waited < 900:
		await physics_frame
		await process_frame
		waited += 1
	_check(editor.logic_variable("tirada") != null and float(editor.logic_variable("tirada")) == float(editor.last_roll[0]), "al pararse los dados, su total llega a la lógica")
	editor._toggle_mode()

	# 8. El editor de bloques: abre, añade con deshacer, no une tipos distintos.
	editor.history.clear()
	editor.open_logic_editor()
	await process_frame
	var view: LogicEditor = editor.logic_editor
	var shown := view.graph_edit.get_children().filter(func(child: Node) -> bool: return child is GraphNode).size()
	_check(view.visible and shown == g.nodes.size(), "el editor de bloques muestra todos los bloques (%d)" % shown)
	var before := g.nodes.size()
	var added := view.add_block("da_numero", Vector2(100, 400))
	_check(g.nodes.size() == before + 1 and added > 0, "se añade un bloque")
	view._on_connection_request(StringName(str(added)), 0, StringName(str(said)), 0)
	_check(g.link_into(said, "in").get("from") == on_drop, "un número no se engancha a una entrada de flujo")
	editor.undo()
	_check(editor.logic.nodes.size() == before, "Ctrl+Z quita el bloque añadido")
	_check(view.graph_edit.get_children().filter(func(child: Node) -> bool: return child is GraphNode).size() == before, "y la vista se rehace")
	view.close_editor()

	# 9. La lógica viaja en el archivo exportado.
	_check(editor.export_game("user://test_logica.tablerama"), "se exporta con su lógica")
	editor.logic = LogicGraph.new()
	_check(editor.import_game("user://test_logica.tablerama") and editor.logic.nodes.size() == before, "y se importa con ella")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_logica.tablerama"))

	if _failed:
		quit(1)
	else:
		print("editor_logic: ok")
		quit(0)


func _mouse(editor: Control, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	editor._gui_input(event)


func _motion(editor: Control, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	editor._gui_input(event)


func _key(editor: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	editor._unhandled_input(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
