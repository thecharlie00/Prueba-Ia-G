class_name ChessPieceModel
extends RefCounted

# Modelos originales cartoon (docs/ARTE.md): cada pieza tiene un cuerpo torneado de una sola
# malla con proporciones chatas y cabezas grandes, más adornos redondeados con nombre propio.
# La pieza lógica no depende del mesh, y los colisionadores se definen aparte.
const SYMBOLS := {1: "P", 2: "C", 3: "A", 4: "T", 5: "D", 6: "R"}
const HEIGHTS := {1: 0.34, 2: 0.44, 3: 0.445, 4: 0.395, 5: 0.47, 6: 0.49}
static var _meshes: Dictionary = {}
static var _eye_white: StandardMaterial3D
static var _eye_ink: StandardMaterial3D


static func height(kind: int) -> float:
	return HEIGHTS.get(kind, 0.34)


static func create(kind: int, white: bool, material: Material) -> Node3D:
	var model := Node3D.new()
	model.name = "ChessModel"
	model.set_meta("kind", kind)
	model.set_meta("white", white)
	match kind:
		ChessRules.PAWN:
			_part(model, "Body", _body(kind), Vector3.ZERO, material)
		ChessRules.KNIGHT:
			_part(model, "Body", _body(kind), Vector3.ZERO, material)
			_knight(model, white, material)
		ChessRules.BISHOP:
			_part(model, "Body", _body(kind), Vector3.ZERO, material)
			_part(model, "Mitre", _mitre(), Vector3(0, 0.27, 0), material)
			_part(model, "Tip", PieceKit.dot(0.026, 0.026), Vector3(0, 0.43, 0), material)
		ChessRules.ROOK:
			_part(model, "Body", _body(kind), Vector3.ZERO, material)
			for i in range(4):
				var a := TAU * i / 4.0 + PI / 4.0
				_part(
					model,
					"Merlon%d" % i,
					PieceKit.rounded_box(Vector3(0.07, 0.065, 0.07), 0.022),
					Vector3(cos(a) * 0.088, 0.36, sin(a) * 0.088),
					material
				)
		ChessRules.QUEEN:
			_part(model, "Body", _body(kind), Vector3.ZERO, material)
			for i in range(5):
				var a := TAU * i / 5.0
				_part(
					model,
					"Jewel%d" % i,
					PieceKit.dot(0.03, 0.03),
					Vector3(cos(a) * 0.1, 0.41, sin(a) * 0.1),
					material
				)
			_part(model, "Center", PieceKit.dot(0.04, 0.04), Vector3(0, 0.43, 0), material)
		ChessRules.KING:
			_part(model, "Body", _body(kind), Vector3.ZERO, material)
			_part(
				model,
				"CrossStem",
				PieceKit.rounded_box(Vector3(0.045, 0.12, 0.045), 0.018),
				Vector3(0, 0.44, 0),
				material
			)
			_part(
				model,
				"CrossArm",
				PieceKit.rounded_box(Vector3(0.12, 0.045, 0.045), 0.018),
				Vector3(0, 0.45, 0),
				material
			)
	var label := Label3D.new()
	label.name = "PieceLetter"
	label.text = SYMBOLS.get(kind, "?")
	label.font_size = 56
	label.pixel_size = 0.0028
	label.rotation_degrees.x = -90
	label.position.y = height(kind) + 0.015
	label.modulate = Color("1d1a3a") if white else Color("fff8ec")
	label.outline_modulate = Color("fff8ec") if white else Color("1d1a3a")
	label.outline_size = 10
	model.add_child(label)
	return model


# Perfiles (radio, altura) de abajo arriba; la base es común y ancha para dar estabilidad visual.
static func _body(kind: int) -> ArrayMesh:
	var key := "body:%d" % kind
	if _meshes.has(key):
		return _meshes[key]
	var base := [Vector2(0.165, 0.0), Vector2(0.175, 0.03), Vector2(0.16, 0.06), Vector2(0.12, 0.08)]
	var top: Array = []
	match kind:
		ChessRules.PAWN:
			top = [
				Vector2(0.08, 0.13), Vector2(0.065, 0.18), Vector2(0.1, 0.2), Vector2(0.06, 0.215),
				Vector2(0.085, 0.24), Vector2(0.095, 0.28), Vector2(0.075, 0.325), Vector2(0.0, 0.345)
			]
		ChessRules.KNIGHT:
			top = [Vector2(0.11, 0.11), Vector2(0.09, 0.14), Vector2(0.0, 0.15)]
		ChessRules.BISHOP:
			top = [
				Vector2(0.085, 0.14), Vector2(0.07, 0.21), Vector2(0.105, 0.24), Vector2(0.075, 0.26),
				Vector2(0.0, 0.27)
			]
		ChessRules.ROOK:
			top = [
				Vector2(0.115, 0.12), Vector2(0.11, 0.24), Vector2(0.14, 0.3), Vector2(0.14, 0.33),
				Vector2(0.06, 0.335), Vector2(0.0, 0.32)
			]
		ChessRules.QUEEN:
			top = [
				Vector2(0.09, 0.15), Vector2(0.075, 0.24), Vector2(0.11, 0.28), Vector2(0.08, 0.3),
				Vector2(0.13, 0.38), Vector2(0.14, 0.4), Vector2(0.06, 0.405), Vector2(0.0, 0.4)
			]
		ChessRules.KING:
			top = [
				Vector2(0.095, 0.15), Vector2(0.08, 0.25), Vector2(0.115, 0.29), Vector2(0.085, 0.31),
				Vector2(0.125, 0.36), Vector2(0.1, 0.39), Vector2(0.0, 0.4)
			]
	var points := PackedVector2Array(base + top)
	var mesh := PieceKit.lathe(PieceKit.smooth_profile(points, 4), 36)
	_meshes[key] = mesh
	return mesh


static func _mitre() -> ArrayMesh:
	if not _meshes.has("mitre"):
		_meshes["mitre"] = PieceKit.lathe(
			PieceKit.smooth_profile(
				PackedVector2Array(
					[
						Vector2(0.0, 0.0), Vector2(0.075, 0.01), Vector2(0.1, 0.06),
						Vector2(0.075, 0.12), Vector2(0.0, 0.16)
					]
				),
				4
			),
			32
		)
	return _meshes["mitre"]


static func _knight(model: Node3D, white: bool, material: Material) -> void:
	var head := Node3D.new()
	head.name = "KnightProfile"
	head.rotation.y = 0.0 if white else PI
	model.add_child(head)
	var neck := _part(
		head,
		"Neck",
		PieceKit.rounded_box(Vector3(0.13, 0.22, 0.15), 0.05),
		Vector3(0, 0.24, 0.02),
		material
	)
	neck.rotation_degrees.x = -14
	_part(
		head,
		"Head",
		PieceKit.rounded_box(Vector3(0.15, 0.13, 0.17), 0.055),
		Vector3(0, 0.35, -0.03),
		material
	)
	_part(
		head,
		"Muzzle",
		PieceKit.rounded_box(Vector3(0.12, 0.09, 0.12), 0.04),
		Vector3(0, 0.31, -0.12),
		material
	)
	for x in [-0.045, 0.045]:
		var ear := _part(
			head, "Ear", PieceKit.rounded_box(Vector3(0.035, 0.07, 0.03), 0.015),
			Vector3(x, 0.43, 0.01), material
		)
		ear.rotation_degrees.z = -12.0 if x < 0.0 else 12.0
	# Ojos de dibujo animado: blanco con pupila de tinta a cada lado.
	if _eye_white == null:
		_eye_white = StandardMaterial3D.new()
		_eye_white.albedo_color = Color("fff8ec")
		_eye_ink = StandardMaterial3D.new()
		_eye_ink.albedo_color = Color("1d1a3a")
	for side in [-1.0, 1.0]:
		var eye := _part(
			head, "Eye", PieceKit.dot(0.024, 0.014), Vector3(side * 0.074, 0.37, -0.045), _eye_white
		)
		eye.rotation_degrees.z = -90.0 * side
		var pupil := _part(
			head, "Pupil", PieceKit.dot(0.012, 0.008), Vector3(side * 0.086, 0.37, -0.052), _eye_ink
		)
		pupil.rotation_degrees.z = -90.0 * side


static func _part(
	parent: Node3D, part: String, mesh: Mesh, position: Vector3, material: Material
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node
