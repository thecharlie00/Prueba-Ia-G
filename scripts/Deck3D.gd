class_name Deck3D
extends InteractiveTableObject

signal card_drawn(card: Card3D)
signal deck_shuffled

@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var cards_remaining := 12
@export var draw_offset := Vector3(1.0, 0.6, 0.0)
@export var initial_cards: Array[String] = []
# Opcional: reparte las cartas dibujadas en seis puntos, elevando cada nueva capa.
@export var spread_draws := false
var _initial_count := 0
var _cards: Array[String] = []


func _ready() -> void:
	super._ready()
	# Montón de cartas: losa redondeada con el color del reverso y cantos de "páginas".
	$Visual.mesh = PieceKit.rounded_slab(Vector3(0.7, 0.24, 0.98), 0.08, 0.035)
	if $Visual.material_override is StandardMaterial3D:
		($Visual.material_override as StandardMaterial3D).albedo_color = Color("ff6b5e")
	_add_page_lines()
	_add_back_art()
	if initial_cards.is_empty():
		for number in range(1, maxi(cards_remaining, 0) + 1):
			_cards.append(str(number))
	else:
		_cards.assign(initial_cards)
	cards_remaining = _cards.size()
	_initial_count = cards_remaining


func shuffle_deck() -> void:
	if is_grabbed or freeze or _cards.size() < 2:
		return
	_cards.shuffle()
	deck_shuffled.emit()


func draw_card() -> void:
	if is_grabbed or freeze or _cards.is_empty() or card_scene == null:
		return
	var card := card_scene.instantiate() as Card3D
	if card == null:
		return
	get_parent().add_child(card)
	var offset := draw_offset
	if spread_draws:
		var index := _initial_count - _cards.size()
		var slot := index % 6
		offset += Vector3((slot % 3 - 1) * 0.75, (index / 6) * 0.08, (slot / 3) * 1.1)
	card.global_position = global_position + offset
	card.set_card_label(_cards.pop_back())
	cards_remaining = _cards.size()
	card_drawn.emit(card)


func _add_page_lines() -> void:
	if has_node("Visual/Pages"):
		return
	var pages := Node3D.new()
	pages.name = "Pages"
	$Visual.add_child(pages)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("fff8ec")
	for i in 3:
		var band := MeshInstance3D.new()
		band.mesh = PieceKit.rounded_slab(Vector3(0.712, 0.022, 0.992), 0.08, 0.008)
		band.position.y = -0.07 + i * 0.07
		band.material_override = paper
		pages.add_child(band)


# Reverso ilustrado (CardArt) en la cara de arriba del mazo.
func _add_back_art() -> void:
	if has_node("Visual/BackArt"):
		return
	var face := MeshInstance3D.new()
	face.name = "BackArt"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.98)
	face.mesh = quad
	face.rotation_degrees.x = -90
	face.position.y = 0.123
	var material := StandardMaterial3D.new()
	material.albedo_texture = CardArt.texture("back")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face.material_override = material
	$Visual.add_child(face)
