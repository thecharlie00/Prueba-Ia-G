extends SceneTree
## Verifica tirada 3D visible + resultado claro (bots y multijugador), privacidad estricta
## de manos ajenas (bots y multijugador) y ausencia de la pestaña «RECURSOS · J1».

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_island_bots_and_resource_tab()
	await _test_island_online_dice_and_privacy()
	await _test_ludo_bots_and_online_dice()
	await _test_domino_bots_and_online_privacy()
	await _test_brisca_bots_and_online_privacy()
	if failures > 0:
		printerr("dice_hand_privacy: %d errores" % failures)
		quit(1)
	else:
		print("dice_hand_privacy: ok")
		quit(0)


func _test_island_bots_and_resource_tab() -> void:
	TableBots.solo = true
	var view := (load("res://scenes/Island.tscn") as PackedScene).instantiate() as IslandView
	root.add_child(view)
	await _frames(4)
	var resource_tab := view.get_node("IslandUI/ResourceHand") as Control
	_check(
		resource_tab != null and not resource_tab.visible and not view.hand_heading.visible,
		"Isla oculta permanentemente la pestaña RECURSOS · J1 al iniciar"
	)
	_check(
		not view.bots[0] and view.bots[1] and view.bots[2],
		"Isla contra bots asigna J1 humano y J2/J3 bots"
	)
	# Dar recursos distintos a J1 y al bot J2 para comprobar aislamiento estricto de manos.
	view.rules.resources[0] = [2, 0, 0, 0, 0]
	view.rules.resources[1] = [0, 0, 0, 0, 4]
	view.rules.dev_ready[0][IslandRules.KNIGHT] = 1
	view.rules.dev_ready[1][IslandRules.MONOPOLY_CARD] = 2
	view.rules.phase = IslandRules.ACTION
	view.rules.turn = 1
	view._refresh()
	_check(
		not resource_tab.visible and view._active_hand_player() == 0,
		"En turno del bot J2 el jugador solo ve su propia mano (J1) y sin pestaña de recursos"
	)
	var ore_cards := view.hand3d.items.filter(
		func(it: Dictionary) -> bool: return int(it.get("resource", -1)) == 4
	).size()
	var wood_cards := view.hand3d.items.filter(
		func(it: Dictionary) -> bool: return int(it.get("resource", -1)) == 0
	).size()
	_check(
		ore_cards == 0 and wood_cards == 2 and not view.dev_status.text.contains("Monopolio 2"),
		"Isla contra bots nunca expone recursos ni cartas de desarrollo del bot"
	)
	# Tampoco durante fases especiales del bot (DISCARD, PLENTY, TRADE_RESPONSE).
	view.rules.phase = IslandRules.DISCARD
	view.rules.discard_player = 1
	view.rules.discard_due = [0, 2, 0]
	view._refresh()
	_check(
		view._active_hand_player() == 0 and not resource_tab.visible,
		"Descarte del bot J2 no cambia la mano visible a la del bot"
	)
	view.rules.phase = IslandRules.PLENTY
	view.rules.turn = 1
	view._refresh()
	_check(
		view.hand3d.items.size() == 3 and wood_cards == 2,
		"Abundancia del bot J2 no muestra selector en la mano de J1"
	)
	# Tirada 3D del bot: los dados ruedan físicamente a su cara y muestran el resultado.
	view.rules.phase = IslandRules.ROLL
	view.rules.turn = 1
	view._refresh()
	view._bot_roll(1)
	_check(
		view.waiting_roll
		and view.dice[0].is_forced_rolling()
		and view.dice[1].is_forced_rolling()
		and view.dice_banner.visible
		and view.rules.phase == IslandRules.ROLL,
		"El bot en Isla lanza los dados 3D visiblemente antes de resolver el turno"
	)
	for step in 12:
		view._process(0.08)
	await physics_frame
	await process_frame
	var a := view.dice[0].top_face()
	var b := view.dice[1].top_face()
	_check(
		not view.waiting_roll
		and view.rules.last_dice == Vector2i(a, b)
		and is_instance_valid(view.dice[0]._pop)
		and is_instance_valid(view.dice[1]._pop)
		and view.dice_banner.visible
		and view.dice_banner_label.text.contains("%d + %d = %d" % [a, b, a + b]),
		"Al posarse los dados del bot se muestra el resultado en DicePop y DiceBanner"
	)
	view.queue_free()
	await _frames(3)


func _test_island_online_dice_and_privacy() -> void:
	var view := (load("res://scenes/IslandTwo.tscn") as PackedScene).instantiate() as IslandView
	root.add_child(view)
	await _frames(4)
	view.online = true
	view._suppress_roll_anim = false
	var inet := IslandNetTable.new()
	inet.view_node = view
	inet.island = view.rules
	view.net_table = inet
	view.add_child(inet)
	for step in range(4):
		for v in range(view.rules.board.vertices.size()):
			if view.rules.can_settlement(v):
				view.rules.place_settlement(v)
				break
		for e in range(view.rules.board.edges.size()):
			if view.rules.can_road(e):
				view.rules.place_road(e)
				break
	view.rules.resources[0] = [1, 0, 0, 0, 0]
	view.rules.resources[1] = [0, 3, 0, 0, 0]
	view.rules.turn = 1
	view._refresh()
	_check(
		view._active_hand_player() == 0
		and view.hand3d.items.size() == 1
		and not (view.get_node("IslandUI/ResourceHand") as Control).visible,
		"Isla online mantiene visible solo la mano propia (J1) cuando es turno de J2"
	)
	_check(
		view.apply_change({"type": "roll", "a": 3, "b": 5, "seat": 1}),
		"Isla online acepta evento de tirada remota de J2"
	)
	_check(
		view.waiting_roll
		and not view.status.text.contains("3 + 5")
		and view.dice_banner.visible
		and view.dice_banner_label.text.contains("J2"),
		"Isla online no adelanta el resultado en texto mientras los dados 3D están rodando"
	)
	for step in 12:
		for d in view.dice:
			d._process(0.08)
		view._physics_process(0.05)
	await physics_frame
	await process_frame
	_check(
		not view.waiting_roll
		and view.dice[0].top_face() == 3
		and view.dice[1].top_face() == 5
		and view.dice_banner.visible
		and view.dice_banner_label.text.contains("3 + 5 = 8"),
		"Isla online revela el resultado 3 + 5 = 8 en dados 3D y banner al aterrizar"
	)
	view.queue_free()
	await _frames(3)


func _test_ludo_bots_and_online_dice() -> void:
	var view := (load("res://scenes/Parchis2.tscn") as PackedScene).instantiate() as LudoView
	root.add_child(view)
	await _frames(4)
	view.online = true
	view._suppress_roll_anim = false
	view.rules.turn = 1
	_check(
		view.apply_change({"type": "roll", "value": 5, "seat": 1}),
		"Parchís online inicia tirada remota de J2 con 5"
	)
	_check(
		view.waiting_roll
		and not view.status.text.contains("dado 5")
		and view.token_buttons[0].disabled
		and not view.markers[0].visible
		and view.dice_banner.visible,
		"Parchís online bloquea fichas y oculta el valor mientras el dado 3D sigue en el aire"
	)
	for step in 12:
		view._process(0.08)
	await physics_frame
	await process_frame
	_check(
		not view.waiting_roll
		and view.die.top_face() == 5
		and is_instance_valid(view.die._pop)
		and view.die._pop.text_value == 5
		and view.dice_banner.visible
		and view.dice_banner_label.text.contains("sacó 5"),
		"Parchís online muestra cara 5, DicePop y DiceBanner al posarse el dado"
	)
	view.queue_free()
	await _frames(3)


func _test_domino_bots_and_online_privacy() -> void:
	TableBots.solo = true
	var view := (load("res://scenes/GuidedDomino.tscn") as PackedScene).instantiate() as GuidedDomino
	root.add_child(view)
	await _frames(4)
	_check(view.bot_enabled, "Dominó contra bots activa bot en J2")
	var visible_pips := 0
	var hidden_tiles := 0
	for tile in view.tiles:
		var pips := tile.get_node_or_null("Visual/Pips") as Node3D
		if pips != null and pips.visible:
			visible_pips += 1
			_check(
				view.rules.hands[0].has(int(view.tile_ids[tile])),
				"Dominó contra bots solo enseña puntos de fichas de la mano propia"
			)
		elif tile.display_name == "Dominó oculto":
			hidden_tiles += 1
	_check(
		visible_pips == 7 and hidden_tiles == 21,
		"Dominó contra bots muestra 7 fichas propias y oculta las 21 del bot y del pozo"
	)
	# Incluso al terminar la partida las fichas no jugadas del rival siguen ocultas.
	view.rules.result = DominoRules.PLAYER_1_WINS
	view._refresh()
	var bot_tile_id := int(view.rules.hands[1][0])
	for tile in view.tiles:
		if int(view.tile_ids[tile]) == bot_tile_id:
			var pips := tile.get_node_or_null("Visual/Pips") as Node3D
			_check(
				pips != null and not pips.visible and tile.display_name == "Dominó oculto",
				"Dominó no revela la mano restante del bot ni al acabar la partida"
			)
	view.queue_free()
	await _frames(3)


func _test_brisca_bots_and_online_privacy() -> void:
	for mode_online in [false, true]:
		var view := (load("res://scenes/Brisca.tscn") as PackedScene).instantiate() as BriscaView
		root.add_child(view)
		await _frames(4)
		if mode_online:
			view.online = true
			view.set_vs_bot(false)
			var bnet := BriscaNetTable.new()
			bnet.view_node = view
			bnet.brisca = view.rules
			view.net_table = bnet
			view.add_child(bnet)
		else:
			view.set_vs_bot(true)
		view.rules.turn = 1
		view.refresh()
		for c in view.hand.cards:
			_check(
				c in view.rules.hands[0] and c not in view.rules.hands[1],
				"Brisca (%s) solo incluye cartas de J1 en el abanico propio"
				% ("online" if mode_online else "bots")
			)
		var rivals: Array = view.table_cards().filter(
			func(card: Card3D) -> bool: return String(card.name).begins_with("Rival")
		)
		_check(rivals.size() == 3, "Brisca muestra 3 dorsos del rival")
		for rival_item in rivals:
			var rival := rival_item as Card3D
			_check(
				rival != null
				and rival.concealed
				and rival.card_label.is_empty()
				and rival.display_name == "Carta oculta",
				"Brisca (%s) no filtra etiqueta ni cara en las cartas boca abajo del rival"
				% ("online" if mode_online else "bots")
			)
		view.queue_free()
		await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FALLO: " + message)
