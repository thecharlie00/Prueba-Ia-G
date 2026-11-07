extends SceneTree
## Brisca: reglas, bot, partidas completas, guardado y la mesa con la mano ordenable.

const SAVE_PATH := "user://test_brisca.json"
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_rules()
	_bot()
	_full_games()
	await _view()
	if _failed:
		quit(1)
	else:
		print("brisca: ok")
		quit(0)


func _rules() -> void:
	var rules := BriscaRules.new(42)
	_check(rules.hands[0].size() == 3 and rules.hands[1].size() == 3, "se reparten 3 cartas a cada uno")
	_check(rules.stock.size() == 34 and rules.stock[0] == rules.trump_card, "la muestra queda debajo del mazo")
	_check(BriscaRules.new(42).hands == rules.hands, "la misma semilla reparte igual")
	var seen := {}
	for card in rules.hands[0] + rules.hands[1] + rules.stock:
		seen[card] = true
	_check(seen.size() == 40, "las 40 cartas están, sin repetir")
	# Quién gana la baza.
	rules.trump_suit = "O"
	_check(rules.beats("1 C", "3 C"), "el as gana al tres del mismo palo")
	_check(rules.beats("3 C", "12 C"), "el tres gana al rey")
	_check(not rules.beats("12 E", "2 C"), "otro palo que no es triunfo no gana")
	_check(rules.beats("2 O", "1 C"), "el dos de triunfo gana al as de otro palo")
	_check(not rules.beats("4 O", "7 O"), "entre triunfos gana el más alto")
	var total := 0
	for card in BriscaRules.full_deck():
		total += BriscaRules.card_points(card)
	_check(total == 120, "la baraja suma 120 puntos")
	# Una baza: gana, suma y roba primero.
	rules = BriscaRules.new(7)
	var first: String = rules.hands[0][0]
	var second: String = rules.hands[1][0]
	_check(not rules.play(second), "no se puede jugar fuera de turno")
	_check(rules.play(first) and rules.play(second), "se juega una baza")
	var winner := 1 if rules.beats(second, first) else 0
	_check(rules.turn == winner and rules.last_trick["winner"] == winner, "sale quien gana la baza")
	_check(rules.points[winner] == BriscaRules.card_points(first) + BriscaRules.card_points(second), "la baza suma sus puntos")
	_check(rules.hands[0].size() == 3 and rules.hands[1].size() == 3 and rules.stock.size() == 32, "los dos roban")
	# Guardado: semilla + jugadas.
	var copy := BriscaRules.from_record(JSON.parse_string(JSON.stringify(rules.export_record())))
	_check(copy != null and copy.hands == rules.hands and copy.points == rules.points, "la partida se reconstruye")
	var bad := rules.export_record()
	bad["events"].append({"type": "play", "card": "99 O"})
	_check(BriscaRules.from_record(bad) == null, "se rechaza una carta que no existe")


func _bot() -> void:
	var rules := BriscaRules.new(3)
	rules.hands[0] = ["1 C", "4 E", "7 B"]
	rules.trump_suit = "O"
	_check(TableBots.brisca_choice(rules) == "4 E", "al salir tira la carta que menos vale")
	rules.hands[0] = ["3 O", "5 E", "12 C"]
	rules.hands[1] = ["2 B", "6 C", "1 E"]
	rules.play("12 C")
	_check(TableBots.brisca_choice(rules) == "6 C" or TableBots.brisca_choice(rules) == "2 B", "sin ganar con el palo, no gasta el as")
	rules = BriscaRules.new(3)
	rules.trump_suit = "O"
	rules.hands[0] = ["1 C", "5 E", "4 B"]
	rules.hands[1] = ["2 O", "6 C", "1 E"]
	rules.play("1 C")
	_check(TableBots.brisca_choice(rules) == "2 O", "un as en la mesa se gana con el triunfo más barato")


func _full_games() -> void:
	var wins := [0, 0, 0]
	for seed_value in 30:
		var rules := BriscaRules.new(seed_value)
		var plays := 0
		while rules.phase == BriscaRules.PLAYING and plays < 50:
			_check(rules.play(TableBots.brisca_choice(rules)), "el bot siempre juega una carta válida")
			plays += 1
		_check(plays == 40 and rules.phase == BriscaRules.FINISHED, "la partida dura 40 cartas")
		_check(rules.points[0] + rules.points[1] == 120, "se reparten los 120 puntos")
		wins[rules.result] += 1
	print("brisca: 30 partidas bot contra bot, ganadas J1 %d · J2 %d · empates %d" % wins)


func _view() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".previous"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var view: BriscaView = (load("res://scenes/Brisca.tscn") as PackedScene).instantiate()
	view.save_path = SAVE_PATH
	root.add_child(view)
	for i in 5:
		await process_frame
	view.rules = BriscaRules.new(11)
	view.refresh()
	_check(view.hand.cards.size() == 3, "tu mano tiene 3 cartas")
	_check(view.table_cards().any(func(card: Card3D) -> bool: return card.name == "Trump"), "la muestra está en la mesa")
	_check(view.table_cards().filter(func(card: Card3D) -> bool: return String(card.name).begins_with("Rival")).size() == 3, "las 3 cartas del bot, boca abajo")
	# Reordenar y ordenar la mano no cambia las cartas.
	var before := view.hand.cards.duplicate()
	view.hand.move_card(0, 2)
	_check(view.hand.cards[2] == before[0], "arrastrar mueve la carta al hueco nuevo")
	view.refresh()
	_check(view.hand.cards[2] == before[0], "el orden elegido se conserva")
	# Jugar desde la mano: la carta va a la baza y el bot responde.
	var card: String = view.hand.cards[0]
	view._on_hand_played(0)
	_check(view.rules.trick.size() == 1 and view.rules.trick[0]["card"] == card, "clic en la mano juega la carta")
	_check(view.is_bot_turn(), "después juega el bot")
	for i in 60:
		await create_timer(0.05).timeout
		if not view.showing.is_empty():
			break
	_check(not view.showing.is_empty() and view.showing["cards"].size() == 2, "se ve la baza terminada")
	view.finish_showing()
	_check(view.hand.cards.size() == 3, "después de la baza se roba")
	# Guardar y cargar.
	_check(view.save_game(), "se guarda la partida")
	var points: Array = view.rules.points.duplicate()
	var hands: Array = view.rules.hands.duplicate(true)
	view.new_game()
	_check(view.load_game(), "se carga la partida")
	_check(view.rules.points == points and view.rules.hands == hands, "la partida cargada es la misma")
	# Dos personas: la mano se tapa al cambiar de turno.
	view.set_vs_bot(false)
	if view.rules.turn == 0:
		view.play(view.rules.hands[0][0])
	_check(view.viewer == view.rules.turn and view.hand.faces_hidden, "con dos personas la mano se tapa al cambiar")
	view._on_hand_played(0)
	_check(view.rules.trick.size() <= 1, "con la mano tapada no se juega")
	view.queue_free()
	await process_frame
	for path in [SAVE_PATH, SAVE_PATH + ".previous"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
