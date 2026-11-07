class_name CardTable
extends Node3D

const CONFIRM_ACTION := preload("res://scripts/ui/ConfirmAction.gd")

const DECK_SCENE := preload("res://scenes/Deck3D.tscn")
const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const MAX_SAVE_BYTES := SandboxPersistence.MAX_BYTES
const ENGLISH_NAME := "Baraja_inglesa"
const SPANISH_NAME := "Baraja_española"

@export var save_path := "user://diceon_cards.json"

var confirm_action: ConfirmAction
var english: Deck3D
var spanish: Deck3D
var hand: CardHand

@onready var objects: Node3D = $Objects
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D
@onready var status_label: Label = $UI/Panel/Margin/Content/Status


func _ready() -> void:
	TableHud.attach.call_deferred(self)
	confirm_action = CONFIRM_ACTION.new()
	add_child(confirm_action)
	english = _make_deck("Baraja inglesa", _english_cards(), Vector3(-1.4, 1.05, -1.3))
	spanish = _make_deck("Baraja española", _spanish_cards(), Vector3(1.4, 1.05, -1.3))
	_make_hand()
	grabber.selection_changed.connect(_on_selection_changed)
	grabber.placement_message.connect(_on_placement_message)
	grabber.grab_finished.connect(_on_grab_finished)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Reset as Button,
		"Reiniciar mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_reset,
		_can_store
	)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Sandbox as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_open_sandbox,
		_can_store
	)
	$UI/Panel/Margin/Content/English/Shuffle.pressed.connect(_shuffle.bind(true))
	$UI/Panel/Margin/Content/English/Draw.pressed.connect(_draw.bind(true))
	$UI/Panel/Margin/Content/Spanish/Shuffle.pressed.connect(_shuffle.bind(false))
	$UI/Panel/Margin/Content/Spanish/Draw.pressed.connect(_draw.bind(false))
	$UI/Panel/Margin/Content/SaveRow/Save.pressed.connect(_save_game)
	_add_hand_button($UI/Panel/Margin/Content/English, "Mano inglesa", true)
	_add_hand_button($UI/Panel/Margin/Content/Spanish, "Mano española", false)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/SaveRow/Load as Button,
		"Cargar mesa",
		"La partida actual será sustituida por el guardado local. ¿Continuar?",
		_load_game,
		_can_store
	)


func _make_deck(title: String, cards: Array[String], position: Vector3) -> Deck3D:
	var deck := DECK_SCENE.instantiate() as Deck3D
	deck.name = title.replace(" ", "_")
	deck.display_name = title + " · N para robar"
	deck.initial_cards = cards
	deck.spread_draws = true
	deck.draw_offset = Vector3(0, 0.65, 1.0)
	deck.position = position
	objects.add_child(deck)
	_connect_deck(deck)
	return deck


static func _english_cards() -> Array[String]:
	var cards: Array[String] = []
	for suit in ["♠", "♥", "♦", "♣"]:
		for rank in ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]:
			cards.append(rank + " " + suit)
	return cards


static func _spanish_cards() -> Array[String]:
	var cards: Array[String] = []
	for suit in ["O", "C", "E", "B"]:
		for rank in ["1", "2", "3", "4", "5", "6", "7", "10", "11", "12"]:
			cards.append(rank + " " + suit)
	return cards


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_B and event.keycode != KEY_M:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	var focus_control := get_viewport().gui_get_focus_owner()
	if focus_control is LineEdit or focus_control is TextEdit:
		return
	if get_viewport().gui_get_hovered_control() != null or is_instance_valid(grabber.held):
		return
	if grabber._pending_press or not grabber.hovered is Card3D:
		return
	if event.keycode == KEY_M:
		take_to_hand(grabber.hovered as Card3D)
	else:
		_return_card(grabber.hovered as Card3D)
	get_viewport().set_input_as_handled()


# --- Mano -------------------------------------------------------------------

func _make_hand() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HandLayer"
	layer.layer = 3
	add_child(layer)
	hand = CardHand.new()
	layer.add_child(hand)
	hand.card_played.connect(play_from_hand)


func _add_hand_button(row: Node, label: String, is_english: bool) -> void:
	var button := Button.new()
	button.name = "ToHand"
	button.text = label
	button.tooltip_text = "Roba la carta de arriba directamente a tu mano"
	button.pressed.connect(draw_to_hand.bind(is_english))
	row.add_child(button)


## Roba la carta de arriba del mazo a la mano, sin pasar por la mesa.
func draw_to_hand(is_english: bool) -> bool:
	var deck := english if is_english else spanish
	if not is_instance_valid(deck) or deck._cards.is_empty():
		status_label.text = "No quedan cartas en esa baraja."
		return false
	if deck.is_grabbed or deck.freeze:
		status_label.text = "Suelta o desbloquea la baraja antes de robar."
		return false
	hand.add(deck._cards.pop_back())
	deck.cards_remaining = deck._cards.size()
	status_label.text = "Carta a tu mano · quedan %d en %s." % [deck.cards_remaining, deck.display_name.get_slice(" · ", 0)]
	return true


## Recoge una carta de la mesa a la mano (tecla M sobre la carta).
func take_to_hand(card: Card3D) -> bool:
	if not is_instance_valid(card) or card.get_parent() != objects:
		return false
	if card.freeze or card.is_grabbed:
		status_label.text = "Suelta o desbloquea la carta antes de cogerla."
		return false
	_forget(card)
	objects.remove_child(card)
	card.queue_free()
	hand.add(card.card_label)
	status_label.text = "%s a tu mano." % card.card_label
	return true


## Juega una carta de la mano boca arriba delante del jugador.
func play_from_hand(index: int) -> Card3D:
	var label := hand.take(index)
	if label.is_empty():
		return null
	var card := (english.card_scene if is_instance_valid(english) else load("res://scenes/Card3D.tscn")).instantiate() as Card3D
	objects.add_child(card)
	card.set_card_label(label)
	var played := objects.get_children().filter(func(node: Node) -> bool: return node is Card3D).size()
	card.global_position = Vector3(-1.2 + (played % 6) * 0.48, 1.25 + (played / 6) * 0.06, 1.05)
	status_label.text = "Juegas %s." % label
	return card


func _forget(card: Card3D) -> void:
	if grabber.hovered == card:
		card.set_hovered(false)
		grabber.hovered = null
	if grabber.last_selected == card:
		grabber.last_selected = null
	if grabber._pending_recovery == card:
		grabber._pending_recovery = null


# Acción explícita y solo en esta mesa libre; devuelve al fondo, sin mezclar.
func _return_card(card: Card3D) -> bool:
	if not is_instance_valid(card) or card.get_parent() != objects:
		return false
	if card.freeze or card.is_grabbed:
		status_label.text = "Suelta o desbloquea la carta antes de devolverla."
		return false
	var deck: Deck3D
	if card.card_label in _english_cards():
		deck = english
	elif card.card_label in _spanish_cards():
		deck = spanish
	if not is_instance_valid(deck) or deck.freeze or deck.is_grabbed:
		status_label.text = "Desbloquea y suelta la baraja antes de devolver la carta."
		return false
	if card.card_label in deck._cards:
		status_label.text = "No se puede devolver una carta duplicada."
		return false
	deck._cards.push_front(card.card_label)
	deck.cards_remaining = deck._cards.size()
	if grabber.hovered == card:
		card.set_hovered(false)
		grabber.hovered = null
	if grabber.last_selected == card:
		grabber.last_selected = null
	if grabber._pending_recovery == card:
		grabber._pending_recovery = null
	objects.remove_child(card)
	card.queue_free()
	status_label.text = (
		"Carta al fondo de %s · quedan %d." % [deck.display_name, deck.cards_remaining]
	)
	return true


func _connect_deck(deck: Deck3D) -> void:
	deck.card_drawn.connect(_on_draw.bind(deck))
	deck.deck_shuffled.connect(_on_shuffle.bind(deck))


func _draw(is_english: bool) -> void:
	var deck := english if is_english else spanish
	if is_instance_valid(deck):
		deck.draw_card()


func _shuffle(is_english: bool) -> void:
	var deck := english if is_english else spanish
	if is_instance_valid(deck):
		deck.shuffle_deck()


func _can_store() -> bool:
	if is_instance_valid(grabber.held) or grabber._pending_press:
		status_label.text = "Suelta la pieza antes de guardar o cargar."
		return false
	for object in objects.get_children():
		if (
			object is InteractiveTableObject
			and (object.is_grabbed or (object.freeze and not object.is_table_locked))
		):
			status_label.text = "Espera a que termine el volteo antes de guardar o cargar."
			return false
	return true


func _save_game() -> void:
	if not _can_store():
		return
	var table := SandboxPersistence.snapshot(objects, false)
	var record := {"game": "card_table", "version": 2, "table": table, "hand": hand.cards.duplicate()}
	if SAVE_STORE.write(save_path, JSON.stringify(record), MAX_SAVE_BYTES, _decode_save):
		status_label.text = "Mesa de cartas guardada en este dispositivo."
	else:
		status_label.text = "No se pudo guardar la mesa de cartas."


func _load_game() -> void:
	if not _can_store():
		return
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, _decode_save)
	if loaded.is_empty():
		status_label.text = "Guardado ausente o inválido; se conserva la mesa actual."
		return
	var record: Dictionary = loaded["record"]["table"]
	var pieces := SandboxPersistence.instantiate_pieces(record)
	if pieces.size() != record["objects"].size():
		status_label.text = "No se pudieron reconstruir las cartas; se conserva la mesa."
		return
	# El formato ya garantiza exactamente los dos mazos antes de reemplazar la escena.
	grabber.clear_movement_undo()
	grabber.last_selected = null
	if is_instance_valid(grabber.hovered):
		grabber.hovered.set_hovered(false)
	grabber.hovered = null
	grabber._pending_recovery = null
	grabber._pending_release = false
	for old in objects.get_children():
		objects.remove_child(old)
		old.queue_free()
	hand.set_cards(loaded["record"].get("hand", []))
	for i in range(pieces.size()):
		var piece := pieces[i]
		objects.add_child(piece)
		SandboxPersistence.restore_piece(piece, record["objects"][i])
		if piece is Deck3D:
			piece.spread_draws = true
			piece.draw_offset = Vector3(0, 0.65, 1.0)
			piece._initial_count = 52 if piece.name == ENGLISH_NAME else 40
			_connect_deck(piece)
			if piece.name == ENGLISH_NAME:
				english = piece
			else:
				spanish = piece
	status_label.text = (
		"Archivo principal inválido o ausente: cargada la copia anterior."
		if loaded["backup"]
		else "Mesa de cartas cargada; la física continúa."
	)


static func _decode_save(record: Variant) -> Variant:
	if not record is Dictionary or record.get("game") != "card_table":
		return null
	var version: Variant = record.get("version")
	# JSON devuelve números como float: se compara por valor, no con Array.has().
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or (version != 1 and version != 2):
		return null
	# Versión 2: añade la mano del jugador. La 1 sigue cargando (mano vacía).
	var hand_cards: Variant = record.get("hand", [])
	if not hand_cards is Array or (version == 1 and not (hand_cards as Array).is_empty()):
		return null
	var table: Variant = record.get("table")
	if not SandboxPersistence.validate(table):
		return null
	var english_cards := _english_cards()
	var spanish_cards := _spanish_cards()
	var seen := {}
	var decks := {}
	for piece in table["objects"]:
		if piece["type"] == "deck":
			var name: String = piece["name"]
			if name not in [ENGLISH_NAME, SPANISH_NAME] or decks.has(name):
				return null
			decks[name] = true
			var allowed := english_cards if name == ENGLISH_NAME else spanish_cards
			for label in piece["cards"]:
				if label not in allowed or seen.has(label):
					return null
				seen[label] = true
		elif piece["type"] == "card":
			var label: String = piece["label"]
			if (label not in english_cards and label not in spanish_cards) or seen.has(label):
				return null
			seen[label] = true
		else:
			return null
	for label in hand_cards:
		if not label is String or (label not in english_cards and label not in spanish_cards):
			return null
		if seen.has(label):
			return null
		seen[label] = true
	if decks.size() != 2 or seen.size() != english_cards.size() + spanish_cards.size():
		return null
	return record


func _on_selection_changed(object: InteractiveTableObject) -> void:
	status_label.text = (
		(
			("Carta · Alt para inspeccionar" if object is Card3D else object.display_name)
			+ (" · BLOQUEADA" if object.is_table_locked else "")
		)
		if is_instance_valid(object)
		else "Inglesa: %d · Española: %d" % [english.cards_remaining, spanish.cards_remaining]
	)


## Apilado automático: carta sobre mazo o sobre otra carta (TableStacking).
func _on_grab_finished(object: InteractiveTableObject, target: Vector3, reason: String) -> void:
	if reason != "released":
		return
	match TableStacking.on_release(objects, object, target):
		"deck":
			status_label.text = "Carta añadida arriba del mazo."
		"new_deck":
			status_label.text = "Dos cartas juntas forman un mazo nuevo."


func _on_placement_message(message: String) -> void:
	status_label.text = message


func _on_draw(_card: Card3D, deck: Deck3D) -> void:
	status_label.text = "%s · quedan %d" % [deck.display_name, deck.cards_remaining]


func _on_shuffle(deck: Deck3D) -> void:
	status_label.text = "%s mezclada · quedan %d" % [deck.display_name, deck.cards_remaining]


func _reset() -> void:
	get_tree().reload_current_scene()


func _open_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
