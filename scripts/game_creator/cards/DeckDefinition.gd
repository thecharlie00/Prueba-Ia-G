# DeckDefinition.gd
# Definición de un mazo: lista de cartas con sus cantidades.
extends Resource

@export var deck_id: String = ""
@export var deck_name: String = "Nuevo Mazo"
@export var author: String = ""
@export var cards: Array[Dictionary] = []  # { card: CardData, quantity: int }

func _init(p_deck_id: String = "", p_deck_name: String = ""):
	deck_id = p_deck_id if p_deck_id != "" else str(Time.get_ticks_msec())
	deck_name = p_deck_name if p_deck_name != "" else "Nuevo Mazo"

# Devuelve el total de cartas en el mazo (sumando cantidades).
func total_cards() -> int:
class_name DeckDefinition
	var total: int = 0
	for entry in cards:
		total += entry.get("quantity", 1)
	return total
