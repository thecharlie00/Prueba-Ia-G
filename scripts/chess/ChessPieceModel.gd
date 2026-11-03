class_name ChessPieceModel
extends RefCounted

# Modelos originales formados por primitivas; la pieza lógica no depende del mesh.
const SYMBOLS := {1: "P", 2: "C", 3: "A", 4: "T", 5: "D", 6: "R"}
const HEIGHTS := {1: 0.34, 2: 0.44, 3: 0.445, 4: 0.395, 5: 0.47, 6: 0.49}
static var _meshes: Dictionary = {}


static func height(kind: int) -> float:
	return HEIGHTS.get(kind, 0.34)


static func create(kind: int, white: bool, material: Material) -> Node3D:
	var model := Node3D.new()
	model.name = "ChessModel"
	model.set_meta("kind", kind)
	model.set_meta("white", white)
	_cylinder(model, "Base", 0.17, 0.15, 0.06, 0.03, material)
	_cylinder(model, "Rim", 0.135, 0.145, 0.035, 0.077, material)
	match kind:
		ChessRules.PAWN:
			_cylinder(model, "Stem", 0.055, 0.105, 0.15, 0.17, material)
			_sphere(model, "Head", 0.063, Vector3(0, 0.275, 0), material)
		ChessRules.KNIGHT:
			_knight(model, white, material)
		ChessRules.BISHOP:
			_cylinder(model, "Stem", 0.055, 0.105, 0.18, 0.185, material)
			_cylinder(model, "Collar", 0.09, 0.095, 0.035, 0.29, material)
			_cylinder(model, "Mitre", 0.012, 0.085, 0.115, 0.362, material)
			_sphere(model, "Tip", 0.018, Vector3(0, 0.425, 0), material)
		ChessRules.ROOK:
			_cylinder(model, "Tower", 0.105, 0.11, 0.20, 0.195, material)
			_cylinder(model, "Battlement", 0.13, 0.115, 0.045, 0.317, material)
			for i in range(4):
				var a := TAU * i / 4.0
				_box(
					model,
					"Merlon%d" % i,
					Vector3(0.055, 0.055, 0.055),
					Vector3(cos(a) * 0.075, 0.365, sin(a) * 0.075),
					material
				)
		ChessRules.QUEEN:
			_cylinder(model, "Stem", 0.07, 0.108, 0.21, 0.20, material)
			_cylinder(model, "Crown", 0.125, 0.065, 0.085, 0.347, material)
			for i in range(5):
				var a := TAU * i / 5.0
				_sphere(
					model,
					"Jewel%d" % i,
					0.025,
					Vector3(cos(a) * 0.093, 0.415, sin(a) * 0.093),
					material
				)
			_sphere(model, "Center", 0.03, Vector3(0, 0.435, 0), material)
		ChessRules.KING:
			_cylinder(model, "Stem", 0.075, 0.11, 0.22, 0.205, material)
			_cylinder(model, "Crown", 0.12, 0.075, 0.065, 0.35, material)
			_box(model, "CrossStem", Vector3(0.035, 0.11, 0.035), Vector3(0, 0.435, 0), material)
			_box(model, "CrossArm", Vector3(0.105, 0.035, 0.035), Vector3(0, 0.45, 0), material)
	var label := Label3D.new()
	label.name = "PieceLetter"
	label.text = SYMBOLS.get(kind, "?")
	label.font_size = 56
	label.pixel_size = 0.0028
	label.rotation_degrees.x = -90
	label.position.y = height(kind) + 0.015
	label.modulate = Color("26382f") if white else Color("f5ead5")
	model.add_child(label)
	return model


static func _knight(model: Node3D, white: bool, material: Material) -> void:
	var head := Node3D.new()
	head.name = "KnightProfile"
	head.rotation.y = 0.0 if white else PI
	model.add_child(head)
	var neck := _cylinder(head, "Neck", 0.065, 0.105, 0.19, 0.19, material)
	neck.rotation_degrees.x = -17
	_box(head, "Head", Vector3(0.13, 0.13, 0.12), Vector3(0, 0.315, -0.025), material)
	_box(head, "Muzzle", Vector3(0.11, 0.07, 0.12), Vector3(0, 0.285, -0.115), material)
	for x in [-0.045, 0.045]:
		var ear := _cylinder(head, "Ear", 0.008, 0.022, 0.075, 0.40, material)
		ear.position.x = x


static func _cylinder(
	parent: Node3D, part: String, bottom: float, top: float, h: float, y: float, material: Material
) -> MeshInstance3D:
	var key := "c:%.4f:%.4f:%.4f" % [bottom, top, h]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = bottom
		mesh.top_radius = top
		mesh.height = h
		mesh.radial_segments = 20
		_meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = _meshes[key]
	node.position.y = y
	node.material_override = material
	parent.add_child(node)
	return node


static func _sphere(
	parent: Node3D, part: String, radius: float, position: Vector3, material: Material
) -> void:
	var key := "s:%.4f" % radius
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2
		mesh.radial_segments = 16
		mesh.rings = 8
		_meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = _meshes[key]
	node.position = position
	node.material_override = material
	parent.add_child(node)


static func _box(
	parent: Node3D, part: String, size: Vector3, position: Vector3, material: Material
) -> void:
	var key := "b:%.4f:%.4f:%.4f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = _meshes[key]
	node.position = position
	node.material_override = material
	parent.add_child(node)
