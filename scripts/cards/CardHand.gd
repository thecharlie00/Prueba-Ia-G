class_name CardHand
extends Control
## Mano de cartas de la mesa de cartas: las cartas se ven en 3D sujetas en la mano (Hand3D).
## Solo guarda etiquetas ("A ♠", "7 O"); la mesa decide de dónde vienen y adónde van.
## Clic en una carta = jugarla (señal card_played). "Ocultar" pone las cartas de espaldas
## para pasar el equipo a otra persona.

signal card_played(index: int)
signal changed

var cards: Array[String] = []
var faces_hidden := false
var hand3d: Hand3D

var _title: Label
var _hide_button: Button


func _ready() -> void:
	name = "CardHand"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand3d = Hand3D.new()
	hand3d.lift = 0.75
	add_child(hand3d)
	hand3d.item_pressed.connect(func(index: int) -> void: card_played.emit(index))
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
	_title.text = "Tu mano · %d" % cards.size() if not cards.is_empty() else "Tu mano está vacía"
	_hide_button.text = "Mostrar" if faces_hidden else "Ocultar"
	_hide_button.visible = not cards.is_empty()
	(_title.get_parent().get_parent() as Control).visible = not cards.is_empty()
