extends SceneTree

const ISLAND_SCENE := load("res://scenes/Island.tscn")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := ISLAND_SCENE.instantiate() as IslandView
	root.add_child(view)
	await _ticks(3)
	_check(view.dice.size() == 2 and view.homes.size() == 1, "dos dados y ladrón físicos")
	_check(view.hand3d != null and view.hand3d.items.is_empty(), "mano 3D vacía al empezar")
	_check(view.tabs.get_tab_count() == 4 and view.tabs.current_tab == 0, "interfaz por pestañas")
	var panel := view.get_node("IslandUI/Panel") as Control
	var hand := view.get_node("IslandUI/ResourceHand") as Control
	var panel_rect := panel.get_global_rect()
	var hand_rect := hand.get_global_rect()
	var accessible := 0
	for vertex in range(54):
		var screen := view.camera.unproject_position(view._vertex_position(vertex))
		if not panel_rect.has_point(screen) and not hand_rect.has_point(screen):
			accessible += 1
	_check(accessible >= 5, "la interfaz deja accesible el tablero")
	_check(not view.grabber.dice_shortcuts_enabled, "el controlador de isla coordina los dados")
	_check(
		(view.dice[0].collision_mask & 4) != 0 and (view.grabber.ray_mask & 4) == 0,
		"bandeja física no bloquea selección"
	)
	_check(view.selection_mode == "settlement", "selección inicial de pueblo")
	_check(not view.grabber.is_processing_unhandled_input(), "selección no agarra objetos")
	for step in range(6):
		var owner := view.rules.turn
		var vertex := -1
		for i in range(view.rules.board.vertices.size()):
			if view.rules.can_settlement(i):
				vertex = i
				break
		_check(vertex >= 0, "hay pueblo inicial disponible")
		if vertex < 0:
			break
		if step == 0:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = view.camera.unproject_position(view._vertex_position(vertex))
			view._unhandled_input(click)
		else:
			view._select_board(view._vertex_position(vertex))
		_check(view.rules.building_owner[vertex] == owner, "se construye pueblo")
		_check(
			view.rules.phase == IslandRules.SETUP_ROAD and view.selection_mode == "road",
			"seleccionar camino"
		)
		var edge := -1
		for i in view.rules.board.vertex_edges[vertex]:
			if view.rules.can_road(i):
				edge = i
				break
		_check(edge >= 0, "hay camino inicial disponible")
		if edge < 0:
			break
		view._select_board(view._edge_position(edge))
		_check(view.rules.road_owner[edge] == owner, "se construye camino")
	_check(view.rules.phase == IslandRules.ROLL, "fin de preparación")
	_check(view.building_nodes.size() == 6 and view.road_nodes.size() == 6, "piezas de preparación")
	_check(view.grabber.is_processing_unhandled_input(), "se reanuda agarre")
	view.save_path = "user://test_island_view.json"
	_clean_save(view.save_path)
	var before_roads: Array[int] = view.rules.road_owner.duplicate()
	var before_seed := view.rules.initial_seed
	view._save_game()
	var original_save := FileAccess.get_file_as_string(view.save_path)
	var original_events: Array[Dictionary] = view.rules.events.duplicate(true)
	view.rules.events.resize(IslandRules.MAX_EVENTS + 1)
	view._save_game()
	_check(
		FileAccess.get_file_as_string(view.save_path) == original_save,
		"historial demasiado largo conserva guardado anterior"
	)
	view.rules.events = [{"type": "x".repeat(view.MAX_SAVE_BYTES)}]
	view._save_game()
	_check(
		FileAccess.get_file_as_string(view.save_path) == original_save,
		"guardado demasiado grande conserva guardado anterior"
	)
	view.rules.events = original_events
	view.rules.roll(1, 1)
	view._load_game()
	await _ticks(3)
	_check(
		view.rules.phase == IslandRules.ROLL and view.rules.road_owner == before_roads,
		"cargar restaura partida"
	)
	_check(
		view.rules.initial_seed == before_seed and view.building_nodes.size() == 6,
		"tablero y cuerpos restaurados"
	)
	var invalid := FileAccess.open(view.save_path, FileAccess.WRITE)
	invalid.store_string("{corrupto")
	invalid.close()
	view._load_game()
	_check(
		view.rules.phase == IslandRules.ROLL and view.rules.road_owner == before_roads,
		"carga inválida no altera partida"
	)
	_clean_save(view.save_path)
	# La tirada manual empieza al soltar cada dado, sin inventar valores.
	view.manually_thrown = [true, true]  # Un turno anterior no debe contar para este.
	for i in range(2):
		var die := view.dice[i]
		view.grabber.hovered = die
		view.grabber._begin_grab(view.camera.unproject_position(die.global_position))
		_check(view.grabber.held == die, "se agarra el dado físico")
		view.grabber._release()
		if i == 0:
			await _ticks(90)
			_check(view.manual_roll and not view.waiting_roll, "espera el segundo dado manual")
			_check(view.rules.phase == IslandRules.ROLL, "un solo dado no resuelve el turno")
	_check(
		view.waiting_roll and view.rules.phase == IslandRules.ROLL,
		"dos dados manuales esperan estabilidad"
	)
	view._reset_dice()
	_check(
		not view.manual_roll and not view.waiting_roll and view.rules.last_dice == Vector2i.ZERO,
		"recolocar cancela tirada manual sin alterar reglas"
	)
	_check(
		is_equal_approx(view.dice[0].global_position.x, 2.97),
		"recolocar devuelve el dado a la bandeja"
	)
	# Un dado inmóvil e inclinado recibe un impulso real, no un valor inventado.
	var tilted := view.dice[0]
	tilted.linear_velocity = Vector3.ZERO
	tilted.angular_velocity = Vector3.ZERO
	view.nudge_counts = [0, 0]
	view._unstick_die(tilted, 0, 0.7, 1.3)
	_check(view.nudge_counts[0] == 1, "un dado encajado recibe un impulso físico")
	view._reset_dice()
	# R lanza ambos cuerpos físicos, sin confirmar hasta que se detienen.
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	root.push_input(key)
	await process_frame
	_check(
		view.waiting_roll and view.dice[0]._awaiting_result and view.dice[1]._awaiting_result,
		"tirada física"
	)
	view._on_die_result(2, 0)
	_check(view.waiting_roll and view.rules.phase == IslandRules.ROLL, "espera ambos dados")
	view._cancel_roll()
	view._on_die_result(3, 1)
	_check(
		view.rules.phase == IslandRules.ROLL and not view.waiting_roll,
		"cancelación ignora resultados tardíos"
	)
	# Se permite cancelar una tirada encajada, igual que en el juego.
	for attempt in range(3):
		for die in view.dice:
			die.global_position = Vector3(2.97, 1.2, -0.8 if die == view.dice[0] else 0.8)
			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO
		await _ticks(100)
		view._roll()
		for i in range(900):
			if not view.waiting_roll:
				break
			await physics_frame
		if not view.waiting_roll:
			break
		if attempt < 2:
			view._cancel_roll()

	_check(not view.waiting_roll, "ambos dados se detienen y resuelven")
	_check(
		view.rules.last_dice.x in range(1, 7) and view.rules.last_dice.y in range(1, 7),
		"caras físicas válidas"
	)
	if not view.waiting_roll:
		for i in range(2):
			_check(
				view.roll_results[i] == view.dice[i].top_face(),
				"cara superior coincide con resultado"
			)
	# Ejercitar selección del ladrón y transición a robo si hay víctima.
	view.rules.phase = IslandRules.ROBBER
	view._refresh()
	var tile := (view.rules.robber_tile + 1) % 19
	view._select_board(view._tile_position(tile))
	_check(
		(
			view.rules.robber_tile == tile
			and view.homes[view.robber_node] == view._tile_position(tile)
		),
		"mover ladrón"
	)
	_check(view.rules.phase in [IslandRules.STEAL, IslandRules.ACTION], "fase tras ladrón")
	view.rules.phase = IslandRules.ACTION
	view._refresh()
	view._begin_selection("road")
	_check(
		view.selection_mode == "road" and not view.grabber.is_processing_unhandled_input(),
		"selección bloquea agarre"
	)
	view._cancel_selection()
	_check(
		view.selection_mode.is_empty() and view.grabber.is_processing_unhandled_input(),
		"cancelar reactiva agarre"
	)
	# Los controles de oferta y carta ejecutan las reglas, no solo actualizan texto.
	view.rules.resources[0] = [3, 0, 0, 0, 0]
	view.rules.resources[1] = [0, 2, 0, 0, 0]
	view.trade_partner.select(1)
	view.trade_give[0].value = 2
	view.trade_take[1].value = 1
	view._offer_trade()
	_check(
		view.rules.phase == IslandRules.TRADE_RESPONSE and view.tabs.current_tab == 1,
		"oferta muestra respuesta"
	)
	view._respond_trade(true)
	_check(view.rules.resources[0] == [1, 1, 0, 0, 0], "interfaz acepta intercambio")
	view.rules.dev_ready[0][IslandRules.KNIGHT] = 1
	view._refresh()
	view.dev_choice.select(0)
	view._play_development()
	_check(view.selection_mode == "robber", "interfaz activa caballero")
	view._select_board(view._tile_position((view.rules.robber_tile + 1) % 19))
	if view.rules.phase == IslandRules.STEAL:
		view._steal()
	_check(
		view.rules.knights_played[0] == 1 and view.rules.phase == IslandRules.ACTION,
		"interfaz resuelve caballero"
	)
	# El descarte usa la carta ilustrada del recurso sin navegar por menús.
	view.rules.phase = IslandRules.DISCARD
	view.rules.discard_due = [0, 1, 0]
	view.rules.discard_player = 1
	view.rules.resources[1][0] = 2
	view._refresh()
	_check(
		(
			view.turn_controls["resource"].visible
			and view.hand_index_of(0) >= 0
			and not view.hand3d.items[view.hand_index_of(0)].get("disabled", false)
			and view.hand_heading.text.contains("J2")
		),
		"descarte contextual"
	)
	view.hand3d.item_pressed.emit(view.hand_index_of(0))
	_check(
		view.rules.resources[1][0] == 1 and view.rules.phase == IslandRules.ROBBER,
		"descarte desde carta"
	)
	# Los cuerpos vuelven por fuerza, no por teletransporte lógico.
	var building: IslandPiece3D = view.building_nodes.values()[0]
	var home: Vector3 = view.homes[building]
	building.global_position = home + Vector3(0.15, 0.5, 0)
	building.linear_velocity = Vector3.ZERO
	building.sleeping = false
	await _ticks(90)
	_check(absf(building.global_position.x - home.x) < 0.15, "retorno físico de pueblo")
	view.queue_free()
	await process_frame
	await _four_player_view()
	await _bot_match()
	if failures:
		printerr("Island view: %d errores" % failures)
		quit(1)
	else:
		print("Island view tests OK")
		quit(0)


func _four_player_view() -> void:
	var view := load("res://scenes/IslandFour.tscn").instantiate() as IslandView
	root.add_child(view)
	await _ticks(2)
	_check(
		view.rules.players == 4 and view.game_title.text.contains("4 jugadores"),
		"escena de cuatro jugadores"
	)
	var order: Array[int] = []
	for step in range(8):
		order.append(view.rules.turn)
		var vertex := -1
		for i in range(54):
			if view.rules.can_settlement(i):
				vertex = i
				break
		if vertex < 0:
			_check(false, "preparación cuatro jugadores")
			break
		view._select_board(view._vertex_position(vertex))
		for edge in view.rules.board.vertex_edges[vertex]:
			if view.rules.can_road(edge):
				view._select_board(view._edge_position(edge))
				break
	_check(
		order == [0, 1, 2, 3, 3, 2, 1, 0] and view.rules.phase == IslandRules.ROLL,
		"orden para cuatro"
	)
	view.save_path = "user://test_island_four.json"
	_clean_save(view.save_path)
	view._save_game()
	view._load_game()
	_check(
		view.rules.players == 4 and view.building_nodes.size() == 8,
		"guardar y cargar cuatro jugadores"
	)
	_clean_save(view.save_path)
	view.queue_free()
	await process_frame


## Partida completa entre bots: la vista juega sola, sin intervención humana.
func _bot_match() -> void:
	TableBots.solo = true
	TableBots.difficulty = TableBots.Difficulty.FACIL
	var view := ISLAND_SCENE.instantiate() as IslandView
	root.add_child(view)
	await _ticks(2)
	_check(view.bots[1] and view.bots[2], "solo bots marca J2 y J3")
	view.set_bot(true, 0)  # J1 también bot: la partida se completa sin humano.
	var guard := 0
	while view.rules.phase != IslandRules.FINISHED and guard < 4000:
		view._process(1.0)  # Cada llamada avanza una acción del bot.
		guard += 1
	TableBots.solo = false
	_check(view.rules.phase == IslandRules.FINISHED, "partida entre bots termina")
	_check(
		view.rules.winner >= 0 and view.rules.score(view.rules.winner) >= 10,
		"ganador con 10 puntos"
	)
	view.queue_free()
	await process_frame


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)


func _clean_save(path: String) -> void:
	for suffix in ["", ".previous", ".pending", ".previous.pending"]:
		var file: String = path + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
