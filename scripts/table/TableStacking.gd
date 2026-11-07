class_name TableStacking
extends RefCounted
## Apilado automático (fase 2): al soltar una carta sobre un mazo entra arriba del mazo; al
## soltar una carta sobre otra carta suelta se forma un mazo nuevo con las dos; al soltar
## una ficha sobre otra se centra encima para que la pila quede recta.

const DECK_SCENE := "res://scenes/Deck3D.tscn"
const CARD_REACH := 0.4
const TOKEN_REACH := 0.28
const MAX_DECK := 120


## Llamar desde grab_finished con reason == "released". Devuelve lo que hizo: "deck",
## "new_deck", "token" o "" si nada.
static func on_release(objects: Node, object: InteractiveTableObject, target: Vector3) -> String:
	if not is_instance_valid(object) or object.is_table_locked:
		return ""
	if object is Card3D:
		var card := object as Card3D
		var deck := _nearest(objects, card, target, CARD_REACH, "Deck3D") as Deck3D
		if deck != null and deck._cards.size() < MAX_DECK:
			_into_deck.call_deferred(deck, card)
			return "deck"
		var other := _nearest(objects, card, target, CARD_REACH, "Card3D") as Card3D
		if other != null and not other._flipping and not card._flipping:
			_new_deck.call_deferred(objects, other, card)
			return "new_deck"
	elif object is Token3D:
		var below := _nearest(objects, object, target, TOKEN_REACH, "Token3D")
		if below != null:
			# Encima y centrada: la física hace el resto.
			var top := below.global_position + Vector3.UP * 0.12
			object.global_position = Vector3(top.x, maxf(object.global_position.y, top.y), top.z)
			object.linear_velocity = Vector3.ZERO
			return "token"
	return ""


static func _nearest(objects: Node, object: InteractiveTableObject, target: Vector3, reach: float, kind: String) -> InteractiveTableObject:
	var best: InteractiveTableObject = null
	var best_distance := reach
	for child in objects.get_children():
		var other := child as InteractiveTableObject
		if other == null or other == object or other.is_grabbed or not other.is_class("RigidBody3D"):
			continue
		if not _is_kind(other, kind) or bool(other.get_meta(&"private_hidden", false)):
			continue
		var flat := Vector2(target.x - other.global_position.x, target.z - other.global_position.z).length()
		if flat < best_distance:
			best_distance = flat
			best = other
	return best


static func _is_kind(object: Object, kind: String) -> bool:
	match kind:
		"Deck3D":
			return object is Deck3D
		"Card3D":
			return object is Card3D
		"Token3D":
			return object is Token3D
	return false


static func _into_deck(deck: Deck3D, card: Card3D) -> void:
	if not is_instance_valid(deck) or not is_instance_valid(card) or card.is_grabbed:
		return
	deck._cards.append(card.card_label)
	deck.cards_remaining = deck._cards.size()
	card.get_parent().remove_child(card)
	card.queue_free()
	deck._juice(Vector3(1.08, 0.9, 1.08))
	deck._sound("drop")


static func _new_deck(objects: Node, bottom: Card3D, top: Card3D) -> void:
	if not is_instance_valid(bottom) or not is_instance_valid(top) or top.is_grabbed or bottom.is_grabbed:
		return
	var deck := (load(DECK_SCENE) as PackedScene).instantiate() as Deck3D
	deck.initial_cards.assign([bottom.card_label, top.card_label])
	deck.cards_remaining = 2
	deck.display_name = "Mazo"
	deck.name = "Mazo"
	var at := bottom.global_position
	var turn := bottom.global_rotation.y
	for card in [bottom, top]:
		card.get_parent().remove_child(card)
		card.queue_free()
	objects.add_child(deck, true)
	deck.global_position = Vector3(at.x, at.y + 0.15, at.z)
	deck.rotation.y = turn
	deck._juice(Vector3(1.1, 0.88, 1.1))
	deck._sound("drop")
