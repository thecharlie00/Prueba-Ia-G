extends SceneTree
## Entrega 5 de «El chat juega»: modos de decisión (anarquía), votos con peso, apuestas con
## monedas, lluvia de emotes, bocadillos sobre piezas, ayuda de comandos y opciones nuevas.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var twitch: Node = root.get_node("Twitch")
	var saved_mode: String = twitch.decision_mode

	# 1. Votos con peso (sin juego): 3 votos sueltos contra uno que pesa 4.
	var round := VoteRound.new(["A", "B"] as Array[String], 20.0)
	round.weight_of = func(v: Dictionary) -> int: return 4 if str(v["name"]) == "rica" else 1
	round.open()
	for user in ["a", "b", "c"]:
		round.feed({"id": user, "user_id": user, "name": user, "text": "!1"})
	round.feed({"id": "r", "user_id": "r", "name": "rica", "text": "!2"})
	_check(round.counts() == [3, 4] and round.leader() == 1 and round.total() == 7, "un voto con peso 4 gana a 3 sueltos")
	_check((twitch.call("sim_emotes", "hola Kappa <3") as Array).size() == 2, "el chat de prueba reconoce emotes globales")

	# 2. Anarquía en un asiento del chat de un juego nativo: el primer voto decide.
	twitch.decision_mode = "anarquía"
	twitch.set_simulated(false, false)
	twitch.test_chat = true
	var seat := ChatSeat.new(1)
	root.add_child(seat)
	var picked := {"winner": -9}
	seat.ask("¿Qué hago?", ["Uno", "Dos", "Tres"] as Array[String], [], func(w: int) -> void: picked["winner"] = w)
	twitch.inject("ana", "!3")
	_check(seat.vote == null or not seat.vote.is_open, "en anarquía el primer voto cierra la votación")
	await create_timer(ChatSeat.RESULT_TIME + 0.4).timeout
	_check(int(picked["winner"]) == 2, "y juega la opción votada")
	seat.queue_free()
	twitch.test_chat = false

	# 3. Juego de la comunidad: apuestas, votación con peso por bits, emotes, bocadillo, ayuda.
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in 10:
		await process_frame
	var editor: Node = current_scene
	editor.load_template("directo")
	var g: LogicGraph = editor.get("logic")
	var start := g.add_node("ev_inicio")
	var rain := g.add_node("tw_lluvia_emotes")
	var bet := g.add_node("tw_apuesta")
	g.nodes[bet]["params"].merge({"nombre": "ronda", "opciones": "Rojo,Azul", "segundos": 30}, true)
	var vote := g.add_node("tw_votacion")
	g.nodes[vote]["params"].merge({"nombre": "peso", "opciones": "Sí,No", "segundos": 30, "peso": "bits"}, true)
	g.connect_ports(start, "out", rain, "in")
	g.connect_ports(rain, "out", bet, "in")
	g.connect_ports(bet, "out", vote, "in")
	var closed := g.add_node("tw_ev_apuesta")
	g.nodes[closed]["params"]["nombre"] = "ronda"
	var say := g.add_node("ac_mensaje")
	g.connect_ports(closed, "out", say, "in")
	g.connect_ports(closed, "bote", say, "texto")
	var key := g.add_node("ev_tecla")
	g.nodes[key]["params"]["tecla"] = "2"
	var pay := g.add_node("tw_pagar_apuesta")
	g.nodes[pay]["params"].merge({"nombre": "ronda", "ganadora": 2}, true)
	g.connect_ports(key, "out", pay, "in")
	var help_key := g.add_node("ev_tecla")
	g.nodes[help_key]["params"]["tecla"] = "3"
	var help := g.add_node("tw_ayuda")
	g.connect_ports(help_key, "out", help, "in")
	twitch.decision_mode = "anarquía"
	editor.call("_toggle_mode")
	for i in 3:
		await process_frame
	var bridge: TwitchBridge = (editor.get("_logic_runner") as LogicRunner).twitch
	_check(bridge != null, "al probar se conecta el chat")
	if bridge != null:
		# Monedas para apostar: !unirme da equipo; !ataque suma monedas.
		for user in ["ana", "luis", "bea"]:
			twitch.inject(user, "!unirme rojo")
		twitch.inject("ana", "!ataque 6")
		twitch.inject("luis", "!ataque 4")
		twitch.inject("bea", "!ataque 2")
		twitch.inject("ana", "!apuesta 2 6")
		twitch.inject("luis", "!apuesta 1 99")
		twitch.inject("bea", "!apuesta 2 2")
		twitch.inject("ana", "!apuesta 1 1")
		_check(bridge.coins("ana") == 0 and bridge.coins("luis") == 0 and bridge.coins("bea") == 0, "apostar cobra las monedas (como mucho las que tienes)")
		_check(bridge.find_child("TwitchBets", true, false) != null, "el panel de apuestas se ve")
		_check(((bridge._bets["ronda"]["stakes"] as Dictionary)["ana"] as Dictionary)["option"] == 1, "solo cuenta la primera apuesta de cada uno")
		bridge._bets["ronda"]["left"] = 0.0
		await process_frame
		await process_frame
		_check(str(editor.get("last_message")) == "12", "al cerrar las apuestas el evento da el bote (12)")
		twitch.inject("ana", "!apuesta 1 1")
		_check(((bridge._bets["ronda"]["stakes"] as Dictionary)).size() == 3, "con las apuestas cerradas ya no se apuesta")
		_key(editor, KEY_2)
		_check(bridge.coins("ana") == 9 and bridge.coins("bea") == 3 and bridge.coins("luis") == 0, "gana Azul: el bote de 12 se reparte 9 y 3")
		_check(not bridge._bets.has("ronda"), "y la apuesta se cierra")
		# Votación con peso por bits; la anarquía no afecta a los juegos de la comunidad.
		_check(bridge._vote_seat.busy, "la votación del juego está abierta")
		twitch.inject("pepe", "!1")
		_check(bridge._vote_seat.vote != null and bridge._vote_seat.vote.is_open, "las votaciones del juego no se cierran en anarquía")
		twitch.inject_event("bits", {"usuario": "rico", "cantidad": 300})
		twitch.inject("rico", "!2")
		_check(bridge._vote_seat.vote.counts() == [1, 4], "300 bits hacen que su voto cuente 4")
		# Lluvia de emotes (sin red: ficha con el nombre del emote).
		twitch.inject("ana", "Kappa PogChamp")
		_check(get_nodes_in_group("tw_emote").size() == 2, "los emotes caen por la pantalla")
		# Bocadillo sobre una pieza y ayuda.
		var dragon: String = editor.logic_pieces("", "dragon")[0]
		var node: Node3D = editor.call("_find_piece", dragon)
		bridge._bubble_on(node, "¡Grrr!", 2.0)
		_check(node.get_children().any(func(c: Node) -> bool: return c is Label3D and (c as Label3D).text == "¡Grrr!"), "sale un bocadillo sobre la pieza")
		_key(editor, KEY_3)
		_check(bridge._alert != null, "«Mostrar los comandos» enseña la tarjeta de comandos")
	editor.call("_toggle_mode")
	await process_frame

	# 4. Opciones del directo: el modo de decisión.
	var layer: CanvasLayer = twitch.open_live_options(root)
	await process_frame
	_check(layer.find_child("DecisionMode", true, false) != null, "las opciones del directo traen el modo de decisión")
	layer.queue_free()
	twitch.decision_mode = saved_mode
	twitch.set_simulated(false, false)

	if _failures > 0:
		push_error("twitch_show: %d fallos" % _failures)
		quit(1)
	else:
		print("twitch_show: OK")
		quit(0)


func _key(editor: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	editor.call("_unhandled_input", event)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		printerr("  FALLO  ", label)
