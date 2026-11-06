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


# Carta de canto grueso y esquinas muy redondeadas; anverso crema y reverso de la paleta.
# La caja de colisión de la escena no cambia.
func _shape_card() -> void:
	$Visual.mesh = PieceKit.rounded_slab(Vector3(0.68, 0.05, 0.96), 0.08, 0.022)
	var face := PieceKit.rounded_slab(Vector3(0.58, 0.006, 0.86), 0.06, 0.003)
	for side in ["Front", "Back"]:
		var node := get_node_or_null("Visual/" + side) as MeshInstance3D
		if node != null:
			node.mesh = face
	var front := get_node_or_null("Visual/Front") as MeshInstance3D
	if front != null and front.material_override is StandardMaterial3D:
		(front.material_override as StandardMaterial3D).albedo_color = Color("fff8ec")
	var back := get_node_or_null("Visual/Back") as MeshInstance3D
	if back != null and back.material_override is StandardMaterial3D:
		(back.material_override as StandardMaterial3D).albedo_color = Color("ff6b5e")
	if $Visual.material_override is StandardMaterial3D:
		($Visual.material_override as StandardMaterial3D).albedo_color = Color("fff1d9")
