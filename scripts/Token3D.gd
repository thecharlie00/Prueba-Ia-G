class_name Token3D
extends InteractiveTableObject

@export var piece_color := Color("ddae60")
var is_king := false
var _crown: Node3D


func _ready() -> void:
	super._ready()
	var material := StandardMaterial3D.new()
	material.albedo_color = piece_color
	material.roughness = 0.52
	# Ficha gruesa de canto redondeado (docs/ARTE.md); el cilindro de colisión no cambia.
	$Visual.mesh = PieceKit.rounded_disc(0.2, 0.12, 0.045)
	$Visual.material_override = material
	_make_inlay(material)
	_make_crown()


# Molduras solo visuales; la forma de colisión cilíndrica sigue siendo única.
func _make_inlay(face_material: Material) -> void:
	var trim := StandardMaterial3D.new()
	trim.albedo_color = (
		piece_color.darkened(0.32)
		if piece_color.get_luminance() > 0.3
		else piece_color.lightened(0.32)
	)
	trim.roughness = 0.58
	var rim := MeshInstance3D.new()
	rim.name = "InlayRim"
	rim.mesh = PieceKit.torus(0.128, 0.014)
	rim.position.y = 0.06
	rim.material_override = trim
	$Visual.add_child(rim)
	var face := MeshInstance3D.new()
	face.name = "InlayFace"
	face.mesh = PieceKit.rounded_disc(0.11, 0.008, 0.004)
	face.position.y = 0.061
	face.material_override = face_material
	$Visual.add_child(face)


func set_king(value: bool) -> void:
	is_king = value
	if is_instance_valid(_crown):
		_crown.visible = value


func _make_crown() -> void:
	_crown = Node3D.new()
	_crown.name = "Crown"
	add_child(_crown)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffc83d")
	# Corona cartoon: aro dorado con cinco bolitas en el borde.
	var ring := MeshInstance3D.new()
	ring.mesh = PieceKit.lathe(
		PieceKit.smooth_profile(
			PackedVector2Array([Vector2(0.1, 0.0), Vector2(0.115, 0.02), Vector2(0.12, 0.045)])
		),
		32,
		false
	)
	ring.position.y = 0.06
	ring.material_override = material
	_crown.add_child(ring)
	for i in 5:
		var a := TAU * i / 5.0
		var ball := MeshInstance3D.new()
		ball.mesh = PieceKit.dot(0.022, 0.022)
		ball.position = Vector3(cos(a) * 0.12, 0.11, sin(a) * 0.12)
		ball.material_override = material
		_crown.add_child(ball)
	var label := Label3D.new()
	label.text = "D"
	label.font_size = 56
	label.pixel_size = 0.003
	label.rotation_degrees.x = -90.0
	label.position.y = 0.075
	label.modulate = Color("202d29")
	_crown.add_child(label)
	_crown.visible = is_king
