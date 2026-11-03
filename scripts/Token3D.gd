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
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.171
	rim_mesh.bottom_radius = 0.171
	rim_mesh.height = 0.006
	var rim := MeshInstance3D.new()
	rim.name = "InlayRim"
	rim.mesh = rim_mesh
	rim.position.y = 0.061
	rim.material_override = trim
	$Visual.add_child(rim)
	var face_mesh := CylinderMesh.new()
	face_mesh.top_radius = 0.138
	face_mesh.bottom_radius = 0.138
	face_mesh.height = 0.004
	var face := MeshInstance3D.new()
	face.name = "InlayFace"
	face.mesh = face_mesh
	face.position.y = 0.066
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
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.115
	mesh.bottom_radius = 0.12
	mesh.height = 0.035
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d8af5d")
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.position.y = 0.078
	ring.material_override = material
	_crown.add_child(ring)
	var label := Label3D.new()
	label.text = "D"
	label.font_size = 56
	label.pixel_size = 0.003
	label.rotation_degrees.x = -90.0
	label.position.y = 0.098
	label.modulate = Color("202d29")
	_crown.add_child(label)
	_crown.visible = is_king
