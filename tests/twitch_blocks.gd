extends SceneTree
## Bloques «Twitch» del creador: comandos con argumentos y permisos, eventos del canal,
## votaciones, espectadores (monedas, equipos, ranking), chat en pantalla con moderación y el
## chat de prueba.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var twitch: Node = root.get_node("Twitch")
	_check(LogicNodes.CATEGORIES.has("twitch"), "hay categoría Twitch en el editor de lógica")
	var count := 0
	for type: String in LogicNodes.DEFS:
		if type.begins_with("tw_"):
			count += 1
	_check(count >= 30, "el catálogo trae %d bloques de Twitch" % count)
	_check(LogicNodes.is_event("tw_ev_bits") and not LogicNodes.is_event("tw_alerta"), "los eventos de Twitch cuentan como eventos")

	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in 10:
		await process_frame
	var editor: Node = current_scene
	var g := LogicGraph.new()
	# !ataque <1-6> → mensaje con el valor.
	var attack := g.add_node("tw_ev_comando")
	g.nodes[attack]["params"].merge({"comando": "!ataque", "alias": "!atk", "argumento": "número", "minimo": 1, "maximo": 6, "espera": 0}, true)
	var say := g.add_node("ac_mensaje")
	g.connect_ports(attack, "out", say, "in")
	g.connect_ports(attack, "valor", say, "texto")
	# !escudo solo para moderadores.
	var shield := g.add_node("tw_ev_comando")
	g.nodes[shield]["params"].merge({"comando": "!escudo", "argumento": "ninguno", "quien": "moderadores", "espera": 0}, true)
	var say_shield := g.add_node("ac_mensaje")
	g.nodes[say_shield]["params"]["texto"] = "escudo"
	g.connect_ports(shield, "out", say_shield, "in")
	# !unirme rojo/azul → equipo rojo y 5 monedas.
	var join := g.add_node("tw_ev_comando")
	g.nodes[join]["params"].merge({"comando": "!unirme", "argumento": "opción", "opciones": "rojo,azul", "espera": 0}, true)
	var team := g.add_node("tw_equipo")
	g.nodes[team]["params"]["equipo"] = "rojo"
	var coins := g.add_node("tw_monedas")
	g.connect_ports(join, "out", team, "in")
	g.connect_ports(join, "usuario", team, "usuario")
	g.connect_ports(team, "out", coins, "in")
	g.connect_ports(join, "usuario", coins, "usuario")
	g.nodes[coins]["params"]["cantidad"] = 5
	# Bits ≥ 50 → alerta.
	var bits := g.add_node("tw_ev_bits")
	g.nodes[bits]["params"]["minimo"] = 50
	var alert := g.add_node("tw_alerta")
	g.connect_ports(bits, "out", alert, "in")
	g.connect_ports(bits, "usuario", alert, "usuario")
	g.connect_ports(bits, "cantidad", alert, "cantidad")
	# Al empezar: chat en panel lateral y votación; al cerrar, mensaje con la opción.
	var start := g.add_node("ev_inicio")
	var show := g.add_node("tw_mostrar_chat")
	var vote := g.add_node("tw_votacion")
	g.nodes[vote]["params"].merge({"nombre": "dragón", "opciones": "Atacar,Huir", "segundos": 30}, true)
	g.connect_ports(start, "out", show, "in")
	g.connect_ports(show, "out", vote, "in")
	var closed := g.add_node("tw_ev_votacion")
	g.nodes[closed]["params"]["nombre"] = "dragón"
	var say_vote := g.add_node("ac_mensaje")
	g.connect_ports(closed, "out", say_vote, "in")
	g.connect_ports(closed, "opcion", say_vote, "texto")
	var copy := LogicGraph.from_record(JSON.parse_string(JSON.stringify(g.to_record())))
	_check(copy != null, "un juego con bloques de Twitch se guarda y se carga")
	editor.set("logic", g)

	twitch.set_simulated(true, false)
	editor.call("_toggle_mode")
	for i in 3:
		await process_frame
	var runner: LogicRunner = editor.get("_logic_runner")
	var bridge: TwitchBridge = runner.twitch if runner != null else null
	_check(bridge != null, "al probar la mesa se conecta el chat")
	if bridge != null:
		twitch.set_simulated(false, false)
		_check(bridge.get_node_or_null("CanvasLayer/TwitchTestChat") != null or bridge.find_child("TwitchTestChat", true, false) != null, "aparece el chat de prueba")
		twitch.inject("ana", "!ataque 4")
		_check(str(editor.get("last_message")) == "4", "!ataque 4 dispara el comando con valor 4")
		editor.set("last_message", "")
		twitch.inject("ana", "!atk 9")
		_check(str(editor.get("last_message")) == "", "un valor fuera de rango no dispara nada")
		twitch.inject("ana", "!ATK 2")
		_check(str(editor.get("last_message")) == "2", "los alias funcionan y no importan las mayúsculas")
		editor.set("last_message", "")
		twitch.inject("ana", "!escudo")
		_check(str(editor.get("last_message")) == "", "un comando de moderadores no lo usa cualquiera")
		var mod_badges: Array[String] = ["moderator"]
		twitch.inject("mod_bea", "!escudo", mod_badges)
		_check(str(editor.get("last_message")) == "escudo", "un moderador sí puede")
		twitch.inject("ana", "!unirme rojo")
		twitch.inject("luis", "!unirme azul")
		twitch.inject("luis", "!unirme verde")
		_check(bridge.coins("ana") == 5 and bridge.coins("luis") == 5, "unirse da 5 monedas")
		_check(str(bridge.viewers["ana"]["team"]) == "rojo", "y asigna equipo")
		_check(bridge.team_coins("rojo") == 10, "monedas del equipo")
		_check(bridge.ranking(2).begins_with("1. "), "ranking de espectadores")
		var mesa := TableApi.new()
		LogicHost.bind(mesa, editor)
		_check(mesa.monedas("ana") == 5 and mesa.dar_monedas("ana", 3) == 8 and mesa.equipo("ana") == "rojo", "los bloques GDScript leen y dan monedas")
		_check("ana" in mesa.espectadores(), "y ven a los espectadores activos")
		mesa.dar_monedas("ana", -3)
		LogicHost.release(mesa)
		twitch.inject_event("bits", {"usuario": "ana", "cantidad": 20})
		_check(bridge._alert == null, "bits por debajo del mínimo no lanzan la alerta")
		twitch.inject_event("bits", {"usuario": "ana", "cantidad": 100})
		_check(bridge._alert != null, "100 bits lanzan la alerta")
		# Votación del arranque: votan tres por Huir y uno por Atacar.
		var seat: ChatSeat = bridge._vote_seat
		_check(seat.vote != null and seat.vote.is_open, "la votación del juego está abierta")
		if seat.vote != null:
			for voter in ["a", "b", "c"]:
				twitch.inject(voter, "!2")
			twitch.inject("d", "!1")
			seat.vote.close()
			await create_timer(ChatSeat.RESULT_TIME + 0.5).timeout
			_check(str(editor.get("last_message")) == "Huir", "al cerrar gana Huir y se dispara su evento")
		# Moderación: un mensaje borrado sale del chat en pantalla.
		var message: Dictionary = twitch.inject("pepe", "hola chat")
		var before := bridge._messages.size()
		twitch.moderation.emit(str(message["id"]), "")
		_check(bridge._messages.size() == before - 1, "un mensaje borrado desaparece del chat en pantalla")
		twitch.blocked_words.assign(["palabrota"])
		var shown_before := bridge._messages.size()
		twitch.inject("pepe", "esto es una palabrota")
		_check(bridge._messages.size() == shown_before, "el filtro de palabras del streamer oculta el mensaje")
		twitch.blocked_words.clear()
		# Comandos: errores con tipo.
		_check(bridge.parse_command({"text": "!unirme verde", "badges": []}).get("error", "") == "argumento", "una opción que no existe se rechaza")
		_check(bridge.parse_command({"text": "hola", "badges": []}).is_empty(), "un mensaje normal no es un comando")
	editor.call("_toggle_mode")
	await process_frame
	twitch.set_simulated(false, false)

	if _failures > 0:
		push_error("twitch_blocks: %d fallos" % _failures)
		quit(1)
	else:
		print("twitch_blocks: OK")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		printerr("  FALLO  ", label)
