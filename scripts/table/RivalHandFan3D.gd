class_name RivalHandFan3D
extends Node3D
## Abanico 3D en tiempo real para representar las cartas de un oponente.
## - Solo recibe el entero público `card_count` (jamás etiquetas ni valores de cartas).
## - Ambas caras usan exclusivamente la textura de reverso (`CardArt.texture("back")`).
## - Sin cuerpos físicos ni colisionadores (cero impacto en Jolt Physics ni en raycasts).
## - Recursos compartidos ligados al ciclo de vida del SceneTree para limpieza exacta al salir.

const MAX_VISIBLE_CARDS := 10
const CARD_SIZE := Vector3(0.27, 0.018, 0.39)
const DONE_META := &"toon_style_applied"

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
	var shared := _ensure_shared_resources()
	_fidget_timer = 3.5 + float(seat_index % 4) * 1.65
	for i in MAX_VISIBLE_CARDS:
		var slot := _make_card_slot(i, shared)
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


func _ensure_shared_resources() -> Dictionary:
	var cache := TableVfx.shared_cache(self)
	if not cache.has("rival_slab_mesh"):
		cache["rival_slab_mesh"] = PieceKit.rounded_slab(CARD_SIZE, 0.036, 0.008, 4)
	if not cache.has("rival_back_quad"):
		var qm := QuadMesh.new()
		qm.size = Vector2(CARD_SIZE.x * 0.96, CARD_SIZE.z * 0.96)
		cache["rival_back_quad"] = qm
	if not cache.has("rival_edge_mat"):
		var edge_mat := StandardMaterial3D.new()
		edge_mat.albedo_color = Palette.PAPER
		edge_mat.roughness = 0.48
		cache["rival_edge_mat"] = edge_mat
	if not cache.has("rival_back_mat"):
		var back_mat := StandardMaterial3D.new()
		back_mat.set_meta(DONE_META, true)
		back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		back_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		back_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		back_mat.albedo_texture = CardArt.texture("back")
		cache["rival_back_mat"] = back_mat
	return cache


func _make_card_slot(idx: int, shared: Dictionary) -> Node3D:
	var slab_mesh := shared["rival_slab_mesh"] as ArrayMesh
	var back_quad := shared["rival_back_quad"] as QuadMesh
	var edge_mat := shared["rival_edge_mat"] as StandardMaterial3D
	var back_mat := shared["rival_back_mat"] as StandardMaterial3D

	var holder := Node3D.new()
	holder.name = "RivalCard%d" % idx
	var body := MeshInstance3D.new()
	body.mesh = slab_mesh
	body.material_override = edge_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(body)
	for side_sign in [-1.0, 1.0]:
		var face := MeshInstance3D.new()
		face.mesh = back_quad
		face.rotation_degrees.x = -90.0 if side_sign > 0.0 else 90.0
		face.position.y = side_sign * (CARD_SIZE.y * 0.5 + 0.002)
		face.material_override = back_mat
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
