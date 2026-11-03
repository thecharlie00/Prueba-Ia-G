class_name CardTable
extends Node3D

const DECK_SCENE := preload("res://scenes/Deck3D.tscn")

var english: Deck3D
var spanish: Deck3D

@onready var objects: Node3D = $Objects
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D
@onready var status_label: Label = $UI/Panel/Margin/Content/Status


func _ready() -> void:
	english = _make_deck("Baraja inglesa", _english_cards(), Vector3(-1.4, 1.05, -1.3))
	spanish = _make_deck("Baraja española", _spanish_cards(), Vector3(1.4, 1.05, -1.3))
	grabber.selection_changed.connect(_on_selection_changed)
	grabber.placement_message.connect(_on_placement_message)
	$UI/Panel/Margin/Content/Reset.pressed.connect(_reset)
	$UI/Panel/Margin/Content/Sandbox.pressed.connect(_open_sandbox)
	$UI/Panel/Margin/Content/English/Shuffle.pressed.connect(english.shuffle_deck)
	$UI/Panel/Margin/Content/English/Draw.pressed.connect(english.draw_card)
	$UI/Panel/Margin/Content/Spanish/Shuffle.pressed.connect(spanish.shuffle_deck)
	$UI/Panel/Margin/Content/Spanish/Draw.pressed.connect(spanish.draw_card)


func _make_deck(title: String, cards: Array[String], position: Vector3) -> Deck3D:
	var deck := DECK_SCENE.instantiate() as Deck3D
	deck.name = title.replace(" ", "_")
	deck.display_name = title + " · N para robar"
	deck.initial_cards = cards
	deck.spread_draws = true
	deck.draw_offset = Vector3(0, 0.65, 1.0)
	deck.position = position
	objects.add_child(deck)
	deck.card_drawn.connect(_on_draw.bind(deck))
	deck.deck_shuffled.connect(_on_shuffle.bind(deck))
	return deck


func _english_cards() -> Array[String]:
	var cards: Array[String] = []
	for suit in ["♠", "♥", "♦", "♣"]:
		for rank in ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]:
			cards.append(rank + " " + suit)
	return cards


func _spanish_cards() -> Array[String]:
	var cards: Array[String] = []
	for suit in ["O", "C", "E", "B"]:
		for rank in ["1", "2", "3", "4", "5", "6", "7", "10", "11", "12"]:
			cards.append(rank + " " + suit)
	return cards


func _on_selection_changed(object: InteractiveTableObject) -> void:
	status_label.text = (
		object.display_name
		if is_instance_valid(object)
		else "Inglesa: %d · Española: %d" % [english.cards_remaining, spanish.cards_remaining]
	)


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
