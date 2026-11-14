class_name CardHand
extends Control
## Mano de cartas de la mesa de cartas: las cartas se ven en 3D sujetas en la mano (Hand3D).
## Solo guarda etiquetas ("A ♠", "7 O"); la mesa decide de dónde vienen y adónde van.
## Clic en una carta = jugarla (señal card_played). Arrastrarla a otro hueco la cambia de
## sitio; "Ordenar" las coloca por palo o por número. "Ocultar" pone las cartas de espaldas
## para pasar el equipo a otra persona.

signal card_played(index: int)
signal changed

var cards: Array[String] = []
var faces_hidden := false
var hand3d: Hand3D

var _title: Label
var _hide_button: Button
var _sort_button: Button
## Orden que aplicará el siguiente clic en "Ordenar": "suit" (palo) o "rank" (número).
var next_sort := "suit"

const ENGLISH_RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SPANISH_RANKS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
const SUIT_ORDER := ["♠", "♥", "♣", "♦", "O", "C", "E", "B"]


func _ready() -> void:
	name = "CardHand"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand3d = Hand3D.new()
	hand3d.lift = 0.75
	add_child(hand3d)
	hand3d.reorderable = true
	hand3d.item_pressed.connect(func(index: int) -> void: card_played.emit(index))
	hand3d.item_moved.connect(move_card)
	# Rótulo pequeño encima de la mano, con el botón para taparla.
	var header := PanelContainer.new()
	header.name = "HandHeader"
	header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	header.grow_horizontal = Control.GROW_DIRECTION_BOTH
	header.offset_top = -250
	header.offset_bottom = -216
	add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	header.add_child(row)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	row.add_child(_title)
	_sort_button = Button.new()
	_sort_button.name = "SortHand"
	_sort_button.focus_mode = Control.FOCUS_NONE
	_sort_button.add_theme_font_size_override("font_size", 12)
	_sort_button.tooltip_text = "También puedes arrastrar una carta a otro hueco de la mano"
	_sort_button.pressed.connect(func() -> void: sort_cards(next_sort))
	row.add_child(_sort_button)
	_hide_button = Button.new()
	_hide_button.name = "HideHand"
	_hide_button.focus_mode = Control.FOCUS_NONE
	_hide_button.add_theme_font_size_override("font_size", 12)
	_hide_button.pressed.connect(func() -> void: set_faces_hidden(not faces_hidden))
	row.add_child(_hide_button)
	_rebuild()


func add(label: String) -> void:
	cards.append(label)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("card")
	_rebuild()
	changed.emit()


func take(index: int) -> String:
	if index < 0 or index >= cards.size():
		return ""
	var label := cards[index]
	cards.remove_at(index)
	_rebuild()
	changed.emit()
	return label


## Cambia una carta de sitio en la mano (arrastrándola en el abanico).
func move_card(from: int, to: int) -> bool:
	if from < 0 or from >= cards.size() or to < 0 or to >= cards.size() or from == to:
		return false
	var label := cards[from]
	cards.remove_at(from)
	cards.insert(to, label)
	_rebuild()
	changed.emit()
	return true


## Ordena la mano por palo (y número dentro del palo) o por número (y palo).
func sort_cards(mode: String) -> void:
	var by_rank := mode == "rank"
	cards.sort_custom(func(a: String, b: String) -> bool:
		var ka := sort_key(a, by_rank)
		var kb := sort_key(b, by_rank)
		return ka < kb if ka != kb else a < b
	)
	next_sort = "suit" if by_rank else "rank"
	_rebuild()
	changed.emit()


## Clave numérica para ordenar una etiqueta ("A ♠", "7 O"); las desconocidas van al final.
static func sort_key(label: String, by_rank: bool) -> int:
	var parts := label.split(" ")
	if parts.size() != 2:
		return 1000000
	var suit := SUIT_ORDER.find(parts[1])
	var ranks := SPANISH_RANKS if parts[1] in ["O", "C", "E", "B"] else ENGLISH_RANKS
	var rank := ranks.find(parts[0])
	if suit < 0 or rank < 0:
		return 1000000
	return rank * 100 + suit if by_rank else suit * 100 + rank


func set_cards(labels: Array) -> void:
	cards.clear()
	for label in labels:
		cards.append(str(label))
	_rebuild()
	changed.emit()


func set_faces_hidden(value: bool) -> void:
	faces_hidden = value
	if hand3d != null:
		hand3d.set_faces_hidden(value)
	_rebuild()


func _rebuild() -> void:
	if hand3d == null:
		return
	var items := []
	for label in cards:
		items.append({"face": "playing", "text": label})
	hand3d.set_items(items)
	_title.text = tr("Tu mano · %d") % cards.size() if not cards.is_empty() else tr("Tu mano está vacía")
	_hide_button.text = "Mostrar" if faces_hidden else "Ocultar"
	_hide_button.visible = not cards.is_empty()
	_sort_button.text = "Ordenar por número" if next_sort == "rank" else "Ordenar por palo"
	_sort_button.visible = cards.size() > 1
	(_title.get_parent().get_parent() as Control).visible = not cards.is_empty()


func _process(_delta: float) -> void:
	# El rótulo no tapa la carta ampliada mientras se mira.
	var header := get_node_or_null("HandHeader") as Control
	if header != null and hand3d != null:
		header.visible = not cards.is_empty() and hand3d._hovered < 0
