extends SceneTree
## Fase 0: partidas completas en cada modo con reglas, con la física y las vistas reales.
## Las juegan los bots (y la IA del ajedrez) por las mismas funciones que usa el jugador,
## y al final se comprueba que la partida termina y que cada pieza física está donde dice
## el estado lógico (sin piezas perdidas, caídas ni desincronizadas). También recorre la
## pausa y la salida al menú de cada mesa.

const SETTLE_FRAMES := 6
const ChessAI := preload("res://scripts/chess/ChessAI.gd")
var _failed := false
var _report: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(20261107)
	await _chess(false)
	await _chess(true)
	await _checkers()
	await _domino()
	await _ludo()
	await _parchis()
	await _island()
	await _pause_and_exit()
	for line in _report:
		print(line)
	if _failed:
		quit(1)
	else:
		print("playthroughs: ok")
		quit(0)


func _open(path: String) -> Node:
	var view: Node = (load(path) as PackedScene).instantiate()
	root.add_child(view)
	for i in 10:
		await physics_frame
	return view


func _settle(frames := SETTLE_FRAMES) -> void:
	for i in frames:
		await physics_frame


func _close(view: Node) -> void:
	view.queue_free()
	await process_frame
	await process_frame


## Distancia horizontal máxima entre cada pieza y su casa lógica.
func _worst_offset(homes: Dictionary) -> float:
	var worst := 0.0
	var culprit := ""
	for key in homes:
		var body := key as Node3D
		if not is_instance_valid(body):
			continue
		var home: Vector3 = homes[key]
		var offset := Vector2(body.global_position.x - home.x, body.global_position.z - home.z).length()
		if offset > worst:
			worst = offset
			culprit = "%s en %s, casa %s, congelada %s" % [body.name, body.global_position, home, body.get("freeze")]
	if worst > 0.15:
		_report.append("  peor pieza: " + culprit)
	return worst


func _lowest(nodes: Array) -> float:
	var lowest := INF
	for node in nodes:
		if is_instance_valid(node):
			lowest = minf(lowest, (node as Node3D).global_position.y)
	return lowest


# --- Ajedrez físico con reglas. finish: blancas tácticas contra negras casuales hasta el
# mate; si no, IA casual con los dos colores durante 200 jugadas (muchas capturas).
func _chess(finish: bool) -> void:
	var view := await _open("res://scenes/GuidedPhysicalChess.tscn")
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var plies := 0
	while view.rules.status() in ["playing", "check"] and plies < (260 if finish else 200):
		# Blancas con la IA táctica y negras con la casual: la partida acaba en mate.
		var mode := ChessRules.OPPONENT_AI_TACTICAL if finish and view.rules.turn == ChessRules.WHITE else ChessRules.OPPONENT_AI_CASUAL
		var move: Dictionary = ChessAI.choose_move(view.rules, mode, random)
		var snapshot: Dictionary = view._move_with_mapping(
			view.rules, view.piece_squares, view.homes, view.capture_counts,
			int(move["from"]), int(move["to"]), ChessRules.QUEEN
		)
		_check(not snapshot.is_empty(), "ajedrez: cada jugada se refleja en las piezas")
		if snapshot.is_empty():
			break
		view._snapshots.append(snapshot)
		view._update_models()
		view._refresh()
		plies += 1
		await _settle()
	await _settle(150)
	# En el tablero, exactas; las comidas pueden quedar algo amontonadas en la bandeja.
	var on_board := {}
	var captured := {}
	for piece in view.homes:
		if int(view.piece_squares.get(piece, -1)) >= 0:
			on_board[piece] = view.homes[piece]
		else:
			captured[piece] = view.homes[piece]
	var offset := _worst_offset(on_board)
	var tray := _worst_offset(captured)
	_report.append("ajedrez: %d jugadas, final «%s», desvío en el tablero %.3f, en la bandeja %.3f" % [plies, view.rules.status(), offset, tray])
	if finish:
		_check(view.rules.status() not in ["playing", "check"], "ajedrez: la partida termina")
	_check(offset < 0.1, "ajedrez: las piezas del tablero acaban en su casilla (desvío %.3f)" % offset)
	_check(tray < 0.35, "ajedrez: las piezas comidas llegan a la bandeja (desvío %.3f)" % tray)
	_check(_lowest(view.homes.keys()) > 0.5, "ajedrez: ninguna pieza se cae de la mesa")
	await _close(view)


# --- Damas físicas con reglas: bot con los dos colores.
func _checkers() -> void:
	var view := await _open("res://scenes/GuidedPhysicalCheckers.tscn")
	var plies := 0
	while view.rules.status() == "playing" and plies < 300:
		var move := TableBots.checkers_choice(view.rules)
		var mover: Token3D = view._token_at_square(int(move["from"]))
		_check(view._apply_move(int(move["from"]), int(move["to"]), mover), "damas: cada jugada se aplica")
		view._refresh_guides()
		plies += 1
		await _settle()
	await _settle(150)
	var offset := _worst_offset(view.home_positions)
	_report.append("damas: %d jugadas, final «%s», desvío máximo %.3f" % [plies, view.rules.status(), offset])
	_check(offset < 0.2, "damas: las fichas acaban en su sitio (desvío %.3f)" % offset)
	_check(_lowest(view.home_positions.keys()) > 0.5, "damas: ninguna ficha se cae")
	await _close(view)


# --- Dominó con reglas: bot con los dos jugadores.
func _domino() -> void:
	var view := await _open("res://scenes/GuidedDomino.tscn")
	# Semilla con la que la cadena se desplaza entera varias veces (caso que fallaba).
	view.rules.reset(2)
	view._sync_homes(true)
	await _settle(20)
	var steps := 0
	while view.rules.result == DominoRules.PLAYING and steps < 120:
		_check(view.bot_step(), "dominó: el bot siempre tiene una acción válida")
		steps += 1
		await _settle()
	await _settle(300)
	var offset := _worst_offset(view.homes)
	_report.append("dominó: %d acciones, resultado «%s», desvío máximo %.3f" % [steps, view.rules.result, offset])
	_check(view.rules.result != DominoRules.PLAYING, "dominó: la partida termina")
	_check(offset < 0.25, "dominó: las fichas acaban en la cadena o en la mano (desvío %.3f)" % offset)
	await _close(view)


# --- Ludo: tres tiradas con el dado físico y luego tiradas directas para acabar la partida.
func _ludo() -> void:
	var view := await _open("res://scenes/Ludo.tscn")
	for player in view.rules.players:
		view.set_bot(true, player)
	var physical_rolls := 0
	var waited := 0
	while physical_rolls < 3 and waited < 3000:
		await physics_frame
		waited += 1
		if view.rules.phase == LudoRules.MOVE or (view.rules.phase == LudoRules.ROLL and not view.waiting_roll and view.rules.events.size() > physical_rolls * 2):
			physical_rolls = view.rules.events.filter(func(e: Dictionary) -> bool: return e["type"] == "roll").size()
	_check(physical_rolls >= 3, "ludo: el bot tira el dado físico y se lee el resultado")
	for player in view.rules.players:
		view.set_bot(false, player)
	await _settle(30)
	var moves := 0
	while view.rules.phase != LudoRules.FINISHED and moves < 900:
		if view.waiting_roll:
			await physics_frame
			continue
		if view.rules.phase == LudoRules.ROLL:
			view.rules.apply_roll(randi_range(1, 6))
			view._refresh()
		if view.rules.phase == LudoRules.MOVE:
			view._choose_token(TableBots.ludo_choice(view.rules))
			moves += 1
			var guard := 0
			while not view.in_transit.is_empty() and guard < 240:
				await physics_frame
				guard += 1
			_check(guard < 240, "ludo: la ficha llega a su casilla")
	await _settle(120)
	var homes := {}
	for player in view.rules.players:
		for index in 4:
			homes[view.tokens[player][index]] = view._token_position(player, index, view.rules.positions[player][index])
	var offset := _worst_offset(homes)
	_report.append("ludo: %d movimientos, ganador J%d, desvío máximo %.3f" % [moves, view.rules.winner + 1, offset])
	_check(view.rules.phase == LudoRules.FINISHED, "ludo: la partida termina")
	_check(offset < 0.15, "ludo: las fichas acaban en su casilla (desvío %.3f)" % offset)
	await _close(view)


# --- Parchís a 4: tiradas directas y el bot, con barreras y premios.
func _parchis() -> void:
	var view := await _open("res://scenes/Parchis.tscn")
	var moves := 0
	var barriers := 0
	while view.rules.phase != LudoRules.FINISHED and moves < 2500:
		if view.waiting_roll:
			await physics_frame
			continue
		if view.rules.phase == LudoRules.ROLL:
			view.rules.apply_roll(randi_range(1, 6))
			view._refresh()
		if view.rules.phase == LudoRules.MOVE:
			view._choose_token(TableBots.ludo_choice(view.rules))
			moves += 1
			for player in view.rules.players:
				for token in 4:
					var progress: int = view.rules.positions[player][token]
					if progress >= 0 and progress < 52 and view.rules.tokens_on(LudoRules.track_square(player, progress)).size() == 2:
						barriers += 1
			var guard := 0
			while not view.in_transit.is_empty() and guard < 240:
				await physics_frame
				guard += 1
	await _settle(150)
	var homes := {}
	for player in view.rules.players:
		for index in 4:
			homes[view.tokens[player][index]] = view._token_position(player, index, view.rules.positions[player][index])
	var offset := _worst_offset(homes)
	_report.append("parchís: %d movimientos, ganador J%d, %d veces con fichas compartiendo casilla, desvío máximo %.3f" % [moves, view.rules.winner + 1, barriers, offset])
	_check(view.rules.phase == LudoRules.FINISHED, "parchís: la partida termina")
	_check(offset < 0.15, "parchís: las fichas acaban en su casilla (desvío %.3f)" % offset)
	await _close(view)


# --- Isla de recursos: bot voraz con los tres jugadores, colocando por el tablero.
func _island() -> void:
	var view := await _open("res://scenes/Island.tscn")
	var rules: IslandRules = view.rules
	var actions := 0
	var stuck := 0
	while rules.phase != IslandRules.FINISHED and actions < 4000 and stuck < 3:
		var before := rules.events.size()
		var action := TableBots.island_action(rules)
		match String(action.get("kind", "")):
			"settlement":
				view._set_mode("settlement")
				view._select_board(view._vertex_position(int(action["id"])))
			"city":
				view._set_mode("city")
				view._select_board(view._vertex_position(int(action["id"])))
			"road":
				view._set_mode("road")
				view._select_board(view._edge_position(int(action["id"])))
			"robber":
				view._set_mode("robber")
				view._select_board(view._tile_position(int(action["id"])))
			"roll":
				rules.roll(randi_range(1, 6), randi_range(1, 6))
				view._refresh()
			"discard":
				rules.discard(int(action["id"]))
				view._refresh()
			"steal":
				rules.steal(int(action["id"]))
				view._refresh()
			"trade":
				rules.trade_bank(int(action["give"]), int(action["take"]))
				view._refresh()
			"end":
				view._end_turn()
		stuck = stuck + 1 if rules.events.size() == before else 0
		actions += 1
		if actions % 10 == 0:
			await physics_frame
	_check(stuck < 3, "isla: el tablero acepta cada acción del bot (fase «%s»)" % rules.phase)
	await _settle(150)
	var offset := _worst_offset(view.homes)
	var built: int = view.building_nodes.size() + view.road_nodes.size()
	_report.append("isla: %d acciones, ganador J%d, %d piezas en el tablero, desvío máximo %.3f" % [actions, rules.winner + 1, built, offset])
	_check(rules.phase == IslandRules.FINISHED, "isla: la partida termina con un ganador")
	_check(offset < 0.2, "isla: pueblos, ciudades y caminos acaban en su sitio (desvío %.3f)" % offset)
	await _close(view)


# --- Pausa y salida al menú en cada mesa.
func _pause_and_exit() -> void:
	var navigation := root.get_node("SessionNavigation")
	for scene in ["Main", "Chess", "GuidedPhysicalChess", "PhysicalChess", "Checkers", "GuidedPhysicalCheckers", "PhysicalCheckers", "GuidedDomino", "PhysicalDomino", "Ludo", "Parchis", "Island", "CardTable", "Brisca"]:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		for i in 12:
			await process_frame
		navigation._toggle()
		await process_frame
		_check(paused, "%s: Esc pone la partida en pausa" % scene)
		navigation._request_return_to_menu()
		await process_frame
		navigation._return_to_menu()
		for i in 6:
			await process_frame
		_check(current_scene != null and current_scene.scene_file_path.ends_with("Menu.tscn"), "%s: la salida confirmada vuelve al menú" % scene)
		_check(not paused, "%s: el menú no queda en pausa" % scene)
	_report.append("pausa y salida al menú: 14 mesas")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
