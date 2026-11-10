extends SceneTree
## Bots: tres dificultades y menú principal → selección de modo (local/bots), además
## de la corrección de los asientos fuera de la mesa física (personajes que pasaban el tablero).

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _ticks(2)
	# --- Tiempos de penseque por dificultad
	_check(
		TableBots.think_time(TableBots.Difficulty.FACIL) < TableBots.think_time(TableBots.Difficulty.NORMAL),
		"el bot fácil piensa antes que el normal"
	)
	_check(
		TableBots.think_time(TableBots.Difficulty.DIFICIL) > TableBots.think_time(TableBots.Difficulty.NORMAL),
		"el bot difícil piensa más que el normal"
	)
	_check(TableBots.think_time() == TableBots.THINK_TIME, "sin dificultad, el tiempo es el de siempre")

	# --- FACIL: jugadas legales al azar en cada juego
	var ludo := LudoRules.new(2)
	ludo.apply_roll(6)
	for i in 20:
		var choice := TableBots.ludo_choice(ludo, TableBots.Difficulty.FACIL)
		_check(choice in ludo.legal_tokens(), "el bot fácil de ludo mueve ficha legal")
	var domino := DominoRules.new()
	domino.reset(7)
	var domino_choice: Dictionary = TableBots.domino_choice(domino, TableBots.Difficulty.FACIL)
	if domino_choice.has("id"):
		_check(
			domino.play(int(domino_choice["id"]), String(domino_choice["end"])),
			"el bot fácil de dominó juega legal"
		)
	else:
		_check(domino_choice.has("action"), "el bot fácil de dominó roba o pasa")
	var checkers := CheckersRules.new()
	var easy_move := TableBots.checkers_choice(checkers, TableBots.Difficulty.FACIL)
	_check(
		not easy_move.is_empty() and checkers.play(int(easy_move["from"]), int(easy_move["to"])),
		"el bot fácil de damas mueve legal"
	)
	var brisca := BriscaRules.new(1)
	var easy_card := TableBots.brisca_choice(brisca, TableBots.Difficulty.FACIL)
	_check(easy_card in brisca.hands[brisca.turn], "el bot fácil de brisca tira carta de su mano")

	# --- DIFICIL: damas con profundidad de 3 juega una partida
	var hard := CheckersRules.new()
	var moves := 0
	while hard.status() == "playing" and moves < 60:
		var move := TableBots.checkers_choice(hard, TableBots.Difficulty.DIFICIL)
		if not hard.play(int(move["from"]), int(move["to"])):
			break
		moves += 1
	_check(moves > 5, "el bot difícil de damas juega una partida (%d jugadas)" % moves)

	# --- Asientos fuera de la mesa física
	var ludo_view := load("res://scenes/Ludo.tscn").instantiate() as LudoView
	root.add_child(ludo_view)
	await _ticks(3)
	_check_seats_outside(ludo_view, "ludo")
	ludo_view.queue_free()
	await _ticks(2)

	var island := load("res://scenes/Island.tscn").instantiate() as IslandView
	root.add_child(island)
	await _ticks(5)
	_check_seats_outside(island, "isla")
	island.queue_free()
	await _ticks(2)

	# --- Menú principal: título, Jugar y Salir; Jugar lleva a la selección de bots
	TableBots.difficulty = TableBots.Difficulty.NORMAL
	TableBots.solo = false
	change_scene_to_file("res://scenes/BotMenu.tscn")
	await _ticks(3)
	var menu := root.get_node_or_null("BotMenu") as Control
	_check(menu != null, "se abre el menú principal")
	if menu != null:
		var jugar := menu.find_child("Jugar", true, false) as Button
		var salir := menu.find_child("Salir", true, false) as Button
		_check(jugar != null, "el menú tiene Jugar")
		_check(salir != null, "el menú tiene Salir")
		if jugar != null:
			jugar.pressed.emit()
			await _ticks(3)
			_check(
				current_scene.scene_file_path == "res://scenes/ModeSelect.tscn",
				"Jugar abre la selección de modo"
			)
			var mode := root.get_node_or_null("ModeSelect") as Control
			_check(mode != null, "se abre la selección de modo")
			if mode != null:
				var local_button := mode.find_child("Local", true, false) as Button
				var bots_button := mode.find_child("Bots", true, false) as Button
				_check(local_button != null, "la selección tiene jugar en local")
				_check(bots_button != null, "la selección tiene jugar con bots")
				if bots_button != null:
					bots_button.pressed.emit()
					await _ticks(3)
					_check(
						current_scene.scene_file_path == "res://scenes/BotSelect.tscn",
						"Jugar con bots abre la selección de bots"
					)
					var selector := root.get_node_or_null("BotSelect") as Control
					_check(selector != null, "se abre la selección de bots")
					if selector != null:
						_check(
							selector.find_child("Dificultad", true, false) != null,
							"la selección pide la dificultad"
						)
						_check(
							selector.find_child("MESAS CON BOT", true, false) != null,
							"la selección muestra las mesas"
						)
						var diff2 := selector.find_child("Difficulty2", true, false) as Button
						_check(diff2 != null, "tiene las tres dificultades")
						if diff2 != null:
							diff2.pressed.emit()
							_check(
								TableBots.difficulty == TableBots.Difficulty.DIFICIL,
								"elegir difícil guarda la dificultad"
							)
						var brisca_button := selector.find_child("Brisca", true, false) as Button
						_check(brisca_button != null, "tiene la mesa de brisca")
						if brisca_button != null:
							brisca_button.pressed.emit()
							_check(TableBots.solo, "elegir una mesa marca el modo solitario")
							await _ticks(3)
							_check(
								current_scene.scene_file_path == "res://scenes/Brisca.tscn",
								"la mesa elegida se abre"
							)
							change_scene_to_file("res://scenes/BotSelect.tscn")
							await _ticks(3)
							var bot_select := root.get_node_or_null("BotSelect")
							_check(
								bot_select != null,
								"al volver, se está en la selección de bots"
							)
							var back := (
								bot_select.find_child("Back", true, false) as Button
								if bot_select != null
								else null
							)
							_check(back != null, "la selección tiene volver")
							if back != null:
								back.pressed.emit()
								await _ticks(3)
								_check(
									current_scene.scene_file_path == "res://scenes/ModeSelect.tscn",
									"volver vuelve a la selección de modo"
								)
								var mode2 := root.get_node_or_null("ModeSelect") as Control
								if mode2 != null:
									var local2 := mode2.find_child("Local", true, false) as Button
									if local2 != null:
										local2.pressed.emit()
										await _ticks(3)
										_check(
											current_scene.scene_file_path == "res://scenes/Menu.tscn",
											"Jugar en local abre la lista de juegos"
										)

	# --- Modo solitario en el ludo: J2 y demás son bots
	TableBots.solo = true
	TableBots.difficulty = TableBots.Difficulty.DIFICIL
	var solo_view := load("res://scenes/Ludo.tscn").instantiate() as LudoView
	root.add_child(solo_view)
	await _ticks(3)
	_check(solo_view.bots[1] == true, "solo: en el ludo de dos, J2 es un bot")
	_check(solo_view.bot_toggles[1].button_pressed, "solo: la casilla del bot está marcada")
	_check(not TableBots.solo, "solo: se consume al abrir la mesa")
	_check(
		TableBots.difficulty == TableBots.Difficulty.DIFICIL,
		"solo: conserva la dificultad elegida"
	)
	_check(solo_view.seats != null, "solo: la mesa tiene asientos")
	solo_view.queue_free()
	TableBots.solo = false
	TableBots.difficulty = TableBots.Difficulty.NORMAL
	await _ticks(2)

	if _failed:
		printerr("Bots (dificultad, menú, asientos): errores")
		quit(1)
	else:
		print("Bots (dificultad, menú, asientos): ok")
		quit(0)


## Cada personaje debe quedar fuera de la caja de la mesa expandida a la altura del
## cuerpo (radio de la shell ~0,44), o se clava en el tablero.
func _check_seats_outside(view: Node, label: String) -> void:
	var table := view.get_node_or_null("Table") as Node3D
	_check(table != null, "%s: tiene la mesa física" % label)
	if table == null:
		return
	var bounds := TableSeats.table_aabb(table.get_node("CollisionShape3D") as CollisionShape3D)
	var seats: TableSeats = view.get_node_or_null("TableSeats")
	_check(seats != null, "%s: tiene asientos" % label)
	if seats == null:
		return
	var i := 0
	while true:
		var avatar := seats.avatar(i)
		if avatar == null:
			break
		var spot := avatar.global_position
		_check(
			not bounds.grow(0.42).has_point(Vector3(spot.x, 0.0, spot.z)),
			"%s: el asiento %d queda fuera de la mesa" % [label, i + 1]
		)
		i += 1
	_check(i > 0, "%s: hay asientos" % label)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
