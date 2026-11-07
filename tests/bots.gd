extends SceneTree
## Bots para completar mesas: ludo, dominó y damas.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# --- Ludo
	var ludo := LudoRules.new(2)
	ludo.apply_roll(6)
	_check(TableBots.ludo_choice(ludo) == 0, "con un 6 y todo en casa, el bot saca ficha")
	ludo = LudoRules.new(2)
	ludo.positions[0] = [10, 3, LudoRules.YARD, LudoRules.YARD]
	# Ficha rival en la casilla a la que llega la ficha 1 (3 + 4 = 7, no segura).
	ludo.positions[1] = [posmod(LudoRules.track_square(0, 7) - 13, 52), LudoRules.YARD, LudoRules.YARD, LudoRules.YARD]
	ludo.apply_roll(4)
	_check(TableBots.ludo_choice(ludo) == 1, "el bot prefiere comer")
	ludo = LudoRules.new(2)
	ludo.positions[0] = [53, 20, LudoRules.YARD, LudoRules.YARD]
	ludo.apply_roll(4)
	_check(TableBots.ludo_choice(ludo) == 0, "el bot prefiere llegar a la meta")
	# Partida entera bot contra bot: siempre elige una ficha legal y termina.
	ludo = LudoRules.new(4)
	var plies := 0
	while ludo.phase != LudoRules.FINISHED and plies < 4000:
		ludo.apply_roll(randi_range(1, 6))
		if ludo.phase == LudoRules.MOVE:
			var token := TableBots.ludo_choice(ludo)
			_check(token in ludo.legal_tokens(), "el bot de ludo solo mueve fichas legales")
			ludo.move(token)
		plies += 1
	_check(ludo.phase == LudoRules.FINISHED, "una partida de ludo entre bots termina (%d tiradas)" % plies)

	# --- Dominó
	for seed_value in [1, 7, 42]:
		var domino := DominoRules.new()
		domino.reset(seed_value)
		var steps := 0
		while domino.result == DominoRules.PLAYING and steps < 200:
			var choice := TableBots.domino_choice(domino)
			var ok := false
			if choice.has("id"):
				ok = domino.play(int(choice["id"]), String(choice["end"]))
			elif choice.get("action") == "draw":
				ok = domino.draw() >= 0
			elif choice.get("action") == "pass":
				ok = domino.pass_turn()
			_check(ok, "la acción del bot de dominó es legal (semilla %d)" % seed_value)
			if not ok:
				break
			steps += 1
		_check(domino.result != DominoRules.PLAYING, "la partida de dominó entre bots termina")

	# --- Damas
	var checkers := CheckersRules.new()
	checkers.board.fill(0)
	checkers.board[5 * 8 + 2] = CheckersRules.WHITE * CheckersRules.MAN
	checkers.board[4 * 8 + 3] = CheckersRules.BLACK * CheckersRules.MAN
	checkers.board[0 * 8 + 1] = CheckersRules.BLACK * CheckersRules.MAN
	checkers.turn = CheckersRules.WHITE
	var capture := TableBots.checkers_choice(checkers)
	_check(int(capture.get("to", -1)) == 3 * 8 + 4, "el bot de damas captura cuando es obligatorio")
	checkers = CheckersRules.new()
	var turns := 0
	while checkers.status() == "playing" and turns < 400:
		var move := TableBots.checkers_choice(checkers)
		_check(checkers.play(int(move["from"]), int(move["to"])), "el bot de damas juega legal")
		turns += 1
	_check(turns > 10, "las damas entre bots juegan una partida de verdad (%d jugadas)" % turns)

	# --- En las mesas
	var view: Node = (load("res://scenes/GuidedPhysicalCheckers.tscn") as PackedScene).instantiate()
	root.add_child(view)
	for i in 5:
		await physics_frame
	view.set_bot_enabled(true)
	_check(view.get_node("UI/Panel/Margin/Content/BotToggle").button_pressed, "la casilla del bot se marca")
	var white := TableBots.checkers_choice(view.rules)
	var mover: Token3D = view._token_at_square(int(white["from"]))
	_check(view._apply_move(int(white["from"]), int(white["to"]), mover), "el jugador mueve las blancas")
	_check(view.is_bot_turn(), "después juega el bot")
	_check(view.bot_step(), "el bot mueve una ficha física")
	_check(view.rules.turn == CheckersRules.WHITE, "tras el bot vuelve a tocar a las blancas")
	view._undo()
	_check(view.rules.turn == CheckersRules.WHITE and view._snapshots.is_empty(), "deshacer con bot vuelve a tu jugada")
	view.queue_free()

	var table: Node = (load("res://scenes/GuidedDomino.tscn") as PackedScene).instantiate()
	root.add_child(table)
	for i in 5:
		await physics_frame
	table.set_bot_enabled(true)
	var first := TableBots.domino_choice(table.rules)
	table.rules.play(int(first["id"]), String(first["end"]))
	_check(table.is_bot_turn(), "en el dominó el bot es el jugador 2")
	_check(table.bot_step(), "el bot de dominó actúa en la mesa")
	table.queue_free()

	var board: Node = (load("res://scenes/Ludo4.tscn") as PackedScene).instantiate()
	root.add_child(board)
	for i in 5:
		await physics_frame
	board.set_bot(true, 0)
	_check(board.is_bot_turn() and board.bot_toggles[0].button_pressed, "en el ludo se elige qué jugadores son bots")
	board.queue_free()
	await process_frame

	if _failed:
		quit(1)
	else:
		print("bots: ok")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
