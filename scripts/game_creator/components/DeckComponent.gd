# DeckComponent.gd
# Un mazo de cartas como un solo objeto sobre la mesa. El mazo es UNA entidad
# (una pieza) que contiene internamente una lista de cartas. Al arrastrarlo se
# toma la carta de arriba; con clic derecho se reparten, barajan, buscan, se
# ven las de arriba o se da la vuelta al mazo. Todo deshacible vía _remember.
class_name DeckComponent
extends BehaviorComponent

# Cartas internas del mazo, de abajo a arriba (cards[-1] es la de arriba).
# Cada una: { id, name, texture, back, label, notes, face_up }
@export var cards: Array[Dictionary] = []

# Si el mazo se ve de cara (se ve la carta de arriba) o de dorso.
@export var face_up: bool = true

# Mostrar el contador de cartas sobre la pieza en el inspector / hover.
@export var show_count: bool = true

# Número de cartas que se muestran al hacer «Ver N de arriba».
@export var peek_count: int = 3

# Máximo de cartas que puede contener el mazo (-1 = ilimitado).
@export var max_capacity: int = -1

# Zona de destino por defecto al repartir (id de zona o "").
@export var default_deal_zone: String = ""

func _serialize_extra(data: Dictionary) -> void:
	data["cards"] = cards
	data["face_up"] = face_up
	data["show_count"] = show_count
	data["peek_count"] = peek_count
	data["max_capacity"] = max_capacity
	data["default_deal_zone"] = default_deal_zone

func _deserialize_extra(data: Dictionary) -> void:
	cards = data.get("cards", []) if data.get("cards") is Array else []
	face_up = data.get("face_up", face_up) == true
	show_count = data.get("show_count", show_count) == true
	peek_count = clampi(int(data.get("peek_count", peek_count)), 1, 10)
	max_capacity = int(data.get("max_capacity", max_capacity))
	default_deal_zone = str(data.get("default_deal_zone", default_deal_zone))

## Devuelve cuántas cartas hay en el mazo.
func count() -> int:
	return cards.size()

## Devuelve true si el mazo está vacío.
func is_empty() -> bool:
	return cards.is_empty()

## Devuelve la carta de arriba sin sacarla, o null si el mazo está vacío.
func top_card() -> Dictionary:
	return cards[-1] if not cards.is_empty() else {}

## Saca y devuelve la carta de arriba, o null si está vacía.
func draw_top() -> Dictionary:
	if cards.is_empty():
		return {}
	return cards.pop_back()

## Baraja las cartas internas del mazo (sin desordenar las de la mesa).
func shuffle() -> void:
	cards.shuffle()

## Da la vuelta al mazo: invierte el orden y cambia face_up.
func flip_deck() -> void:
	cards.reverse()
	face_up = not face_up

## Añade una carta al mazo (encima). Devuelve true si se pudo.
func add_card(card: Dictionary) -> bool:
	if max_capacity >= 0 and cards.size() >= max_capacity:
		return false
	cards.append(card)
	return true

## Saca `count` cartas de arriba y las devuelve como lista.
func deal(count: int) -> Array:
	var n := clampi(count, 0, cards.size())
	var dealt: Array = []
	for _ in range(n):
		dealt.append(draw_top())
	return dealt

## Busca una carta por nombre (o por id) y la saca del mazo. Devuelve la carta o {}.
func search(name_or_id: String) -> Dictionary:
	var wanted := name_or_id.strip_edges().to_lower()
	for i in cards.size():
		var c := cards[i]
		if str(c.get("id", "")).to_lower() == wanted or str(c.get("name", "")).to_lower() == wanted:
			return cards.remove_at(i)
	return {}

## Devuelve una copia de las `n` cartas de arriba (para verlas sin sacarlas).
func peek(n: int) -> Array:
	var count := clampi(n, 0, cards.size())
	return cards.slice(cards.size() - count, cards.size())

## Devuelve una copia de todas las cartas (de abajo a arriba).
func all_cards() -> Array:
	return cards.duplicate()

## Reparte `count` cartas de este mazo a una zona (a través del editor).
## Devuelve cuántas se repartieron. Requiere que `editor` sea GameCreatorEditor.
func deal_to_zone(count: int, editor: Object, to_zone_id: String) -> int:
	var dealt := deal(count)
	if dealt.is_empty() or editor == null:
		return 0
	var zone := editor._find_piece(to_zone_id) if editor.has_method("_find_piece") else null
	if zone == null:
		# Devolver las cartas al mazo si no hay zona destino.
		for c in dealt:
			add_card(c)
		return 0
	var v := zone.get_component("VisualComponent") if zone != null else null
	var zone_size := PieceShapes.piece_size(v) if v != null else Vector3(1, 0.006, 0.7)
	var slot := 0
	for c in dealt:
		var piece := {
			"id": "", "name": str(c.get("name", "Carta")), "shape": "carta",
			"color": Palette.PAPER.to_html(true), "texture": str(c.get("texture", "")),
			"back": str(c.get("back", "")), "label": str(c.get("label", "")),
			"pattern": "liso", "cells": 8, "finish": "brillo",
			"notes": str(c.get("notes", "")), "shuffle": false,
			"tags": [], "zkind": "normal", "player": 0, "model": "", "msize": [0, 0, 0],
			"pos": [0, 0, 0], "rot": [0, 0, 0], "scale": 1.0,
			"locked": false, "mass": 0.2, "bounce": 0.05,
		}
		editor._place_card_in_zone(piece, zone, slot)
		slot += 1
	if v != null and v.zone_kind == "mano" and not editor._build_mode:
		editor._arrange_hand(zone)
	editor._play("card")
	return dealt.size()

## Efecto de sonido auxiliar (busca /root/Sfx).
func _play_sound(editor: Object, sound: String) -> void:
	if editor == null:
		return
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null and sfx.has_method("play"):
		sfx.play(sound)
