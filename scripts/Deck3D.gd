class_name Deck3D
extends InteractiveTableObject

signal card_drawn(card: Card3D)
signal deck_shuffled

@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var cards_remaining := 12
@export var draw_offset := Vector3(1.0, 0.6, 0.0)
var _cards: Array[String] = []


func _ready() -> void:
	super._ready()
	for number in range(1, maxi(cards_remaining, 0) + 1):
		_cards.append(str(number))
	cards_remaining = _cards.size()


func shuffle_deck() -> void:
	if _cards.size() < 2:
		return
	_cards.shuffle()
	deck_shuffled.emit()


func draw_card() -> void:
	if _cards.is_empty() or card_scene == null:
		return
	var card := card_scene.instantiate() as Card3D
	if card == null:
		return
	get_parent().add_child(card)
	card.global_position = global_position + draw_offset
	card.set_card_label(_cards.pop_back())
	cards_remaining = _cards.size()
	card_drawn.emit(card)
