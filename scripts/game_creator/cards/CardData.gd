# CardData.gd
# Datos de una carta individual dentro del Card & Deck Builder Studio.
extends Resource
class_name CardData

@export var card_id: String = ""
@export var name: String = "Carta"
@export var description: String = ""
@export var front_art: Texture2D = null
@export var back_art: Texture2D = null  # dorso compartido por el mazo
@export var cost: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var icons: Array[String] = []
@export var frame_style: String = "classic"  # classic, cartoon, stylized
@export var custom_fields: Dictionary = {}

func _init(p_card_id: String = "", p_name: String = ""):
	card_id = p_card_id if p_card_id != "" else str(Time.get_ticks_msec())
	name = p_name if p_name != "" else "Carta"
