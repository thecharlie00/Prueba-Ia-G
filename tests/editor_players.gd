extends SceneTree
## Jugadores y turnos, el asistente «Nuevo juego», el menú contextual de las piezas y los
## atajos del editor de bloques (cable soltado en vacío, notas).

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in range(10):
		await process_frame
	var editor := current_scene
	var hierarchy: SceneHierarchy = editor._scene_hierarchy

	# 1. «Nuevo juego» de cartas para 3: manos de color, marcadores y reparto para todos.
	editor.add_piece("ficha")
	editor.new_game("cartas", 3, true, true)
	_check(editor.players == 3, "el juego queda para 3 jugadores")
	var hands: Array = [0, 1, 2].map(func(i: int) -> String: return editor.hand_zone_of(i))
	_check(not hands.has(""), "cada jugador tiene su zona de mano: %s" % [hands])
	_check(editor._find_piece("zona_mano") == null, "la mano común de la plantilla se quita")
	var scores: Array = editor.ui_layout.elements.filter(func(e: Dictionary) -> bool: return str(e["type"]) == "counter")
	_check(scores.size() == 3 and str(scores[1]["name"]).contains(GamePlayers.player_name(1)), "y un marcador por jugador")
	_check(editor.logic.nodes.values().any(func(n: Dictionary) -> bool: return n["type"] == "nota"), "la lógica trae una nota que la explica")
	editor._toggle_mode()
	await process_frame
	await process_frame
	for i in range(3):
		_check(editor.logic_pieces(hands[i], "").size() == 5, "al probar, el jugador %d recibe 5 cartas" % (i + 1))
	_check(editor.logic_pieces("zona_mazo", "").size() == 5, "y en el mazo quedan 5: %d" % editor.logic_pieces("zona_mazo", "").size())
	_check(editor.current_player == 0, "tras repartir, el turno vuelve al primero")
	_check(editor._turn_bar.visible and editor._turn_label.text.contains(GamePlayers.player_name(0)), "la barra de turno dice de quién es")
	_key(editor, KEY_1)
	for i in range(30):
		await physics_frame
	_check(editor.logic_pieces(hands[0], "").size() == 6, "la tecla 1 roba para quien tiene el turno")
	_key(editor, KEY_T)
	_check(editor.current_player == 1, "T pasa el turno")
	_key(editor, KEY_1)
	_check(editor.logic_pieces(hands[1], "").size() == 6, "y ahora roba el segundo")
	editor._toggle_mode()
	_check(not editor._turn_bar.visible, "al editar, la barra de turno se esconde")
	editor.undo()
	_check(hierarchy.entities.size() == 1 and editor.players == 2, "Ctrl+Z vuelve a la mesa de antes del asistente")

	# 2. Evento de turno y datos de jugadores en la lógica.
	editor.clear_table()
	editor.set_players(4)
	editor.logic = LogicGraph.new()
	var g: LogicGraph = editor.logic
	var on_turn := g.add_node("ev_turno")
	var store := g.add_node("ac_variable")
	g.nodes[store]["params"]["nombre"] = "ultimo"
	g.connect_ports(on_turn, "out", store, "in")
	g.connect_ports(on_turn, "nombre", store, "valor")
	var key := g.add_node("ev_tecla")
	var give := g.add_node("ac_dar_turno")
	g.nodes[give]["params"]["jugador"] = 4
	g.connect_ports(key, "out", give, "in")
	editor._toggle_mode()
	await process_frame
	_check(editor.logic_variable("ultimo") == GamePlayers.player_name(0), "al empezar, salta «Al empezar un turno» del primero")
	_key(editor, KEY_1)
	await process_frame
	_check(editor.current_player == 3 and editor.logic_variable("ultimo") == GamePlayers.player_name(3), "«Dar el turno a» 4 funciona")
	_key(editor, KEY_T)
	await process_frame
	_check(editor.current_player == 0, "tras el último, vuelve el primero")
	editor._toggle_mode()

	# 3. Menú contextual: clic derecho en una pieza.
	editor.clear_table()
	var token: PropEntity = editor.add_piece("ficha")
	editor.select_pieces([])
	var cam: Camera3D = editor._camera
	editor._orbit = editor._orbit_goal.duplicate()
	editor._apply_orbit()
	await process_frame
	var at := cam.unproject_position(token.global_position + Vector3.UP * 0.04)
	var options: Array = editor.open_context_menu(at)
	_check(options.size() >= 6 and editor.selection == [token], "clic derecho en una pieza abre su menú y la selecciona")
	var duplicate_id := -1
	for id in editor.context_actions:
		if str(editor.context_actions[id][0]).begins_with(tr("Duplicar")):
			duplicate_id = id
	editor.run_context_action(duplicate_id)
	_check(hierarchy.entities.size() == 2, "«Duplicar» del menú duplica")
	_check(editor.open_context_menu(Vector2(5, 5)).is_empty(), "en un hueco no hay menú")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = at
	editor._gui_input(right)
	var release := right.duplicate() as InputEventMouseButton
	release.pressed = false
	editor._gui_input(release)
	_check(editor._context_menu != null and editor._context_menu.visible, "un clic derecho sin arrastrar abre el menú")
	editor._context_menu.hide()

	# 4. Editor de bloques: soltar un cable en vacío ofrece sólo lo que encaja y lo une.
	editor.logic = LogicGraph.new()
	editor.open_logic_editor()
	await process_frame
	var view: LogicEditor = editor.logic_editor
	var start := view.add_block("ev_inicio", Vector2.ZERO)
	view._on_connection_to_empty(StringName(str(start)), 0, Vector2(300, 100))
	var offered: Array = []
	for i in view._popup.item_count:
		if not view._popup.is_item_separator(i):
			offered.append(str(view._popup.get_item_metadata(i)))
	_check(offered.has("ac_mensaje") and not offered.has("da_numero") and not offered.has("ev_tecla"), "sólo se ofrecen bloques con entrada de flujo")
	var message := view.add_block_for_wire("ac_mensaje", Vector2(300, 0))
	_check(editor.logic.link_into(message, "in").get("from") == start, "y el nuevo bloque queda unido")
	var number_node := view.add_block("da_numero", Vector2(0, 300))
	view._on_connection_to_empty(StringName(str(number_node)), 0, Vector2(300, 300))
	var joined := view.add_block_for_wire("da_comparar", Vector2(300, 300))
	_check(editor.logic.link_into(joined, "a").get("from") == number_node, "un número se une a la primera entrada que lo acepta")
	var note := view.add_block("nota", Vector2(0, 500))
	_check(note > 0 and view.graph_edit.get_node_or_null(NodePath(str(note))) != null, "se pueden poner notas")
	view.close_editor()
	editor._toggle_mode()
	_check(editor._logic_runner != null and editor._logic_runner.errors.is_empty(), "las notas no estorban al jugar")
	editor._toggle_mode()

	if _failed:
		quit(1)
	else:
		print("editor_players: ok")
		quit(0)


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
