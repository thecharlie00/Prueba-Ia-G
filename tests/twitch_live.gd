extends SceneTree
## Entrega 4 de «El chat juega»: la plantilla para streamers jugada entera con el chat de
## prueba, los bloques de control (sorteo, marcador, cuenta atrás, límites, comandos
## apagados, moderación) y las opciones del directo del streamer.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var twitch: Node = root.get_node("Twitch")
	var saved := {"who": twitch.vote_who, "names": twitch.show_names, "events": twitch.allow_community_events, "msgs": twitch.allow_game_messages}

	# 1. La plantilla «Dragón del chat».
	_check("directo" in TableTemplates.NAMES and "directo" in TableTemplates.FOR_STREAMERS, "hay plantilla para streamers")
	var record: Variant = TableTemplates.logic("directo")
	_check(LogicGraph.from_record(record) != null, "su lógica es válida")
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in 10:
		await process_frame
	var editor: Node = current_scene
	editor.load_template("directo")
	_check(editor.logic_pieces("", "rojo").size() == 8 and editor.logic_pieces("", "azul").size() == 8, "trae 8 soldados por equipo")
	_check(editor.call("logic_uses_twitch"), "y se exporta con la etiqueta «Para streamers»")
	twitch.set_simulated(false, false)
	editor.call("_toggle_mode")
	for i in 3:
		await process_frame
	var bridge: TwitchBridge = (editor.get("_logic_runner") as LogicRunner).twitch
	_check(bridge != null, "al probar se conecta el chat")
	if bridge != null:
		_check(bridge.find_child("TwitchScoreboard", true, false) != null, "sale el marcador de equipos")
		twitch.inject("ana", "!unirme azul")
		_check(str(bridge.viewers["ana"]["team"]) == "azul", "!unirme azul la pone en el equipo azul")
		var piece := str(bridge.viewers["ana"]["piece"])
		_check(not piece.is_empty() and editor.logic_pieces("", "azul").has(piece), "y le da un soldado azul")
		twitch.inject("ana", "!ataque 5")
		_check(bridge.team_coins("azul") == 5, "!ataque 5 suma 5 al equipo azul")
		twitch.inject("ana", "!ataque 6")
		_check(bridge.team_coins("azul") == 5, "la espera de 10 s frena el segundo ataque")
		twitch.inject_event("bits", {"usuario": "luis", "cantidad": 300})
		_check(not bridge._vote_seat.busy, "300 bits no llenan la meta de 500")
		twitch.inject_event("bits", {"usuario": "luis", "cantidad": 250})
		_check(bridge._vote_seat.busy, "con 550 se llena y el chat vota a quién ataca el dragón")
		twitch.inject_event("raid", {"canal": "amigo", "espectadores": 12})
		twitch.inject("bea", "!participo")
		twitch.inject("bea", "!participo")
		_check((bridge._raffles["raid"]["entrants"] as Array).size() == 1, "la raid abre un sorteo y cada uno participa una vez")
		bridge._raffles["raid"]["left"] = 0.0
		await process_frame
		await process_frame
		_check(bridge.coins("bea") == 50, "la ganadora del sorteo recibe 50 monedas")
		_check(bridge.find_child("TwitchHighlight", true, false) != null, "y su mensaje sale destacado")
	editor.call("_toggle_mode")
	await process_frame

	# 2. Bloques de control sueltos.
	var g := LogicGraph.new()
	var cmd := g.add_node("tw_ev_comando")
	g.nodes[cmd]["params"].merge({"comando": "!hola", "argumento": "ninguno", "espera": 0}, true)
	var limit := g.add_node("tw_limite")
	g.nodes[limit]["params"]["veces"] = 2
	var say := g.add_node("ac_mensaje")
	g.nodes[say]["params"]["texto"] = "hola"
	var nope := g.add_node("ac_mensaje")
	g.nodes[nope]["params"]["texto"] = "limite"
	g.connect_ports(cmd, "out", limit, "in")
	g.connect_ports(limit, "si", say, "in")
	g.connect_ports(limit, "no", nope, "in")
	var start := g.add_node("ev_inicio")
	var timer := g.add_node("tw_temporizador")
	g.nodes[timer]["params"].merge({"nombre": "r", "texto": "Ronda", "segundos": 1}, true)
	g.connect_ports(start, "out", timer, "in")
	var off := g.add_node("tw_comando_activo")
	g.nodes[off]["params"].merge({"comando": "!hola", "activo": false}, true)
	var ended := g.add_node("tw_ev_temporizador")
	g.nodes[ended]["params"]["nombre"] = "r"
	g.connect_ports(ended, "out", off, "in")
	var modded := g.add_node("tw_ev_moderacion")
	var say_mod := g.add_node("ac_mensaje")
	g.connect_ports(modded, "out", say_mod, "in")
	g.connect_ports(modded, "usuario", say_mod, "texto")
	editor.set("logic", g)
	editor.call("_toggle_mode")
	for i in 3:
		await process_frame
	bridge = (editor.get("_logic_runner") as LogicRunner).twitch
	if bridge != null:
		_check(bridge.find_child("TwitchTimers", true, false) != null, "la cuenta atrás se ve")
		twitch.inject("a", "!hola")
		twitch.inject("b", "!hola")
		_check(str(editor.get("last_message")) == "hola", "el límite deja pasar las dos primeras")
		twitch.inject("c", "!hola")
		_check(str(editor.get("last_message")) == "limite", "y la tercera va por «no»")
		await create_timer(1.4).timeout
		editor.set("last_message", "")
		twitch.inject("d", "!hola")
		_check(str(editor.get("last_message")) == "", "al acabar la cuenta atrás el comando se apaga")
		var bad: Dictionary = twitch.inject("troll", "mensaje feo")
		twitch.moderation.emit(str(bad["id"]), "")
		_check(str(editor.get("last_message")) == "troll", "borrar un mensaje dispara «Al borrar o banear» con su autor")
		twitch.allow_community_events = false
		editor.set("last_message", "")
		bridge.trace.clear()
		twitch.inject_event("follow", {"usuario": "x"})
		_check("tw_ev_follow" not in bridge.trace, "con los eventos apagados el juego no recibe follows")
		twitch.allow_community_events = true
	editor.call("_toggle_mode")
	await process_frame

	# 3. Opciones del directo.
	twitch.vote_who = "suscriptores"
	_check(not twitch.can_vote([]) and twitch.can_vote(["subscriber"]), "si solo votan subs, un espectador sin insignia no vota")
	twitch.vote_who = "todos"
	twitch.show_names = false
	_check(twitch.display_name("ana") != "ana", "se pueden ocultar los nombres")
	twitch.show_names = true
	var layer: CanvasLayer = twitch.open_live_options(editor)
	await process_frame
	var panel := layer.find_child("LiveOptions", true, false)
	_check(panel != null and panel.find_child("VoteSeconds", true, false) != null and panel.find_child("BlockedWords", true, false) != null, "la ventana de opciones del directo se abre")
	(panel.find_child("Close", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	_check(not is_instance_valid(layer), "y se cierra con «Listo»")

	twitch.vote_who = saved["who"]
	twitch.show_names = saved["names"]
	twitch.allow_community_events = saved["events"]
	twitch.allow_game_messages = saved["msgs"]
	if _failures > 0:
		push_error("twitch_live: %d fallos" % _failures)
		quit(1)
	else:
		print("twitch_live: OK")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		printerr("  FALLO  ", label)
