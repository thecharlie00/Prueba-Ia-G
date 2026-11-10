class_name Card3D
extends InteractiveTableObject

@export var flip_duration := 0.35
@export var card_label := "A"

var _flipping := false
var _front_mat: ShaderMaterial
var _back_mat: ShaderMaterial
var _drag_bend := Vector2.ZERO


func _ready() -> void:
	super._ready()
	_shape_card()
	var label := Label3D.new()
	label.name = "FaceLabel"
	label.text = card_label
	label.font_size = 64
	label.pixel_size = 0.004
	label.modulate = Color(0.12, 0.25, 0.21)
	label.position = Vector3(0, 0.032, 0)
	label.rotation_degrees = Vector3(-90, 0, 0)
	$Visual.add_child(label)
	for index in range(2):
		var corner := Label3D.new()
		corner.name = "Corner%d" % index
		corner.text = card_label
		corner.font_size = 44
		corner.pixel_size = 0.0025
		corner.modulate = Color(0.12, 0.25, 0.21)
		corner.rotation_degrees = Vector3(-90, 0, 0 if index == 0 else 180)
		corner.position = Vector3(
			-0.22 if index == 0 else 0.22, 0.032, -0.34 if index == 0 else 0.34
		)
		$Visual.add_child(corner)


func set_card_label(value: String) -> void:
	card_label = value
	_apply_art()
	display_name = "Carta " + CustomDecks.pretty(value) + " · F para voltear"
	var label := get_node_or_null("Visual/FaceLabel") as Label3D
	if label:
		label.text = value
	for index in range(2):
		var corner := get_node_or_null("Visual/Corner%d" % index) as Label3D
		if corner:
			corner.text = value


func flip() -> void:
	if _flipping or is_grabbed or freeze:
		return
	_flipping = true
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("card")
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var end_rotation := quaternion * Quaternion(Vector3.FORWARD, PI)
	var tween := create_tween()
	(
		tween
		. tween_property(self, "quaternion", end_rotation, flip_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	tween.tween_callback(_finish_flip)


func _finish_flip() -> void:
	freeze = false
	sleeping = false
	_flipping = false
	if is_inside_tree():
		TableVfx.spawn_drop(self, global_position, 0.65, Palette.PAPER)


func _has_extra_visual_motion() -> bool:
	return _drag_bend.length_squared() > 0.0004


func _tick_visual_juice(delta: float) -> void:
	var target_bend := Vector2.ZERO
	if is_grabbed and not _is_reduce_motion():
		var local_vel := global_transform.basis.inverse() * linear_velocity
		target_bend = Vector2(
			clampf(local_vel.x * 0.22, -1.25, 1.25),
			clampf(-local_vel.z * 0.22, -1.25, 1.25)
		)
	_drag_bend = _drag_bend.lerp(target_bend, 1.0 - exp(-16.0 * delta))
	if not _has_extra_visual_motion() and not is_grabbed:
		_drag_bend = Vector2.ZERO
	if _front_mat != null:
		_front_mat.set_shader_parameter("drag_bend", _drag_bend)
	if _back_mat != null:
		_back_mat.set_shader_parameter("drag_bend", _drag_bend)
	super._tick_visual_juice(delta)


# Carta de canto grueso y esquinas redondeadas con la ilustración de CardArt en las dos caras
# y malla subdividida con deformación aerodinámica durante el arrastre (card_flex.gdshader).
func _shape_card() -> void:
	$Visual.mesh = PieceKit.rounded_slab(Vector3(0.68, 0.05, 0.96), 0.08, 0.022)
	if $Visual.material_override is StandardMaterial3D:
		($Visual.material_override as StandardMaterial3D).albedo_color = Color("fff1d9")
	var quad := TableVfx.shared_card_quad(self)
	var flex_shader := TableVfx.card_flex_shader(self)
	for side in ["Front", "Back"]:
		var node := get_node_or_null("Visual/" + side) as MeshInstance3D
		if node == null:
			continue
		node.mesh = quad
		node.rotation_degrees.x = -90 if side == "Front" else 90
		node.position.y = 0.0265 if side == "Front" else -0.0265
		var mat := ShaderMaterial.new()
		mat.set_meta(DONE_META, true)
		mat.shader = flex_shader
		mat.set_shader_parameter("bend_sign", 1.0 if side == "Front" else -1.0)
		mat.set_shader_parameter("drag_bend", Vector2.ZERO)
		if side == "Back":
			mat.set_shader_parameter("card_tex", CardArt.texture("back"))
			_back_mat = mat
		else:
			_front_mat = mat
		node.material_override = mat
	_update_highlight()
	_apply_art.call_deferred()


func _apply_art() -> void:
	for node_name in ["FaceLabel", "Corner0", "Corner1"]:
		var label := get_node_or_null("Visual/" + node_name) as Label3D
		if label != null:
			label.visible = false
	if _front_mat != null:
		_front_mat.set_shader_parameter("card_tex", CardArt.texture("playing", card_label))
