class_name Card3D
extends InteractiveTableObject

@export var flip_duration := 0.35
@export var card_label := "A"
var _flipping := false


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
	display_name = "Carta " + value + " · F para voltear"
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


# Carta de canto grueso y esquinas redondeadas con la ilustración de CardArt en las dos caras.
# La caja de colisión de la escena no cambia. Las etiquetas de texto se conservan (inspección
# y tests) pero ocultas: el aspecto lo da la ilustración.
func _shape_card() -> void:
	$Visual.mesh = PieceKit.rounded_slab(Vector3(0.68, 0.05, 0.96), 0.08, 0.022)
	if $Visual.material_override is StandardMaterial3D:
		($Visual.material_override as StandardMaterial3D).albedo_color = Color("fff1d9")
	var quad := QuadMesh.new()
	quad.size = Vector2(0.68, 0.96)
	for side in ["Front", "Back"]:
		var node := get_node_or_null("Visual/" + side) as MeshInstance3D
		if node == null:
			continue
		node.mesh = quad
		node.rotation_degrees.x = -90 if side == "Front" else 90
		node.position.y = 0.0265 if side == "Front" else -0.0265
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.albedo_texture = CardArt.texture("back") if side == "Back" else null
		node.material_override = material
	_apply_art.call_deferred()


func _apply_art() -> void:
	for node_name in ["FaceLabel", "Corner0", "Corner1"]:
		var label := get_node_or_null("Visual/" + node_name) as Label3D
		if label != null:
			label.visible = false
	var front := get_node_or_null("Visual/Front") as MeshInstance3D
	if front != null and front.material_override is StandardMaterial3D:
		(front.material_override as StandardMaterial3D).albedo_texture = CardArt.texture(
			"playing", card_label
		)
