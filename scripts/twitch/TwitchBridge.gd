class_name TwitchBridge
extends Node
## Une el chat de Twitch con los bloques «Twitch» de un juego de la comunidad mientras se
## prueba la mesa: dispara los eventos (mensajes, comandos, bits, raids…), lleva el registro de
## espectadores (monedas, equipos, fichas), abre votaciones, enseña el chat en pantalla, las
## alertas y la barra de meta, y ofrece un «chat de prueba» para probar sin estar en directo.

const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/Nunito.ttf")
## Minutos sin escribir tras los que un espectador deja de contar como activo.
const ACTIVE_SECONDS := 600.0
const MAX_PANEL_MESSAGES := 8
const MAX_CARDS := 10
## Votaciones por minuto que puede abrir un juego como mucho.
const VOTES_PER_MINUTE := 6
const ROLE_BADGES := {
	"suscriptores": ["subscriber", "founder"], "suscriptor": ["subscriber", "founder"],
	"VIP": ["vip"], "moderadores": ["moderator"], "moderador": ["moderator"], "streamer": ["broadcaster"],
}

var runner: LogicRunner
var editor: Node
## nombre → {coins, team, piece, badges, seen}
var viewers := {}
var commands: Array[Dictionary] = []
var trace: Array[String] = []

var _cooldowns := {}
var _vote_seat: ChatSeat
var _vote_name := ""
var _vote_times: Array[float] = []
var _layer: CanvasLayer
var _chat_box: Control
var _chat_style := ""
var _chat_side := "derecha"
var _chat_filter := "sin comandos"
var _messages: Array[Dictionary] = []
var _ticker_offset := 0.0
var _bubbles: Array = []
var _alert: PanelContainer
var _alert_left := 0.0
var _goal: PanelContainer
var _goal_bar: ProgressBar
var _goal_label: Label
var _test_panel: PanelContainer
var _now := 0.0
var _relayout_left := 0.0


func _init(logic_runner: LogicRunner, owner_editor: Node) -> void:
	runner = logic_runner
	editor = owner_editor
	name = "TwitchBridge"


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 55
	add_child(_layer)
	_vote_seat = ChatSeat.new(-1)
	add_child(_vote_seat)
	_vote_seat.finished.connect(func(_w: int) -> void: _render_chat())
	_build_commands()
	var twitch := _twitch()
	if twitch == null:
		return
	twitch.chat_message.connect(_on_message)
	twitch.moderation.connect(_on_moderation)
	twitch.channel_event.connect(_on_channel_event)
	twitch.state_changed.connect(_on_state)
	_ask_scopes()
	_build_test_panel()
	if bool(twitch.call("is_available")):
		_fire.call_deferred("tw_ev_conexion")


func _exit_tree() -> void:
	var twitch := _twitch()
	if twitch != null:
		twitch.call("clear_rewards")


func _twitch() -> Node:
	return get_node_or_null("/root/Twitch")


func _fire(type: String, matches := Callable(), data := {}) -> void:
	trace.append(type)
	runner.fire(type, matches, data)


# --- Comandos -----------------------------------------------------------------------

func _build_commands() -> void:
	commands.clear()
	for node: Dictionary in runner.graph.nodes.values():
		if str(node["type"]) != "tw_ev_comando":
			continue
		var p: Dictionary = node["params"]
		var names: Array[String] = [_clean_command(str(p.get("comando", "")))]
		for alias in str(p.get("alias", "")).split(",", false):
			names.append(_clean_command(alias))
		var options: Array[String] = []
		for option in str(p.get("opciones", "")).split(",", false):
			options.append(option.strip_edges().to_lower())
		commands.append({
			"name": names[0], "names": names, "arg": str(p.get("argumento", "ninguno")),
			"min": int(p.get("minimo", 1)), "max": int(p.get("maximo", 6)), "options": options,
			"who": str(p.get("quien", "todos")), "wait": float(p.get("espera", 5)), "help": str(p.get("ayuda", "")),
		})


static func _clean_command(text: String) -> String:
	var name := text.strip_edges().to_lower()
	return name if name.begins_with("!") or name.is_empty() else "!" + name


## Comprueba un mensaje contra los comandos del juego. Devuelve {command, value} o {error}.
func parse_command(message: Dictionary) -> Dictionary:
	var words := str(message.get("text", "")).strip_edges().split(" ", false)
	if words.is_empty() or not words[0].begins_with("!"):
		return {}
	var word := words[0].to_lower()
	for command in commands:
		if word not in (command["names"] as Array):
			continue
		if not _has_role(message, str(command["who"])):
			return {"error": "rol", "command": command}
		var arg := words[1].to_lower() if words.size() > 1 else ""
		var value: Variant = null
		match str(command["arg"]):
			"número":
				if not arg.is_valid_int() or int(arg) < int(command["min"]) or int(arg) > int(command["max"]):
					return {"error": "argumento", "command": command}
				value = float(int(arg))
			"opción":
				if arg not in (command["options"] as Array):
					return {"error": "argumento", "command": command}
				value = arg
			"casilla":
				if not RegEx.create_from_string("^[a-z][0-9]{1,2}$").search(arg):
					return {"error": "argumento", "command": command}
				value = arg.to_upper()
			"jugador":
				var target := arg.trim_prefix("@")
				if target.is_empty():
					return {"error": "argumento", "command": command}
				value = target
		return {"command": command, "value": value}
	return {}


func _has_role(message: Dictionary, who: String) -> bool:
	if who == "todos":
		return true
	var badges: Array = message.get("badges", [])
	if "broadcaster" in badges:
		return true
	for badge: Variant in ROLE_BADGES.get(who, []):
		if badge in badges:
			return true
	return false


# --- Mensajes y eventos -------------------------------------------------------------

func _on_message(message: Dictionary) -> void:
	var user := str(message.get("name", ""))
	if user.is_empty():
		return
	var viewer := _viewer(user)
	viewer["badges"] = message.get("badges", [])
	viewer["seen"] = _now
	var text := str(message.get("text", ""))
	var is_command := text.strip_edges().begins_with("!")
	_show_message(message, is_command)
	if text.strip_edges().to_lower() == "!ayuda":
		_show_help()
		return
	var parsed := parse_command(message)
	if parsed.has("command") and not parsed.has("error"):
		var command: Dictionary = parsed["command"]
		var key := "%s|%s" % [command["name"], user]
		if _now < float(_cooldowns.get(key, -1.0)):
			return
		_cooldowns[key] = _now + float(command["wait"])
		var name := str(command["name"])
		_fire("tw_ev_comando", func(p: Dictionary) -> bool: return _clean_command(str(p.get("comando", ""))) == name, {"usuario": user, "valor": parsed["value"]})
	var emotes := float((message.get("emotes", []) as Array).size())
	_fire("tw_ev_mensaje", func(p: Dictionary) -> bool: return _message_matches(p, message), {"usuario": user, "emotes": emotes})


func _message_matches(p: Dictionary, message: Dictionary) -> bool:
	if not _has_role(message, str(p.get("quien", "todos"))):
		return false
	var text := str(message.get("text", "")).to_lower()
	var needle := str(p.get("texto", "")).to_lower()
	match str(p.get("filtro", "todos")):
		"empieza por":
			return text.begins_with(needle)
		"contiene":
			return needle.is_empty() or text.contains(needle)
		"solo emotes":
			return not (message.get("emotes", []) as Array).is_empty()
	return true


func _on_channel_event(kind: String, data: Dictionary) -> void:
	match kind:
		"bits":
			_fire("tw_ev_bits", func(p: Dictionary) -> bool: return int(data["cantidad"]) >= int(p.get("minimo", 1)), {"usuario": data["usuario"], "cantidad": float(data["cantidad"])})
		"sub":
			_fire("tw_ev_sub", Callable(), {"usuario": data["usuario"], "meses": float(data.get("meses", 1)), "regalo": bool(data.get("regalo", false))})
		"follow":
			_fire("tw_ev_follow", Callable(), {"usuario": data["usuario"]})
		"raid":
			_fire("tw_ev_raid", func(p: Dictionary) -> bool: return int(data["espectadores"]) >= int(p.get("minimo", 1)), {"canal": data["canal"], "espectadores": float(data["espectadores"])})
		"canje":
			var title := str(data.get("recompensa", "")).to_lower()
			_fire("tw_ev_canje", func(p: Dictionary) -> bool: return str(p.get("recompensa", "")).strip_edges().to_lower() == title, {"usuario": data["usuario"]})
		"hype":
			_fire("tw_ev_hype", func(p: Dictionary) -> bool: return str(p.get("fase", "")) == str(data.get("fase", "")), {"nivel": float(data.get("nivel", 1))})
		"anuncio":
			_fire("tw_ev_anuncio", Callable(), {"segundos": float(data.get("segundos", 0))})


func _on_moderation(message_id: String, user_id: String) -> void:
	_messages = _messages.filter(func(m: Dictionary) -> bool:
		if message_id.is_empty() and user_id.is_empty():
			return false
		return str(m.get("id", "")) != message_id and (user_id.is_empty() or str(m.get("user_id", "")) != user_id)
	)
	_render_chat()


func _on_state(_state: String) -> void:
	var twitch := _twitch()
	if twitch != null and bool(twitch.call("is_connected_to_chat")):
		_fire("tw_ev_conexion")


## Pide los permisos que usan los bloques del juego y avisa si falta alguno.
func _ask_scopes() -> void:
	var uses: Array[String] = []
	var map := {"tw_ev_bits": "bits", "tw_ev_sub": "sub", "tw_ev_follow": "follow", "tw_ev_canje": "canje", "tw_recompensa": "recompensa", "tw_ev_hype": "hype", "tw_ev_anuncio": "anuncio", "tw_escribir": "escribir"}
	for node: Dictionary in runner.graph.nodes.values():
		var use := str(map.get(str(node["type"]), ""))
		if not use.is_empty() and use not in uses:
			uses.append(use)
	if uses.is_empty():
		return
	var missing: Array = _twitch().call("request_scopes", uses)
	if not missing.is_empty():
		editor.call("logic_message", TranslationServer.translate("Este juego usa eventos de Twitch que piden permisos nuevos: desconecta y vuelve a conectar Twitch en Ajustes."))


# --- Espectadores -------------------------------------------------------------------

func _viewer(user: String) -> Dictionary:
	if not viewers.has(user):
		viewers[user] = {"coins": 0, "team": "", "piece": "", "badges": [], "seen": _now}
	return viewers[user]


func coins(user: String) -> int:
	return int(_viewer(user)["coins"]) if not user.is_empty() else 0


func team_coins(team: String) -> int:
	var total := 0
	for user: Variant in viewers:
		if str((viewers[user] as Dictionary)["team"]) == team:
			total += int((viewers[user] as Dictionary)["coins"])
	return total


func ranking(count: int) -> String:
	var names: Array = viewers.keys()
	names.sort_custom(func(a: Variant, b: Variant) -> bool: return coins(str(a)) > coins(str(b)))
	var lines: Array[String] = []
	for i in range(mini(count, names.size())):
		lines.append("%d. %s (%d)" % [i + 1, str(names[i]), coins(str(names[i]))])
	return "\n".join(lines)


func active_viewers(team := "") -> Array[String]:
	var result: Array[String] = []
	for user: Variant in viewers:
		var v: Dictionary = viewers[user]
		if _now - float(v["seen"]) <= ACTIVE_SECONDS and (team.is_empty() or str(v["team"]) == team):
			result.append(str(user))
	return result


func _give_piece(user: String, tag: String) -> String:
	var viewer := _viewer(user)
	if not str(viewer["piece"]).is_empty():
		return str(viewer["piece"])
	var taken: Array = viewers.values().map(func(v: Dictionary) -> String: return str(v["piece"]))
	for piece: Variant in editor.call("logic_pieces", "", tag.strip_edges().to_lower()):
		if str(piece) not in taken:
			viewer["piece"] = str(piece)
			editor.call("logic_set_label", str(piece), user)
			return str(piece)
	return ""


# --- Bloques ------------------------------------------------------------------------

## Ejecuta un bloque de acción «Twitch». Devuelve la salida de flujo que sigue y sus valores.
func exec(id: int, node: Dictionary) -> Dictionary:
	var p: Dictionary = node["params"]
	match str(node["type"]):
		"tw_votacion":
			_open_vote(id, p)
		"tw_cerrar_votacion":
			if _vote_seat.vote != null and _vote_seat.vote.is_open:
				_vote_seat.vote.close()
		"tw_mostrar_chat":
			_chat_style = str(p.get("estilo", "panel lateral"))
			_chat_side = str(p.get("lado", "derecha"))
			_chat_filter = str(p.get("mensajes", "sin comandos"))
			_render_chat()
		"tw_ocultar_chat":
			_chat_style = ""
			_render_chat()
		"tw_alerta":
			var user := LogicRunner._text(runner._value(id, "usuario"))
			var amount := LogicRunner._text(runner._value(id, "cantidad"))
			show_alert(str(p.get("texto", "")).replace("{usuario}", user).replace("{cantidad}", amount), float(p.get("segundos", 4)), str(p.get("sonido", "fanfarria")))
		"tw_meta":
			_show_goal(str(p.get("nombre", "")), LogicRunner._number(runner._value(id, "valor")), maxf(float(p.get("maximo", 100)), 1.0))
		"tw_monedas":
			var user := LogicRunner._text(runner._value(id, "usuario"))
			if not user.is_empty():
				_viewer(user)["coins"] = coins(user) + int(LogicRunner._number(runner._value(id, "cantidad")))
		"tw_equipo":
			var user := LogicRunner._text(runner._value(id, "usuario"))
			if not user.is_empty():
				_viewer(user)["team"] = str(p.get("equipo", "")).strip_edges().to_lower()
		"tw_ficha":
			var user := LogicRunner._text(runner._value(id, "usuario"))
			return {"out": "out", "values": {"pieza": _give_piece(user, str(p.get("etiqueta", ""))) if not user.is_empty() else ""}}
		"tw_recompensa":
			_twitch().call("create_reward", str(p.get("titulo", "")), int(p.get("coste", 100)))
		"tw_escribir":
			_twitch().call("send_chat", LogicRunner._text(runner._value(id, "texto")))
		"tw_si_rol":
			var user := LogicRunner._text(runner._value(id, "usuario"))
			var badges: Array = _viewer(user)["badges"] if not user.is_empty() else []
			return {"out": "si" if _has_role({"badges": badges}, str(p.get("rol", ""))) else "no"}
	return {"out": "out"}


## Calcula un bloque de datos «Twitch».
func compute(id: int, node: Dictionary) -> Variant:
	var p: Dictionary = node["params"]
	match str(node["type"]):
		"tw_da_monedas":
			return float(coins(LogicRunner._text(runner._value(id, "usuario"))))
		"tw_da_equipo":
			var user := LogicRunner._text(runner._value(id, "usuario"))
			return str(_viewer(user)["team"]) if not user.is_empty() else ""
		"tw_da_puntos_equipo":
			return float(team_coins(str(p.get("equipo", "")).strip_edges().to_lower()))
		"tw_da_ranking":
			return ranking(clampi(int(p.get("cuantos", 3)), 1, 20))
		"tw_da_azar":
			var pool := active_viewers(str(p.get("equipo", "")).strip_edges().to_lower())
			return pool[randi() % pool.size()] if not pool.is_empty() else ""
		"tw_da_activos":
			return float(active_viewers().size())
		"tw_da_votos":
			var option := int(p.get("opcion", 1)) - 1
			if _vote_seat.vote == null or option < 0 or option >= _vote_seat.vote.options.size():
				return 0.0
			return float(_vote_seat.vote.counts()[option])
		"tw_da_ficha":
			var user := LogicRunner._text(runner._value(id, "usuario"))
			return str(_viewer(user)["piece"]) if not user.is_empty() else ""
		"tw_da_conectado":
			var twitch := _twitch()
			return twitch != null and bool(twitch.call("is_available"))
	return null


func _open_vote(id: int, p: Dictionary) -> void:
	if _vote_seat.busy:
		editor.call("logic_message", TranslationServer.translate("Ya hay una votación abierta."))
		return
	_vote_times = _vote_times.filter(func(t: float) -> bool: return _now - t < 60.0)
	if _vote_times.size() >= VOTES_PER_MINUTE:
		editor.call("logic_message", TranslationServer.translate("Demasiadas votaciones seguidas: espera un poco."))
		return
	_vote_times.append(_now)
	var labels: Array[String] = []
	for option in str(p.get("opciones", "")).split(",", false):
		if labels.size() < 9 and not option.strip_edges().is_empty():
			labels.append(option.strip_edges())
	if labels.is_empty():
		return
	var targets: Array = []
	var pieces: Variant = runner._value(id, "piezas")
	if pieces is Array:
		for piece: Variant in pieces:
			targets.append(editor.call("_find_piece", str(piece)))
	var name := str(p.get("nombre", ""))
	var twitch := _twitch()
	var previous := int(twitch.get("vote_seconds"))
	twitch.set("vote_seconds", clampi(int(p.get("segundos", 20)), 5, 120))
	_vote_name = name
	_vote_seat.ask(str(p.get("pregunta", "")), labels, targets, func(winner: int) -> void:
		var vote := _vote_seat.last_vote
		var votes := 0.0
		var total := 0.0
		if vote != null and winner >= 0:
			votes = float(vote.counts()[winner])
			total = float(vote.total())
		_fire("tw_ev_votacion", func(params: Dictionary) -> bool: return str(params.get("nombre", "")) == name, {
			"ganadora": float(winner + 1), "opcion": labels[winner] if winner >= 0 else "", "votos": votes, "total": total,
		})
	)
	twitch.set("vote_seconds", previous)
	_relayout_left = 0.1


# --- Chat en pantalla ---------------------------------------------------------------

func _show_message(message: Dictionary, is_command: bool) -> void:
	var twitch := _twitch()
	if twitch != null and bool(twitch.call("is_blocked", str(message.get("text", "")))):
		return
	var entry := message.duplicate()
	entry["command"] = is_command
	entry["born"] = _now
	_messages.append(entry)
	if _messages.size() > 40:
		_messages = _messages.slice(_messages.size() - 40)
	if _chat_style == "bocadillos sobre fichas":
		_bubble(entry)
	_render_chat(entry)


func _visible_messages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in _messages:
		var command := bool(m.get("command", false))
		if (_chat_filter == "sin comandos" and command) or (_chat_filter == "solo comandos" and not command):
			continue
		result.append(m)
	return result


func _bbcode(m: Dictionary) -> String:
	var badges := ""
	var list: Array = m.get("badges", [])
	if "broadcaster" in list:
		badges += "[color=#ff6b5e]★[/color] "
	if "moderator" in list:
		badges += "[color=#2fcf95]M[/color] "
	if "vip" in list:
		badges += "[color=#ff9f43]V[/color] "
	if "subscriber" in list or "founder" in list:
		badges += "[color=#a78bff]S[/color] "
	var text := str(m.get("text", "")).replace("[", "[lb]")
	return "%s[color=%s][b]%s[/b][/color]: %s" % [badges, str(m.get("color", "#a78bff")), str(m.get("name", "")).replace("[", "[lb]"), text]


func _render_chat(newest: Dictionary = {}) -> void:
	if _chat_box != null and _chat_style != "cartas que caen":
		_chat_box.queue_free()
		_chat_box = null
	if _chat_style.is_empty():
		if _chat_box != null:
			_chat_box.queue_free()
			_chat_box = null
		return
	var shown := _visible_messages()
	match _chat_style:
		"panel lateral":
			_chat_box = _panel(Color(Palette.PANEL, 0.92), 16)
			_chat_box.anchor_top = 0.18
			_chat_box.anchor_bottom = 0.82
			_place_side(_chat_box, 320.0)
			# Con una votación abierta en el mismo lado, el chat se coloca debajo de su panel.
			var vote_panel := _vote_seat.find_child("ChatVotePanel", true, false) as Control
			if _chat_side == "derecha" and _vote_seat.busy and vote_panel != null and vote_panel.is_visible_in_tree():
				_chat_box.anchor_top = 0.0
				_chat_box.anchor_bottom = 1.0
				_chat_box.offset_top = vote_panel.get_global_rect().end.y + 12.0
				_chat_box.offset_bottom = -18.0
			var column := _chat_box.get_child(0).get_child(0) as VBoxContainer
			column.alignment = BoxContainer.ALIGNMENT_END
			for m in shown.slice(maxi(shown.size() - MAX_PANEL_MESSAGES, 0)):
				column.add_child(_rich(_bbcode(m), 16, 290))
		"pizarra":
			_chat_box = _panel(Color("2f4a3a"), 10, Color("8a5a2b"), 8)
			_chat_box.anchor_left = 0.5
			_chat_box.anchor_right = 0.5
			_chat_box.offset_left = -260.0
			_chat_box.offset_right = 260.0
			_chat_box.offset_top = 70.0
			var column := _chat_box.get_child(0).get_child(0) as VBoxContainer
			for m in shown.slice(maxi(shown.size() - 5, 0)):
				var line := _rich("[color=#ffe08a]%s[/color]: %s" % [str(m.get("name", "")), str(m.get("text", "")).replace("[", "[lb]")], 20, 500)
				line.add_theme_font_override("normal_font", DISPLAY_FONT)
				line.add_theme_color_override("default_color", Color("f1f5e8"))
				column.add_child(line)
		"marquesina":
			_chat_box = _panel(Palette.INK, 0)
			_chat_box.anchor_left = 0.0
			_chat_box.anchor_right = 1.0
			_chat_box.anchor_top = 1.0
			_chat_box.anchor_bottom = 1.0
			_chat_box.offset_top = -46.0
			_chat_box.clip_contents = true
			var parts: Array[String] = []
			for m in shown.slice(maxi(shown.size() - 6, 0)):
				parts.append(_bbcode(m))
			var line := _rich("      ".join(parts), 18, 4000)
			line.name = "Ticker"
			line.autowrap_mode = TextServer.AUTOWRAP_OFF
			line.fit_content = true
			(_chat_box.get_child(0).get_child(0) as VBoxContainer).add_child(line)
		"solo reacciones":
			_chat_box = VBoxContainer.new()
			_chat_box.anchor_left = 1.0
			_chat_box.anchor_right = 1.0
			_chat_box.anchor_top = 1.0
			_chat_box.anchor_bottom = 1.0
			_chat_box.offset_left = -340.0
			_chat_box.offset_right = -18.0
			_chat_box.offset_top = -220.0
			_chat_box.offset_bottom = -18.0
			(_chat_box as VBoxContainer).alignment = BoxContainer.ALIGNMENT_END
			_chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_layer.add_child(_chat_box)
			for m in shown.filter(func(x: Dictionary) -> bool: return bool(x.get("command", false)) and _now - float(x["born"]) < 3.5).slice(-3):
				var pill := _panel(Palette.LAVENDER, 999)
				pill.get_parent().remove_child(pill)
				_chat_box.add_child(pill)
				(pill.get_child(0).get_child(0) as VBoxContainer).add_child(_label(TranslationServer.translate("%s usa %s") % [str(m.get("name", "")), str(m.get("text", "")).split(" ")[0]], BODY_FONT, 15, Palette.INK))
		"cartas que caen":
			if newest.is_empty() or (_chat_filter == "sin comandos" and bool(newest.get("command", false))) or (_chat_filter == "solo comandos" and not bool(newest.get("command", false))):
				return
			_drop_card(newest)
		"bocadillos sobre fichas":
			pass


func _place_side(box: Control, width: float) -> void:
	if _chat_side == "izquierda":
		box.anchor_left = 0.0
		box.anchor_right = 0.0
		box.offset_left = 18.0
		box.offset_right = 18.0 + width
	else:
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.offset_left = -18.0 - width
		box.offset_right = -18.0


func _drop_card(m: Dictionary) -> void:
	var cards := _layer.get_children().filter(func(n: Node) -> bool: return n.is_in_group("tw_card"))
	while cards.size() >= MAX_CARDS:
		(cards.pop_front() as Node).queue_free()
	var gold := "subscriber" in (m.get("badges", []) as Array)
	var card := _panel(Color(Palette.SUN if gold else Palette.PAPER), 12)
	card.add_to_group("tw_card")
	var viewport := get_viewport().get_visible_rect().size
	card.position = Vector2(randf_range(0.1, 0.7) * viewport.x, -80.0)
	card.custom_minimum_size = Vector2(230, 0)
	card.rotation = randf_range(-0.12, 0.12)
	var text := _rich(_bbcode(m), 15, 210)
	text.add_theme_color_override("default_color", Palette.INK)
	(card.get_child(0).get_child(0) as VBoxContainer).add_child(text)
	var tween := card.create_tween()
	tween.tween_property(card, "position:y", randf_range(0.25, 0.7) * viewport.y, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(12.0)
	tween.tween_property(card, "modulate:a", 0.0, 0.8)
	tween.tween_callback(card.queue_free)


func _bubble(m: Dictionary) -> void:
	var piece := str(_viewer(str(m.get("name", "")))["piece"])
	if piece.is_empty():
		return
	var node: Variant = editor.call("_find_piece", piece)
	if not node is Node3D:
		return
	var label := Label3D.new()
	label.text = str(m.get("text", "")).left(80)
	label.font = BODY_FONT
	label.font_size = 48
	label.pixel_size = 0.0016
	label.outline_size = 16
	label.outline_modulate = Palette.INK
	label.modulate = Palette.PAPER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.width = 600
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(node as Node3D).add_child(label)
	label.position = Vector3.UP * 0.12
	_bubbles.append([label, 4.0])


func _show_help() -> void:
	var lines: Array[String] = []
	for command in commands:
		var usage := str(command["name"])
		match str(command["arg"]):
			"número":
				usage += " %d-%d" % [command["min"], command["max"]]
			"opción":
				usage += " " + "/".join(command["options"] as Array)
			"casilla":
				usage += " A1"
			"jugador":
				usage += " @nombre"
		lines.append(usage + ("  ·  " + str(command["help"]) if not str(command["help"]).is_empty() else ""))
	if not lines.is_empty():
		show_alert(TranslationServer.translate("Comandos") + "\n" + "\n".join(lines), 8.0, "ninguno")


# --- Alertas y meta -----------------------------------------------------------------

func show_alert(text: String, seconds: float, sound: String) -> void:
	if _alert != null:
		_alert.queue_free()
	_alert = _panel(Palette.SUN, 18, Palette.INK, 4)
	_alert.anchor_left = 0.5
	_alert.anchor_right = 0.5
	_alert.offset_left = -280.0
	_alert.offset_right = 280.0
	_alert.offset_top = 230.0
	var label := _label(text, DISPLAY_FONT, 30, Palette.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(_alert.get_child(0).get_child(0) as VBoxContainer).add_child(label)
	_alert.pivot_offset = Vector2(280, 40)
	_alert.scale = Vector2(0.6, 0.6)
	_alert.create_tween().tween_property(_alert, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_alert_left = clampf(seconds, 1.0, 20.0)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null and sound != "ninguno":
		sfx.call("play", "turn" if sound == "fanfarria" else "pop")


func _show_goal(title: String, value: float, maximum: float) -> void:
	if _goal == null:
		_goal = _panel(Palette.PANEL, 14)
		_goal.offset_left = 18.0
		_goal.offset_right = 290.0
		_goal.offset_top = 76.0
		var column := _goal.get_child(0).get_child(0) as VBoxContainer
		_goal_label = _label("", BODY_FONT, 16, Palette.PAPER)
		column.add_child(_goal_label)
		_goal_bar = ProgressBar.new()
		_goal_bar.show_percentage = false
		_goal_bar.custom_minimum_size = Vector2(0, 14)
		_goal_bar.add_theme_stylebox_override("background", _box(Palette.INK, 7))
		_goal_bar.add_theme_stylebox_override("fill", _box(Palette.SUN, 7))
		column.add_child(_goal_bar)
	_goal_label.text = "%s · %d / %d" % [title, int(minf(value, maximum)), int(maximum)]
	_goal_bar.max_value = maximum
	_goal_bar.create_tween().tween_property(_goal_bar, "value", minf(value, maximum), 0.4)


func _process(delta: float) -> void:
	_now += delta
	if _relayout_left > 0.0:
		_relayout_left -= delta
		if _relayout_left <= 0.0:
			_render_chat()
	if _alert != null:
		_alert_left -= delta
		if _alert_left <= 0.0:
			_alert.queue_free()
			_alert = null
	if _chat_style == "marquesina" and _chat_box != null:
		var ticker := _chat_box.find_child("Ticker", true, false) as Control
		if ticker != null:
			_ticker_offset += delta * 90.0
			var width := ticker.size.x + get_viewport().get_visible_rect().size.x
			ticker.position.x = get_viewport().get_visible_rect().size.x - fmod(_ticker_offset, maxf(width, 1.0))
	if _chat_style == "solo reacciones" and _chat_box != null and int(_now * 2.0) != int((_now - delta) * 2.0):
		_render_chat()
	for bubble: Array in _bubbles:
		bubble[1] = float(bubble[1]) - delta
		if float(bubble[1]) <= 0.0 and is_instance_valid(bubble[0]):
			(bubble[0] as Node).queue_free()
	_bubbles = _bubbles.filter(func(b: Array) -> bool: return float(b[1]) > 0.0)


# --- Chat de prueba -----------------------------------------------------------------

## Panel para probar sin estar en directo: escribir como espectador y lanzar eventos.
func _build_test_panel() -> void:
	_test_panel = _panel(Color(Palette.PANEL, 0.95), 14)
	_test_panel.name = "TwitchTestChat"
	_test_panel.anchor_top = 1.0
	_test_panel.anchor_bottom = 1.0
	_test_panel.offset_left = 18.0
	_test_panel.offset_right = 430.0
	_test_panel.offset_top = -196.0
	_test_panel.offset_bottom = -18.0
	_test_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := _test_panel.get_child(0).get_child(0) as VBoxContainer
	column.add_child(_label("Chat de prueba", DISPLAY_FONT, 18, Palette.LAVENDER))
	var who := HBoxContainer.new()
	column.add_child(who)
	var user := LineEdit.new()
	user.name = "TestUser"
	user.text = "pixel_ana"
	user.custom_minimum_size.x = 130
	who.add_child(user)
	var role := OptionButton.new()
	role.name = "TestRole"
	for item in ["espectador", "suscriptor", "VIP", "moderador"]:
		role.add_item(item)
	who.add_child(role)
	var line := HBoxContainer.new()
	column.add_child(line)
	var text := LineEdit.new()
	text.name = "TestText"
	text.placeholder_text = "!ataque 4"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var send := Button.new()
	send.text = "Enviar"
	line.add_child(send)
	var badges_for := func() -> Array[String]:
		var result: Array[String] = []
		match role.selected:
			1: result.append("subscriber")
			2: result.append("vip")
			3: result.append("moderator")
		return result
	var submit := func() -> void:
		if text.text.strip_edges().is_empty():
			return
		_twitch().call("inject", user.text.strip_edges() if not user.text.strip_edges().is_empty() else "pixel_ana", text.text, badges_for.call())
		text.text = ""
	send.pressed.connect(submit)
	text.text_submitted.connect(func(_t: String) -> void: submit.call())
	var events := HFlowContainer.new()
	column.add_child(events)
	var buttons := [
		["100 bits", "bits", {"cantidad": 100}], ["Suscripción", "sub", {"meses": 1, "regalo": false}],
		["Seguidor", "follow", {}], ["Raid de 25", "raid", {"canal": "canal_amigo", "espectadores": 25}],
		["Canje", "canje", {}], ["Hype Train", "hype", {"fase": "empieza", "nivel": 1}], ["Anuncio", "anuncio", {"segundos": 60}],
	]
	for entry: Array in buttons:
		var button := Button.new()
		button.text = str(entry[0])
		button.add_theme_font_size_override("font_size", 12)
		var kind := str(entry[1])
		var payload: Dictionary = entry[2]
		button.pressed.connect(func() -> void:
			var data := payload.duplicate()
			data["usuario"] = user.text.strip_edges()
			if kind == "canje":
				data["recompensa"] = _first_reward()
			_twitch().call("inject_event", kind, data)
		)
		events.add_child(button)


func _first_reward() -> String:
	for node: Dictionary in runner.graph.nodes.values():
		if str(node["type"]) in ["tw_recompensa", "tw_ev_canje"]:
			var p: Dictionary = node["params"]
			return str(p.get("titulo", p.get("recompensa", "")))
	return ""


# --- Utilidades de interfaz ---------------------------------------------------------

func _panel(color: Color, radius: int, border_color := Palette.INK, border := 3) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := _box(color, radius)
	box.set_border_width_all(border)
	box.border_color = border_color
	panel.add_theme_stylebox_override("panel", box)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	_layer.add_child(panel)
	return panel


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


func _rich(text: String, size: int, width: float) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.custom_minimum_size.x = width
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_override("normal_font", BODY_FONT)
	rich.add_theme_font_override("bold_font", BODY_FONT)
	rich.add_theme_font_size_override("normal_font_size", size)
	rich.add_theme_font_size_override("bold_font_size", size)
	rich.add_theme_color_override("default_color", Palette.PAPER)
	rich.text = text
	return rich


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
