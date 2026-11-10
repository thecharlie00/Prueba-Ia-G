extends SceneTree
## Pruebas de los adaptadores online NetTable para Parchís/Ludo, Ajedrez, Damas,
## Dominó (con privacidad de fichas) y Brisca (con mano propia y sync por semilla).

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var net := root.get_node_or_null("Net")
	_check(net != null, "autoload Net registrado")
	if net == null:
		quit(1)
		return

	# 1. Catálogo completo de 12 mesas online en el Lobby
	var games: Array = net.ONLINE_GAMES
	_check(games.size() == 12, "el catálogo online expone las 12 mesas con reglas")
	for entry in games:
		var scene_path := str(entry["scene"])
		_check(ResourceLoader.exists(scene_path), "existe escena online " + scene_path)

	# 2. Parchís / Ludo online (LudoNetTable)
	_check(change_scene_to_file("res://scenes/Parchis2.tscn") == OK, "abrir Parchis2.tscn")
	await _frames()
	var parchis := current_scene as LudoView
	_check(parchis != null, "Parchis2 cargada como LudoView")
	if parchis != null:
		parchis.online = true
		parchis._suppress_roll_anim = true
		var ludo_net := LudoNetTable.new()
		ludo_net.view_node = parchis
		ludo_net.ludo = parchis.rules
		parchis.net_table = ludo_net
		parchis.add_child(ludo_net)
		_check(
			not ludo_net._allows({"type": "roll", "value": 5}, 1),
			"Parchís online rechaza tirada fuera de turno"
		)
		_check(
			not ludo_net._allows({"type": "roll", "value": 7}, 0),
			"Parchís online rechaza valor de dado inválido"
		)
		_check(
			ludo_net._allows({"type": "roll", "value": 5}, 0)
			and ludo_net._apply({"type": "roll", "value": 5, "seat": 0}),
			"Parchís online acepta tirada de 5 en turno propio"
		)
		_check(
			ludo_net._allows({"type": "move", "token": 0}, 0)
			and ludo_net._apply({"type": "move", "token": 0, "seat": 0}),
			"Parchís online saca ficha de casa con el 5"
		)
		var ludo_snap := ludo_net.snapshot()
		parchis.rules = LudoRules.new(2, LudoRules.PARCHIS)
		ludo_net.ludo = parchis.rules
		ludo_net._on_sync(ludo_snap)
		_check(
			parchis.rules.positions[0][0] == 0 and parchis.rules.turn == 1,
			"Parchís online reconstruye el estado tras sync"
		)

	# 3. Ajedrez físico online (ChessNetTable)
	_check(
		change_scene_to_file("res://scenes/GuidedPhysicalChess.tscn") == OK,
		"abrir GuidedPhysicalChess.tscn"
	)
	await _frames()
	var chess_view := current_scene as GuidedPhysicalChess
	_check(chess_view != null, "GuidedPhysicalChess cargada")
	if chess_view != null:
		chess_view.online = true
		var chess_net := ChessNetTable.new()
		chess_net.view_node = chess_view
		chess_net.chess = chess_view.rules
		chess_view.net_table = chess_net
		chess_view.add_child(chess_net)
		# 52 = e2, 36 = e4; 12 = e7, 28 = e5
		_check(
			not chess_net._allows({"type": "move", "from": 12, "to": 28, "promotion": ChessRules.QUEEN}, 1),
			"Ajedrez online impide que negras muevan en turno de blancas"
		)
		_check(
			not chess_net._allows({"type": "move", "from": 52, "to": 28, "promotion": ChessRules.QUEEN}, 0),
			"Ajedrez online rechaza jugada ilegal e2-e5"
		)
		_check(
			chess_net._allows({"type": "move", "from": 52, "to": 36, "promotion": ChessRules.QUEEN}, 0)
			and chess_net._apply({"type": "move", "from": 52, "to": 36, "promotion": ChessRules.QUEEN}),
			"Ajedrez online aplica e2-e4 de blancas"
		)
		_check(
			chess_net._allows({"type": "move", "from": 12, "to": 28, "promotion": ChessRules.QUEEN}, 1)
			and chess_net._apply({"type": "move", "from": 12, "to": 28, "promotion": ChessRules.QUEEN}),
			"Ajedrez online aplica e7-e5 de negras"
		)
		var chess_snap := chess_net.snapshot()
		chess_view._reset()
		chess_net.chess = chess_view.rules
		chess_net._on_sync(chess_snap)
		_check(
			chess_view.rules.move_log.size() == 2 and chess_view.rules.piece_at(36) != 0,
			"Ajedrez online sincroniza historial y piezas físicas"
		)

	# 4. Damas físicas online (CheckersNetTable)
	_check(
		change_scene_to_file("res://scenes/GuidedPhysicalCheckers.tscn") == OK,
		"abrir GuidedPhysicalCheckers.tscn"
	)
	await _frames()
	var checkers_view := current_scene as GuidedPhysicalCheckers
	_check(checkers_view != null, "GuidedPhysicalCheckers cargada")
	if checkers_view != null:
		checkers_view.online = true
		var chk_net := CheckersNetTable.new()
		chk_net.view_node = checkers_view
		chk_net.checkers = checkers_view.rules
		checkers_view.net_table = chk_net
		checkers_view.add_child(chk_net)
		var first_move := {}
		for sq in range(64):
			var moves := checkers_view.rules.legal_moves_from(sq)
			if not moves.is_empty():
				first_move = {"type": "move", "from": sq, "to": int(moves[0]["to"])}
				break
		_check(not first_move.is_empty(), "Damas tiene movimiento inicial legal")
		_check(
			not chk_net._allows(first_move, 1),
			"Damas online rechaza movimiento fuera de turno"
		)
		_check(
			chk_net._allows(first_move, 0) and chk_net._apply(first_move),
			"Damas online aplica movimiento inicial de blancas"
		)
		var chk_snap := chk_net.snapshot()
		var chk_moves: Array = chk_snap.get("moves", [])
		_check(
			chk_moves.size() == 1 and checkers_view.sync_from_record(chk_snap),
			"Damas online reconstruye tablero desde snapshot"
		)

	# 5. Dominó online y ocultación de fichas ajenas/pozo (DominoNetTable)
	_check(
		change_scene_to_file("res://scenes/GuidedDomino.tscn") == OK,
		"abrir GuidedDomino.tscn"
	)
	await _frames()
	var domino_view := current_scene as GuidedDomino
	_check(domino_view != null, "GuidedDomino cargada")
	if domino_view != null:
		domino_view.online = true
		var dom_net := DominoNetTable.new()
		dom_net.view_node = domino_view
		dom_net.domino = domino_view.rules
		domino_view.net_table = dom_net
		domino_view.add_child(dom_net)
		domino_view._refresh()
		# Sin sesión activa local_seat() devuelve 0 (J1): sus 7 fichas visibles, 21 ocultas (J2 + pozo)
		var visible_count := 0
		var hidden_count := 0
		for tile in domino_view.tiles:
			var pips := tile.get_node_or_null("Visual/Pips") as Node3D
			if pips != null and pips.visible:
				visible_count += 1
			elif tile.display_name == "Dominó oculto":
				hidden_count += 1
		_check(
			visible_count == 7 and hidden_count == 21,
			"Dominó online muestra las 7 fichas propias y oculta las 21 del rival y el pozo"
		)
		var first_id: int = int(domino_view.rules.hands[0][0])
		_check(
			not dom_net._allows({"type": "play", "id": first_id, "end": "left"}, 1),
			"Dominó online rechaza jugada fuera de turno"
		)
		_check(
			dom_net._allows({"type": "play", "id": first_id, "end": "left"}, 0)
			and dom_net._apply({"type": "play", "id": first_id, "end": "left"}),
			"Dominó online coloca ficha en la cadena"
		)
		var dom_snap := dom_net.snapshot()
		domino_view.rules = DominoRules.new()
		dom_net.domino = domino_view.rules
		dom_net._on_sync(dom_snap)
		_check(
			domino_view.rules.chain.size() == 1 and int(domino_view.rules.chain[0]["id"]) == first_id,
			"Dominó online sincroniza reparto y cadena"
		)

	# 6. Brisca online y mano propia boca arriba (BriscaNetTable)
	_check(change_scene_to_file("res://scenes/Brisca.tscn") == OK, "abrir Brisca.tscn")
	await _frames()
	var brisca_view := current_scene as BriscaView
	_check(brisca_view != null, "Brisca cargada")
	if brisca_view != null:
		brisca_view.online = true
		brisca_view.set_vs_bot(false)
		var bri_net := BriscaNetTable.new()
		bri_net.view_node = brisca_view
		bri_net.brisca = brisca_view.rules
		brisca_view.net_table = bri_net
		brisca_view.add_child(bri_net)
		brisca_view.refresh()
		var p1_card := str(brisca_view.rules.hands[0][0])
		var p2_card := str(brisca_view.rules.hands[1][0])
		_check(
			not brisca_view.hand.faces_hidden and p1_card in brisca_view.hand.cards,
			"Brisca online muestra las cartas propias boca arriba sin tapar al cambiar turno"
		)
		_check(
			not bri_net._allows({"type": "play", "card": p2_card}, 0)
			and not bri_net._allows({"type": "play", "card": p1_card}, 1),
			"Brisca online impide jugar cartas ajenas o fuera de turno"
		)
		_check(
			bri_net._allows({"type": "play", "card": p1_card}, 0)
			and bri_net._apply({"type": "play", "card": p1_card}),
			"Brisca online acepta la salida de J1"
		)
		_check(
			bri_net._allows({"type": "play", "card": p2_card}, 1)
			and bri_net._apply({"type": "play", "card": p2_card}),
			"Brisca online resuelve la baza con la respuesta de J2"
		)
		var bri_snap := bri_net.snapshot()
		brisca_view.rules = BriscaRules.new(1)
		bri_net.brisca = brisca_view.rules
		bri_net._on_sync(bri_snap)
		_check(
			int(brisca_view.rules.tricks_won[0]) + int(brisca_view.rules.tricks_won[1]) == 1,
			"Brisca online sincroniza semilla y bazas jugadas"
		)

	if failures > 0:
		printerr("Online tables tests: %d errores" % failures)
		quit(1)
	else:
		print("Online tables tests OK")
		quit(0)


func _frames() -> void:
	for i in 4:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FALLO: " + message)
