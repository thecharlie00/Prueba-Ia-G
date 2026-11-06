class_name IslandPiece3D
extends InteractiveTableObject

@export_enum("settlement", "city", "road", "robber") var kind := "settlement"
@export var piece_color := Color("e6b466")


func _ready() -> void:
	super._ready()
	_rebuild()


func set_kind(value: String) -> void:
	if value == kind or value not in ["settlement", "city", "road", "robber"]:
		return
	kind = value
	_rebuild()


func _rebuild() -> void:
	var names := {"settlement": "Pueblo", "city": "Ciudad", "road": "Camino", "robber": "Ladrón"}
	display_name = names[kind]
	for child in $Visual.get_children():
		$Visual.remove_child(child)
		child.queue_free()
	var material := StandardMaterial3D.new()
	material.albedo_color = piece_color
	material.roughness = 0.65
	var shape := BoxShape3D.new()
	match kind:
		"road":
			shape.size = Vector3(0.31, 0.075, 0.075)
			_box(Vector3(0.31, 0.075, 0.075), Vector3.ZERO, material)
		"settlement":
			# Casita: un cuerpo y un tejado a dos aguas, con puerta.
			shape.size = Vector3(0.14, 0.18, 0.14)
			_box(Vector3(0.14, 0.12, 0.14), Vector3(0, -0.03, 0), material)
			_roof(Vector3(0, 0.03, 0), 0.17, 0.16, material)
			_doors(Vector3(0.034, 0.05, 0.004), Vector3(0, -0.06, 0), 0.071)
		"city":
			# Ciudad: casa ancha y una torre alta con tejado en punta; se distingue del pueblo
			# por la silueta aunque se vea de lejos o en blanco y negro.
			shape.size = Vector3(0.2, 0.26, 0.14)
			_box(Vector3(0.2, 0.11, 0.14), Vector3(-0.0, -0.075, 0), material)
			_roof(Vector3(-0.045, -0.02, 0), 0.13, 0.16, material)
			_box(Vector3(0.08, 0.2, 0.08), Vector3(0.055, -0.03, 0), material)
			_spire(Vector3(0.055, 0.1, 0), 0.062, 0.085, material)
			_doors(Vector3(0.034, 0.05, 0.004), Vector3(-0.045, -0.105, 0), 0.071)
		"robber":
			shape.size = Vector3(0.14, 0.20, 0.14)
			_robber(material)
	$CollisionShape3D.shape = shape
	_update_highlight()


func _box(size: Vector3, position: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.mesh = PieceKit.rounded_box(size, minf(0.022, minf(size.x, minf(size.y, size.z)) * 0.3))
	node.position = position
	node.material_override = material
	$Visual.add_child(node)


# Tejado a dos aguas: prisma triangular apoyado en lo alto de la pared (base = position).
func _roof(base: Vector3, width: float, depth: float, material: Material) -> void:
	var radius := width / sqrt(3.0)
	var prism := CylinderMesh.new()
	prism.radial_segments = 3
	prism.rings = 1
	prism.top_radius = radius
	prism.bottom_radius = radius
	prism.height = depth
	var node := MeshInstance3D.new()
	node.mesh = prism
	# Eje del prisma a lo largo de z y un vértice hacia arriba.
	node.rotation.x = -PI / 2.0
	node.position = base + Vector3(0, radius * 0.5, 0)
	var roof := StandardMaterial3D.new()
	roof.albedo_color = (material as StandardMaterial3D).albedo_color.darkened(0.3)
	node.material_override = roof
	$Visual.add_child(node)


func _spire(position: Vector3, radius: float, height: float, material: StandardMaterial3D) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 4
	cone.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = cone
	node.position = position + Vector3(0, height * 0.5, 0)
	node.rotation.y = PI / 4.0
	var roof := StandardMaterial3D.new()
	roof.albedo_color = material.albedo_color.darkened(0.25)
	node.material_override = roof
	$Visual.add_child(node)


# Puertas de tinta delante y detrás (la pieza puede quedar girada).
func _doors(size: Vector3, position: Vector3, depth: float) -> void:
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Palette.INK
	for side in [-1.0, 1.0]:
		var door := MeshInstance3D.new()
		door.mesh = PieceKit.rounded_box(size, 0.004)
		door.position = position + Vector3(0, 0, side * depth)
		door.material_override = ink
		$Visual.add_child(door)


# Ladrón: figura torneada oscura con dos ojos blancos.
func _robber(material: StandardMaterial3D) -> void:
	material.albedo_color = Palette.PANEL
	var body := MeshInstance3D.new()
	body.mesh = PieceKit.lathe(
		PieceKit.smooth_profile(
			PackedVector2Array(
				[
					Vector2(0.07, -0.1), Vector2(0.065, -0.04), Vector2(0.045, 0.01),
					Vector2(0.06, 0.05), Vector2(0.05, 0.09), Vector2(0.0, 0.105)
				]
			)
		),
		28
	)
	body.material_override = material
	$Visual.add_child(body)
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Palette.PAPER
	for x in [-0.02, 0.02]:
		var node := MeshInstance3D.new()
		node.mesh = PieceKit.dot(0.012, 0.007)
		node.position = Vector3(x, 0.055, 0.057)
		node.rotation_degrees.x = 90
		node.material_override = eye
		$Visual.add_child(node)


func _update_highlight() -> void:
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual == null:
		return
	var overlay: Material = _highlight if hovered or is_grabbed else null
	for child in visual.get_children():
		if child is MeshInstance3D:
			child.material_overlay = overlay
