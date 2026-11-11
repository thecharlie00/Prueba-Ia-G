class_name BriscaView
extends Node3D
## Mesa de brisca (BriscaRules): mazo con la muestra, la baza en el centro y las cartas del
## rival boca abajo. Tu mano se juega desde el abanico (CardHand): clic para jugar, arrastrar
## para reordenar y «Ordenar» por palo o por número. Contra el bot o contra otra persona en
## el mismo equipo; en ese caso la mano se tapa al cambiar de turno.

const CONFIRM_ACTION := preload("res://scripts/ui/ConfirmAction.gd")
const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const CARD_SCENE := preload("res://scenes/Card3D.tscn")
const DECK_SCENE := preload("res://scenes/Deck3D.tscn")
const MAX_SAVE_BYTES := 20000
## Tiempo que se ve la baza terminada antes de recogerla.
const TRICK_PAUSE := 1.3
const TABLE_Y := 0.86
const NAMES := ["Jugador 1", "Jugador 2"]

@export var save_path := "user://tablerama_brisca.json"

var rules: BriscaRules
var vs_bot := true
var hand: CardHand
var confirm_action: ConfirmAction
var stock_deck: Deck3D
## Jugador cuya mano se ve en el abanico.
var viewer := 0
## Baza terminada que se está enseñando (vacía si no hay ninguna).
var showing: Dictionary = {}
var _show_time := 0.0
var _bot_wait := 0.0
var _table_cards: Array[Card3D] = []

@onready var objects: Node3D = $Objects
@onready var status_label: Label = $UI/Panel/Margin/Content/Status
@onready var help_label: Label = $UI/Panel/Margin/Content/Help
var result_label: Label
var bot_toggle: CheckBox
var online := false
var net_table: BriscaNetTable
var _online_bots: Array[bool] = [false, false]


func _net() -> Node:
	return get_node_or_null("/root/Net")


func _local_seat() -> int:
	var net := _net()
	return int(net.local_seat()) if net != null else -1


func _ready() -> void:
	confirm_action = CONFIRM_ACTION.new()
	add_child(confirm_action)
	rules = BriscaRules.new(randi() % 1000000)
	_make_ui()
	_make_hand()
	stock_deck = DECK_SCENE.instantiate() as Deck3D
	stock_deck.name = "Stock"
	stock_deck.display_name = "Mazo"
	stock_deck.position = Vector3(-1.25, 0.98, 0.0)
	_still(stock_deck)
	objects.add_child(stock_deck)
	TableHud.attach.call_deferred(self)
	_start_online()
	refresh()


func _start_online() -> void:
	var net := _net()
	if net == null or str(net.room_game) != "BriscaOnline":
		return
	if not (Engine.has_singleton("Fusion") and Fusion.is_in_room()):
		return
	online = true
	net_table = BriscaNetTable.new()
	net_table.name = "NetTable"
	net_table.view_node = self
	net_table.brisca = rules
	add_child(net_table)
	if net_table.is_host():
		var rbots: Array = net.room_bots
		_online_bots[0] = rbots.size() > 0 and bool(rbots[0])
		_online_bots[1] = rbots.size() > 1 and bool(rbots[1])
		set_vs_bot(_online_bots[1])
	else:
		set_vs_bot(false)
		if bot_toggle != null:
			bot_toggle.disabled = true
		net_table.request_sync()
	var reset_btn := get_node_or_null("UI/Panel/Margin/Content/Reset") as Button
	if reset_btn != null:
		reset_btn.disabled = true
	var load_btn := get_node_or_null("UI/Panel/Margin/Content/SaveRow/Load") as Button
	if load_btn != null:
		load_btn.disabled = true
	net.player_left.connect(_on_net_player_left)


func _on_net_player_left(player_id: int) -> void:
	if online and net_table != null and net_table.is_host():
		var seat := player_id - 1
		if seat >= 0 and seat < _online_bots.size() and seat != _local_seat():
			_online_bots[seat] = true
			if seat == 1:
				set_vs_bot(true)
			refresh()


func _is_awaiting_sync() -> bool:
	return online and net_table != null and not net_table.synced


func is_local_turn() -> bool:
	if not online:
		return viewer == rules.turn and not is_bot_turn()
	if _is_awaiting_sync():
		return false
	return _local_seat() == rules.turn and not is_bot_turn()


func submit_change(action: Dictionary, acting_seat: int = -1) -> bool:
	if not online or net_table == null:
		return false
	return net_table.submit(action, acting_seat)


func apply_change(change: Dictionary) -> bool:
	if str(change.get("type", "")) != "play":
		return false
	if not showing.is_empty():
		finish_showing()
	var ok := play(str(change.get("card", "")))
	if ok and net_table != null:
		net_table.brisca = rules
	return ok


func sync_from_rules(replayed: BriscaRules) -> void:
	rules = replayed
	showing = {}
	_show_time = 0.0
	hand.set_cards([])
	refresh()


func _make_ui() -> void:
	var content := $UI/Panel/Margin/Content
	result_label = Label.new()
	result_label.name = "Result"
	content.add_child(result_label)
	content.move_child(result_label, status_label.get_index() + 1)
	bot_toggle = CheckBox.new()
	bot_toggle.name = "VsBot"
	bot_toggle.text = "El jugador 2 es un bot"
	bot_toggle.button_pressed = vs_bot
	bot_toggle.toggled.connect(set_vs_bot)
	content.add_child(bot_toggle)
	content.move_child(bot_toggle, $UI/Panel/Margin/Content/Reset.get_index())
	if TableBots.solo:
		# Menú de bots: la mesa empieza en solitario contra el bot.
		TableBots.solo = false
		set_vs_bot(true)
	var save_row := HBoxContainer.new()
	save_row.name = "SaveRow"
	var save := Button.new()
	save.name = "Save"
	save.text = "Guardar partida"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(save_game)
	save_row.add_child(save)
	var load_button := Button.new()
	load_button.name = "Load"
	load_button.text = "Cargar partida"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(load_button)
	content.add_child(save_row)
	content.move_child(save_row, $UI/Panel/Margin/Content/Sandbox.get_index())
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Reset as Button,
		"Nueva partida",
		"Se perderá la partida actual. ¿Continuar?",
		new_game
	)
	confirm_action.bind_button(load_button, "Cargar partida", "La partida actual será sustituida por la guardada. ¿Continuar?", load_game)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Sandbox as Button,
		"Mesa de cartas libre",
		"Se perderá la partida actual. ¿Continuar?",
		_open_card_sandbox
	)


func _open_card_sandbox() -> void:
	if online:
		var net := _net()
		if net != null and net.has_method("leave_room"):
			net.leave_room()
	get_tree().change_scene_to_file("res://scenes/CardTable.tscn")


func _make_hand() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HandLayer"
	layer.layer = 3
	add_child(layer)
	hand = CardHand.new()
	layer.add_child(hand)
	hand.card_played.connect(_on_hand_played)


# Cartas de la mesa: solo se miran, no se cogen ni chocan.
func _still(body: RigidBody3D) -> void:
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	if body is InteractiveTableObject:
		(body as InteractiveTableObject).is_table_locked = true


func set_vs_bot(value: bool) -> void:
	vs_bot = value
	if bot_toggle != null:
		bot_toggle.set_pressed_no_signal(value)
	_bot_wait = 0.0
	refresh()


func new_game() -> void:
	if online:
		help_label.text = "La partida online se sincroniza desde el anfitrión."
		return
	rules = BriscaRules.new(randi() % 1000000)
	showing = {}
	hand.set_cards([])
	refresh()


func is_bot_turn() -> bool:
	if rules.phase != BriscaRules.PLAYING:
		return false
	if online:
		if net_table == null or not net_table.is_host():
			return false
		return (rules.turn == 1 and (vs_bot or _online_bots[1])) or (rules.turn == 0 and _online_bots[0])
	return vs_bot and rules.turn == 1


## Juega una carta del jugador que tiene el turno. Devuelve si se ha jugado.
func play(card: String) -> bool:
	if not showing.is_empty() or not rules.play(card):
		return false
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("card")
	if is_inside_tree():
		var is_trump := card.ends_with(" " + rules.trump_suit)
		var pts := BriscaRules.card_points(card)
		if is_trump or pts >= 10:
			TableVfx.spawn_hero_impact(self, Vector3(0.22, TABLE_Y, 0.0), Palette.SUN, 0.20)
		else:
			TableVfx.spawn_drop(self, Vector3(0.22, TABLE_Y, 0.0), 0.9, Palette.PAPER)
	if rules.trick.is_empty():
		showing = rules.last_trick
		_show_time = TRICK_PAUSE
	_bot_wait = 0.0
	refresh()
	return true


func _on_hand_played(index: int) -> void:
	if index < 0 or index >= hand.cards.size():
		return
	if hand.faces_hidden:
		help_label.text = "Pulsa «Mostrar» para ver tu mano."
		return
	if not is_local_turn():
		help_label.text = "Espera tu turno."
		return
	if not showing.is_empty():
		return
	if online:
		submit_change({"type": "play", "card": hand.cards[index]})
		return
	play(hand.cards[index])


## Termina de enseñar la baza (público para los tests: sin esperar al reloj).
func finish_showing() -> void:
	showing = {}
	_show_time = 0.0
	refresh()


func _process(delta: float) -> void:
	if not showing.is_empty():
		_show_time -= delta
		if _show_time <= 0.0:
			finish_showing()
		return
	if is_bot_turn():
		_bot_wait += delta
		if _bot_wait >= TableBots.think_time(TableBots.difficulty):
			_bot_wait = 0.0
			var bot_seat := rules.turn
			var chosen := TableBots.brisca_choice(rules, TableBots.difficulty)
			if online:
				submit_change({"type": "play", "card": chosen}, bot_seat)
			else:
				play(chosen)


func refresh() -> void:
	if rules == null or hand == null:
		return
	if _is_awaiting_sync():
		hand.set_cards([])
		for card in _table_cards:
			if is_instance_valid(card):
				objects.remove_child(card)
				card.queue_free()
		_table_cards.clear()
		if stock_deck != null:
			stock_deck.visible = false
		result_label.text = "Sincronizando mesa…"
		status_label.text = "Conectando con el anfitrión"
		help_label.text = "Recibiendo reparto y muestra de la sala…"
		return
	var previous_viewer := viewer
	if online:
		var in_room := Engine.has_singleton("Fusion") and Fusion.is_in_room()
		var seat := _local_seat() if in_room else maxi(0, _local_seat())
		viewer = seat if (seat >= 0 and seat < 2 and not _online_bots[seat]) else -1
	else:
		viewer = 0 if vs_bot else (rules.turn if rules.phase == BriscaRules.PLAYING else viewer)
	_sync_hand(previous_viewer != viewer)
	_sync_table()
	var trump: String = BriscaRules.SUIT_NAMES[rules.trump_suit]
	result_label.text = "J1 %d · %s %d · triunfo: %s" % [
		rules.points[0], "Bot" if vs_bot else "J2", rules.points[1], trump
	]
	if rules.phase == BriscaRules.FINISHED:
		if rules.result == BriscaRules.DRAW:
			status_label.text = "Empate a 60."
		else:
			status_label.text = "Gana %s con %d puntos." % [_name(rules.result), rules.points[rules.result]]
		help_label.text = "«Nueva partida» para repartir otra vez."
	elif not showing.is_empty():
		status_label.text = "Baza para %s (+%d)" % [_name(int(showing["winner"])), int(showing["points"])]
	else:
		status_label.text = "Turno del bot" if is_bot_turn() else "Turno de %s" % _name(rules.turn)
		var on_table := rules.card_to_beat()
		if is_bot_turn():
			help_label.text = "El bot está pensando…"
		elif online and not is_local_turn():
			help_label.text = "Esperando a %s…" % _name(rules.turn)
		elif on_table.is_empty():
			help_label.text = "Sales tú: juega cualquier carta. Triunfo: %s." % trump
		else:
			help_label.text = "Hay que superar el %s; no hace falta asistir." % BriscaRules.card_name(on_table)


func _name(player: int) -> String:
	return "el bot" if player == 1 and vs_bot else NAMES[player]


# Mano del abanico: conserva el orden que haya puesto el jugador y añade las nuevas al final.
func _sync_hand(changed_player: bool) -> void:
	if viewer < 0 or viewer >= rules.hands.size():
		if not hand.cards.is_empty():
			hand.set_cards([])
		return
	var cards: Array = rules.hands[viewer]
	var kept: Array[String] = []
	if not changed_player:
		for card in hand.cards:
			if card in cards:
				kept.append(card)
	for card in cards:
		if card not in kept:
			kept.append(card)
	if kept != hand.cards:
		hand.set_cards(kept)
	if online:
		if hand.faces_hidden:
			hand.set_faces_hidden(false)
	# Dos personas en el mismo equipo: la mano se tapa al cambiar de jugador.
	elif changed_player and not vs_bot:
		hand.set_faces_hidden(true)
	elif vs_bot and hand.faces_hidden:
		hand.set_faces_hidden(false)


func _sync_table() -> void:
	for card in _table_cards:
		if is_instance_valid(card):
			objects.remove_child(card)
			card.queue_free()
	_table_cards.clear()
	# Mazo y muestra (la muestra se ve atravesada bajo el mazo hasta que se roba).
	var hidden_stock := rules.stock.size() - (1 if rules.trump_card in rules.stock else 0)
	stock_deck.visible = hidden_stock > 0
	stock_deck.cards_remaining = hidden_stock
	stock_deck.display_name = "Mazo · quedan %d" % rules.stock.size()
	if rules.trump_card in rules.stock:
		var trump := _place(rules.trump_card, Vector3(-0.92, TABLE_Y, 0.0), true)
		trump.rotation_degrees.y = 90
		trump.name = "Trump"
	# Baza: la que está en juego o la que se acaba de ganar.
	var trick: Array = showing.get("cards", rules.trick)
	for play_item in trick:
		var player: int = play_item["player"]
		var spot := Vector3(0.1, TABLE_Y + 0.01 * _table_cards.size(), 0.4) if player == 0 else Vector3(0.35, TABLE_Y + 0.01 * _table_cards.size(), -0.4)
		var card := _place(play_item["card"], spot, true)
		card.rotation_degrees.y = -8 if player == 0 else 10
		card.name = "Trick%d" % player
	# Cartas del rival o bot: siempre boca abajo mostrando únicamente el dorso.
	var other := 1 - clampi(viewer, 0, 1)
	for i in rules.hands[other].size():
		var back := _place("", Vector3(-0.55 + i * 0.55, TABLE_Y, -1.35), false)
		back.name = "Rival%d" % i


func _place(label: String, spot: Vector3, face_up: bool) -> Card3D:
	var card := CARD_SCENE.instantiate() as Card3D
	_still(card)
	card.position = spot
	if not face_up:
		card.rotation_degrees.z = 180
	objects.add_child(card)
	if face_up:
		card.set_card_label(label)
	else:
		card.set_concealed(true)
	_table_cards.append(card)
	return card


func table_cards() -> Array[Card3D]:
	return _table_cards


# --- Guardar y cargar --------------------------------------------------------

func save_game() -> bool:
	var record := {"game": "brisca_table", "version": 1, "vs_bot": vs_bot, "rules": rules.export_record()}
	var ok := SAVE_STORE.write(save_path, JSON.stringify(record), MAX_SAVE_BYTES, _decode_save)
	help_label.text = "Partida guardada en este equipo." if ok else "No se pudo guardar; comprueba el espacio."
	return ok


func load_game() -> bool:
	if online:
		help_label.text = "La partida online se sincroniza desde el anfitrión; el guardado local no se usa."
		return false
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, _decode_save)
	if loaded.is_empty():
		help_label.text = "Guardado ausente o inválido; se conserva la partida."
		return false
	var record: Dictionary = loaded["record"]
	rules = BriscaRules.from_record(record["rules"])
	showing = {}
	hand.set_cards([])
	set_vs_bot(bool(record["vs_bot"]))
	help_label.text = "Partida cargada."
	return true


static func _decode_save(record: Variant) -> Variant:
	if not record is Dictionary or record.get("game") != "brisca_table":
		return null
	var version: Variant = record.get("version")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version != 1:
		return null
	if not record.get("vs_bot") is bool or BriscaRules.from_record(record.get("rules")) == null:
		return null
	return record


# --- Interfaz integrada (TableHud) --------------------------------------------

func hud_seats() -> Array:
	return [
		{"name": NAMES[0], "color": Palette.PLAYER_RED, "bot": false, "side": "south"},
		{"name": "Bot" if vs_bot else NAMES[1], "color": Palette.PLAYER_BLUE, "bot": vs_bot, "side": "north"},
	]


func hud_active_seat() -> int:
	if rules.phase == BriscaRules.PLAYING:
		return rules.turn
	return rules.result if rules.result in [0, 1] else -1


func hud_seat_status(index: int) -> String:
	return "%d puntos" % rules.points[index]


func hud_seat_cards(index: int) -> int:
	if index < 0 or index >= rules.hands.size() or index == viewer:
		return 0
	return rules.hands[index].size()
