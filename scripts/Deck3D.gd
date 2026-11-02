class_name Deck3D
extends InteractiveTableObject

signal card_drawn(card: Card3D)
@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var cards_remaining := 12
@export var draw_offset := Vector3(1.0, 0.6, 0.0)


func draw_card() -> void:
	if cards_remaining <= 0 or card_scene == null:
		return
	var card := card_scene.instantiate() as Card3D
	if card == null:
		return
	get_parent().add_child(card)
	card.global_position = global_position + draw_offset
	cards_remaining -= 1
	card_drawn.emit(card)
