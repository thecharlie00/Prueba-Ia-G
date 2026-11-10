class_name RivalHandFan3D
extends Node3D
## Abanico 3D en tiempo real para representar las cartas (o fichas privadas) de un oponente.
## Seguridad de red y privacidad garantizada:
## - Solo recibe el entero público `card_count` (jamás etiquetas ni valores de cartas).
## - Ambas caras usan exclusivamente la textura de reverso (`CardArt.texture("back")`).
## - Sin cuerpos físicos ni colisionadores (cero impacto en Jolt Physics ni en raycasts).
## - Pool fijo de mallas reutilizadas para evitar reservas de memoria durante la partida.

const MAX_VISIBLE_CARDS := 10
const CARD_SIZE := Vector3(0.27, 0.018, 0.39)
const DONE_META := &"toon_style_applied"

static var _slab_mesh: ArrayMesh
static var _back_quad: QuadMesh
static var _back_mat: StandardMaterial3D
static var _edge_mat: StandardMaterial3D

var card_count := 0
var seat_index := 0

var _slots: Array[Node3D] = []
var _targets: Array[Transform3D] = []
var _badge: Label3D
var _fidget_timer := 4.0
var _fidget_slot := -1
var _fidget_phase := 0.0
var _pop_timer := 0.0


func _ready() -> void:
	_ensure_shared_resources()
	_fidget_timer = 3.5 + float(seat_index % 4) * 1.65
	for i in MAX_VISIBLE_CARDS:
		var slot := _make_card_slot(i)
		slot.visible = false
		add_child(slot)
		_slots.append(slot)
		_targets.append(Transform3D.IDENTITY)
	_badge = Label3D.new()
	_badge.name = "CountBadge"
	if has_node("/root/ToonStyle"):
		_badge.font = get_node("/root/ToonStyle").DISPLAY_FONT
	_badge.font_size = 44
	_badge.pixel_size = 0.0036
	_badge.modulate = Palette.SUN
	_badge.outline_size = 16
	_badge.outline_modulate = Palette.INK
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.no_depth_test = true
	_badge.render_priority = 3
	_badge.position = Vector3(0.0, 0.26, 0.04)
	_badge.visible = false
	add_child(_badge)
	visible = false
	set_process(false)


static func _ensure_shared_resources() -> void:
	if _slab_mesh == null:
		_slab_mesh = PieceKit.rounded_slab(CARD_SIZE, 0.036, 0.008, 4)
	if _back_quad == null:
		_back_quad = QuadMesh.new()
		_back_quad.size = Vector2(CARD_SIZE.x * 0.96, CARD_SIZE.z * 0.96)
	if _edge_mat == null:
		_edge_mat = StandardMaterial3D.new()
		_edge_mat.albedo_color = Palette.PAPER
		_edge_mat.roughness = 0.48
	if _back_mat == null:
		_back_mat = StandardMaterial3D.new()
		_back_mat.set_meta(DONE_META, true)
		_back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_back_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_back_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_back_mat.albedo_texture = CardArt.texture("back")


func _make_card_slot(idx: int) -> Node3D:
	var holder := Node3D.new()
	holder.name = "RivalCard%d" % idx
	var body := MeshInstance3D.new()
	body.mesh = _slab_mesh
	body.material_override = _edge_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(body)
	# Ambas caras llevan únicamente el reverso para blindar la privacidad desde cualquier ángulo.
	for side_sign in [-1.0, 1.0]:
		var face := MeshInstance3D.new()
		face.mesh = _back_quad
		face.rotation_degrees.x = -90.0 if side_sign > 0.0 else 90.0
		face.position.y = side_sign * (CARD_SIZE.y * 0.5 + 0.002)
		face.material_override = _back_mat
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(face)
	return holder


func set_card_count(new_count: int) -> void:
	var clamped := maxi(new_count, 0)
	if clamped == card_count:
		return
	var grew := clamped > card_count
	card_count = clamped
	if card_count <= 0:
		visible = false
		_badge.visible = false
		for slot in _slots:
			slot.visible = false
		set_process(false)
		return
	visible = true
	set_process(true)
	_recompute_targets(grew)


func _recompute_targets(animate_new: bool) -> void:
	var shown := mini(card_count, MAX_VISIBLE_CARDS)
	var spread_deg := minf(44.0, float(shown) * 6.8)
	var step_x := minf(0.105, 0.76 / maxf(float(shown), 1.0))
	for i in MAX_VISIBLE_CARDS:
		var slot := _slots[i]
		if i >= shown:
			slot.visible = false
			continue
		var was_hidden := not slot.visible
		slot.visible = true
		var center_offset := float(i) - float(shown - 1) * 0.5
		var norm := center_offset / maxf(float(shown - 1) * 0.5, 1.0) if shown > 1 else 0.0
		var roll := deg_to_rad(-norm * spread_deg * 0.5)
		# Las cartas se levantan casi verticales mirando hacia el centro de la mesa (-Z).
		var tilt := Basis(Vector3.FORWARD, roll) * Basis(Vector3.RIGHT, deg_to_rad(68.0))
		var pos := Vector3(
			center_offset * step_x,
			-absf(norm) * absf(norm) * 0.045,
			float(i) * 0.007
		)
		var target := Transform3D(tilt, pos)
		_targets[i] = target
		if was_hidden:
			if animate_new and not _is_reduce_motion():
				slot.transform = Transform3D(
					tilt.scaled(Vector3.ONE * 0.35),
					pos + Vector3(0.0, 0.16, 0.12)
				)
				_pop_timer = 0.28
			else:
				slot.transform = target
	_badge.visible = card_count > 3
	if _badge.visible:
		_badge.text = "×%d" % card_count


func _is_reduce_motion() -> bool:
	var style := get_node_or_null("/root/ToonStyle")
	return style != null and style.get("reduce_motion") == true


func _process(delta: float) -> void:
	if card_count <= 0:
		set_process(false)
		return
	var reduce := _is_reduce_motion()
	var shown := mini(card_count, MAX_VISIBLE_CARDS)
	if not reduce and shown >= 2:
		_fidget_timer -= delta
		if _fidget_timer <= 0.0:
			_fidget_timer = randf_range(5.2, 8.8)
			_fidget_slot = randi() % shown
			_fidget_phase = 0.42
	if _fidget_phase > 0.0:
		_fidget_phase = maxf(_fidget_phase - delta, 0.0)
	if _pop_timer > 0.0:
		_pop_timer = maxf(_pop_timer - delta, 0.0)

	var weight := clampf(delta * 13.0, 0.0, 1.0)
	for i in shown:
		var goal := _targets[i]
		if not reduce and i == _fidget_slot and _fidget_phase > 0.0:
			var wave := sin((1.0 - _fidget_phase / 0.42) * PI)
			goal.origin.y += wave * 0.042
			goal.origin.z -= wave * 0.022
		_slots[i].transform = _slots[i].transform.interpolate_with(goal, weight)
