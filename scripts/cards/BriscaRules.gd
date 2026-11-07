class_name BriscaRules
extends RefCounted
## Brisca para dos jugadores con la baraja española de 40 cartas.
##
## - Se reparten 3 cartas a cada uno; la siguiente se pone boca arriba (la muestra) y su palo
##   es el triunfo. La muestra queda debajo del mazo y es la última carta que se roba.
## - No hay que asistir ni que ganar: se puede jugar cualquier carta.
## - Gana la baza el triunfo más alto; si no hay triunfo, la carta más alta del palo de salida.
##   Orden: as, tres, rey (12), caballo (11), sota (10), 7, 6, 5, 4, 2.
## - Puntos: as 11, tres 10, rey 4, caballo 3, sota 2 (120 en total). Gana quien pase de 60.
## - Quien gana la baza roba primero y sale en la siguiente.
## La partida se guarda como semilla de reparto + cartas jugadas, y se reconstruye jugándolas.

const SUITS := ["O", "C", "E", "B"]
const RANKS := ["1", "2", "3", "4", "5", "6", "7", "10", "11", "12"]
const SUIT_NAMES := {"O": "oros", "C": "copas", "E": "espadas", "B": "bastos"}
const RANK_NAMES := {"1": "as", "10": "sota", "11": "caballo", "12": "rey"}
const STRENGTH := {"1": 10, "3": 9, "12": 8, "11": 7, "10": 6, "7": 5, "6": 4, "5": 3, "4": 2, "2": 1}
const POINTS := {"1": 11, "3": 10, "12": 4, "11": 3, "10": 2}
const HAND_SIZE := 3
const PLAYING := "playing"
const FINISHED := "finished"
## Resultado: 0 o 1 gana ese jugador; DRAW empate a 60.
const DRAW := 2

var deal_seed := 0
## Mazo para robar: se roba del final; la muestra está en la posición 0.
var stock: Array[String] = []
var trump_card := ""
var trump_suit := ""
var hands: Array = [[], []]
## Baza en curso: [{"player": int, "card": String}].
var trick: Array[Dictionary] = []
## Última baza terminada, para enseñarla un momento: cartas, ganador y puntos.
var last_trick: Dictionary = {}
var turn := 0
var points := [0, 0]
var tricks_won := [0, 0]
var phase := PLAYING
var result := -1
var events: Array[Dictionary] = []


func _init(seed_value: int = 0) -> void:
	reset(seed_value)


static func full_deck() -> Array[String]:
	var cards: Array[String] = []
	for suit in SUITS:
		for rank in RANKS:
			cards.append(rank + " " + suit)
	return cards


static func rank_of(card: String) -> String:
	return card.get_slice(" ", 0)


static func suit_of(card: String) -> String:
	return card.get_slice(" ", 1)


static func card_points(card: String) -> int:
	return int(POINTS.get(rank_of(card), 0))


static func card_name(card: String) -> String:
	var rank := rank_of(card)
	return "%s de %s" % [RANK_NAMES.get(rank, rank), SUIT_NAMES.get(suit_of(card), "?")]


func reset(seed_value: int) -> void:
	deal_seed = seed_value
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var deck := full_deck()
	# Barajado propio (Fisher–Yates) con la semilla, igual en cualquier equipo.
	for i in range(deck.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var swap := deck[i]
		deck[i] = deck[j]
		deck[j] = swap
	hands = [[], []]
	for _deal in HAND_SIZE:
		for player in 2:
			hands[player].append(deck.pop_back())
	trump_card = deck.pop_back()
	trump_suit = suit_of(trump_card)
	stock.clear()
	stock.append(trump_card)
	stock.append_array(deck)
	trick.clear()
	last_trick = {}
	turn = 0
	points = [0, 0]
	tricks_won = [0, 0]
	phase = PLAYING
	result = -1
	events.clear()


## La carta a beats la carta b (b ya está en la mesa y marca el palo si no hay triunfo).
func beats(a: String, b: String) -> bool:
	var sa := suit_of(a)
	var sb := suit_of(b)
	if sa == sb:
		return STRENGTH[rank_of(a)] > STRENGTH[rank_of(b)]
	return sa == trump_suit


func can_play(card: String) -> bool:
	return phase == PLAYING and card in hands[turn]


func play(card: String) -> bool:
	if not can_play(card):
		return false
	hands[turn].erase(card)
	trick.append({"player": turn, "card": card})
	events.append({"type": "play", "card": card})
	if trick.size() < 2:
		turn = 1 - turn
		return true
	var first: Dictionary = trick[0]
	var second: Dictionary = trick[1]
	var winner: int = second["player"] if beats(second["card"], first["card"]) else first["player"]
	var gained := card_points(first["card"]) + card_points(second["card"])
	points[winner] += gained
	tricks_won[winner] += 1
	last_trick = {"cards": trick.duplicate(true), "winner": winner, "points": gained}
	trick.clear()
	# Roba primero quien gana la baza; la muestra es la última carta del mazo.
	for player in [winner, 1 - winner]:
		if not stock.is_empty():
			hands[player].append(stock.pop_back())
	turn = winner
	if hands[0].is_empty() and hands[1].is_empty():
		phase = FINISHED
		result = DRAW if points[0] == points[1] else (0 if points[0] > points[1] else 1)
	return true


## Carta de la mesa en la baza actual (la que hay que superar), o "".
func card_to_beat() -> String:
	return trick[0]["card"] if trick.size() == 1 else ""


func export_record() -> Dictionary:
	return {"game": "brisca", "version": 1, "seed": deal_seed, "events": events.duplicate(true)}


static func from_record(data: Variant) -> BriscaRules:
	if not data is Dictionary or data.get("game") != "brisca":
		return null
	var version: Variant = data.get("version")
	var seed_value: Variant = data.get("seed")
	var list: Variant = data.get("events")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version != 1:
		return null
	if typeof(seed_value) not in [TYPE_INT, TYPE_FLOAT] or float(seed_value) != floorf(float(seed_value)):
		return null
	if absf(float(seed_value)) > 2147483647.0 or not list is Array or list.size() > 40:
		return null
	var rules := BriscaRules.new(int(seed_value))
	for event in list:
		if not event is Dictionary or event.get("type") != "play" or not event.get("card") is String:
			return null
		if not rules.play(event["card"]):
			return null
	return rules
