extends SceneTree
## Verifica «El chat juega»: lectura de mensajes de EventSub, moderación, votaciones y el
## asiento del chat en Parchís y Brisca con el chat simulado.

var _failures := 0
var _messages: Array = []
var _moderated: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var twitch: Node = root.get_node("Twitch")
	twitch.chat_message.connect(func(m: Dictionary) -> void: _messages.append(m))
	twitch.moderation.connect(func(id: String, user: String) -> void: _moderated.append([id, user]))

	# Mensaje de EventSub tal como lo manda Twitch.
	twitch.handle_eventsub(JSON.stringify({
		"metadata": {"message_type": "notification"},
		"payload": {
			"subscription": {"type": "channel.chat.message"},
			"event": {
				"chatter_user_id": "42", "chatter_user_login": "pixel_ana", "chatter_user_name": "Pixel_Ana",
				"message_id": "abc", "color": "#FF0000",
				"badges": [{"set_id": "subscriber", "id": "12", "info": "12"}],
				"message": {"text": " !2 ", "fragments": [{"type": "text", "text": "!2 "}, {"type": "emote", "text": "Kappa", "emote": {"id": "25"}}]},
			},
		},
	}))
	_check(_messages.size() == 1, "un mensaje de EventSub llega al juego")
	if _messages.size() == 1:
		var m: Dictionary = _messages[0]
		_check(m["name"] == "Pixel_Ana" and m["user_id"] == "42" and m["text"] == "!2", "nombre, usuario y texto normalizados")
		_check("subscriber" in (m["badges"] as Array), "insignias")
		_check((m["emotes"] as Array).size() == 1, "emotes")
	twitch.handle_eventsub(JSON.stringify({"metadata": {"message_type": "notification"}, "payload": {"subscription": {"type": "channel.chat.message"}, "event": {"chatter_user_id": "42", "message_id": "abc", "message": {"text": "!2"}}}}))
	_check(_messages.size() == 1, "un mensaje repetido no se procesa dos veces")
	twitch.handle_eventsub(JSON.stringify({"metadata": {"message_type": "notification"}, "payload": {"subscription": {"type": "channel.chat.message_delete"}, "event": {"message_id": "abc", "target_user_id": "42"}}}))
	_check(_moderated.size() == 1 and _moderated[0][0] == "abc", "un mensaje borrado avisa a las votaciones")

	# Votaciones.
	var labels: Array[String] = ["A", "B", "C"]
	var vote := VoteRound.new(labels, 5.0)
	vote.open()
	_check(not vote.feed({"user_id": "1", "id": "m1", "text": "hola"}), "un mensaje normal no es un voto")
	_check(not vote.feed({"user_id": "1", "id": "m2", "text": "!7"}), "una opción que no existe no cuenta")
	vote.feed({"user_id": "1", "id": "m3", "text": "!1", "name": "uno"})
	vote.feed({"user_id": "2", "id": "m4", "text": "!2", "name": "dos"})
	vote.feed({"user_id": "3", "id": "m5", "text": "!2 vamos", "name": "tres"})
	_check(vote.leader() == 1, "gana la más votada")
	vote.feed({"user_id": "3", "id": "m6", "text": "!1", "name": "tres"})
	_check(vote.total() == 3 and vote.counts() == [2, 1, 0], "cuenta el último voto de cada persona")
	vote.moderate("m6", "")
	_check(vote.total() == 2, "un mensaje borrado pierde su voto")
	vote.moderate("", "1")
	_check(vote.total() == 1 and vote.leader() == 1, "un usuario limpiado pierde su voto")
	var tie := VoteRound.new(labels, 5.0)
	tie.open()
	tie.feed({"user_id": "1", "id": "t1", "text": "!3"})
	tie.feed({"user_id": "2", "id": "t2", "text": "!1"})
	_check(tie.leader() == 2, "en empate gana la que recibió antes su voto")
	var empty := VoteRound.new(labels, 1.0)
	empty.open()
	empty.tick(2.0)
	_check(not empty.is_open and empty.winner == -1, "sin votos, nadie gana (juega el bot)")

	# Parchís con el chat simulado en el último asiento.
	twitch.set_simulated(true, false)
	twitch.vote_seconds = 2
	TableBots.solo = true
	TableBots.chat_plays = true
	change_scene_to_file("res://scenes/Parchis2.tscn")
	for i in 5:
		await process_frame
	var ludo: Node = current_scene
	var seat: ChatSeat = ludo.get("chat_seat")
	_check(seat != null and seat.seat == 1, "el chat se sienta en el último asiento de Parchís")
	if seat != null:
		ludo.call("set_bot", true, 0)
		var decisions := {"count": 0, "voted": 0}
		seat.finished.connect(func(winner: int) -> void:
			decisions["count"] += 1
			if winner >= 0 and seat.vote == null:
				decisions["voted"] += 1
		)
		var saw_panel := false
		for i in 6000:
			await physics_frame
			if seat.vote != null and seat.vote.is_open:
				saw_panel = saw_panel or (seat.get_node("CanvasLayer/ChatVotePanel") as Control).visible if seat.has_node("CanvasLayer/ChatVotePanel") else saw_panel
			if int(decisions["count"]) >= 6:
				break
		_check(int(decisions["count"]) >= 6, "el chat decide varios turnos de Parchís (%d)" % int(decisions["count"]))
	twitch.set_simulated(false, false)

	# Brisca: el chat juega como segundo jugador.
	twitch.set_simulated(true, false)
	TableBots.solo = true
	TableBots.chat_plays = true
	change_scene_to_file("res://scenes/Brisca.tscn")
	for i in 5:
		await process_frame
	var brisca: Node = current_scene
	var brisca_seat: ChatSeat = brisca.get("chat_seat")
	_check(brisca_seat != null and brisca_seat.seat == 1, "el chat se sienta en Brisca")
	if brisca_seat != null:
		var plays := {"count": 0}
		brisca_seat.finished.connect(func(_w: int) -> void: plays["count"] += 1)
		for i in 4000:
			await process_frame
			var rules: BriscaRules = brisca.get("rules")
			if rules.phase == BriscaRules.PLAYING and rules.turn == 0 and (brisca.get("showing") as Dictionary).is_empty():
				for card: Variant in rules.hands[0]:
					if rules.can_play(str(card)):
						brisca.call("play", str(card))
						break
			if int(plays["count"]) >= 3:
				break
		_check(int(plays["count"]) >= 3, "el chat juega cartas en Brisca (%d)" % int(plays["count"]))
	twitch.set_simulated(false, false)


	# Damas, dominó e isla: el chat decide; el otro asiento lo mueve el bot desde el test.
	for case in [
		["res://scenes/GuidedPhysicalCheckers.tscn", "damas"],
		["res://scenes/GuidedDomino.tscn", "dominó"],
		["res://scenes/IslandTwo.tscn", "isla"],
	]:
		twitch.set_simulated(true, false)
		TableBots.solo = true
		TableBots.chat_plays = true
		change_scene_to_file(str(case[0]))
		for i in 5:
			await process_frame
		var view: Node = current_scene
		var chat: ChatSeat = view.get("chat_seat")
		_check(chat != null, "el chat se sienta en %s" % case[1])
		if chat == null:
			continue
		if view.has_method("set_bot"):
			view.call("set_bot", true, 0)
		var done := {"count": 0}
		chat.finished.connect(func(_w: int) -> void: done["count"] += 1)
		for i in 9000:
			await physics_frame
			if not view.has_method("set_bot"):
				var rules: Variant = view.get("rules")
				var my_turn := false
				if rules is CheckersRules:
					my_turn = (rules as CheckersRules).turn == CheckersRules.WHITE and (rules as CheckersRules).status() == "playing"
				elif rules is DominoRules:
					my_turn = (rules as DominoRules).turn == 0 and (rules as DominoRules).result == DominoRules.PLAYING
				if my_turn and i % 20 == 0:
					view.call("bot_step")
			if int(done["count"]) >= 4:
				break
		_check(int(done["count"]) >= 4, "el chat decide en %s (%d)" % [case[1], int(done["count"])])
		twitch.set_simulated(false, false)

	if _failures > 0:
		push_error("twitch_chat: %d fallos" % _failures)
		quit(1)
	else:
		print("twitch_chat: OK")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		printerr("  FALLO  ", label)
