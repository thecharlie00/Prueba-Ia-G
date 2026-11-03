class_name Deck3D
extends InteractiveTableObject

signal card_drawn(card: Card3D)
signal deck_shuffled

@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var cards_remaining := 12
@export var draw_offset := Vector3(1.0, 0.6, 0.0)
@export var initial_cards: Array[String] = []
# Opcional: reparte las cartas dibujadas en seis puntos, elevando cada nueva capa.
@export var spread_draws := false
var _initial_count := 0
var _cards: Array[String] = []


func _ready() -> void:
	super._ready()
	if initial_cards.is_empty():
		for number in range(1, maxi(cards_remaining, 0) + 1):
			_cards.append(str(number))
	else:
		_cards.assign(initial_cards)
	cards_remaining = _cards.size()
	_initial_count = cards_remaining


func shuffle_deck() -> void:
	if is_grabbed or freeze or _cards.size() < 2:
		return
	_cards.shuffle()
	deck_shuffled.emit()


func draw_card() -> void:
	if is_grabbed or freeze or _cards.is_empty() or card_scene == null:
		return
	var card := card_scene.instantiate() as Card3D
	if card == null:
		return
	get_parent().add_child(card)
	var offset := draw_offset
	if spread_draws:
		var index := _initial_count - _cards.size()
		var slot := index % 6
		offset += Vector3((slot % 3 - 1) * 0.75, (index / 6) * 0.08, (slot / 3) * 1.1)
	card.global_position = global_position + offset
	card.set_card_label(_cards.pop_back())
	cards_remaining = _cards.size()
	card_drawn.emit(card)
