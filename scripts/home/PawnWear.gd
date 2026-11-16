class_name PawnWear
## Sombreros y complementos del peón. Se cuelgan de la cabeza de un muñeco hecho con
## HomeDecor.make_meeple (cabeza «Head» de radio 0,46 y alto 0,84, ojos hacia +z).

const SLOT_HAT := "WearHat"
const SLOT_ACCESSORY := "WearAccessory"


static func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	return HomeDecor.add_mesh(parent, mesh, at, color)


static func _sphere(r: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 32
	return mesh


## Pone el sombrero y el complemento indicados (quita los anteriores).
static func apply(meeple: Node3D, hat_id: String, accessory_id: String) -> void:
	var head := meeple.get_node_or_null("Head") as Node3D
	if head == null:
		return
	for slot in [SLOT_HAT, SLOT_ACCESSORY]:
		var old := head.get_node_or_null(slot)
		if old != null:
			head.remove_child(old)
			old.queue_free()
	var hat := Node3D.new()
	hat.name = SLOT_HAT
	head.add_child(hat)
	build_hat(hat, hat_id)
	var accessory := Node3D.new()
	accessory.name = SLOT_ACCESSORY
	head.add_child(accessory)
	build_accessory(accessory, accessory_id)


static func build_hat(root: Node3D, id: String) -> void:
	match id:
		"gorro":
			var cap := _mesh(root, _sphere(0.44), Vector3(0, 0.22, -0.02), Palette.CORAL)
			cap.scale = Vector3(1.05, 0.62, 1.05)
			_mesh(root, PieceKit.torus(0.42, 0.07, 32), Vector3(0, 0.16, -0.02), Palette.PAPER)
			_mesh(root, _sphere(0.11), Vector3(0, 0.5, -0.02), Palette.PAPER)
		"gorra":
			var dome := _mesh(root, _sphere(0.45), Vector3(0, 0.2, 0), Color("4fa3ff"))
			dome.scale = Vector3(1.03, 0.6, 1.03)
			var brim := _mesh(root, PieceKit.rounded_box(Vector3(0.5, 0.05, 0.4), 0.02), Vector3(0, 0.18, 0.45), Color("3a86e0"))
			brim.rotation.x = -0.15
			_mesh(root, _sphere(0.05), Vector3(0, 0.47, 0), Palette.SUN)
		"cono":
			var cone := _mesh(root, _cylinder(0.0, 0.24, 0.55), Vector3(0.05, 0.62, 0), Palette.MINT)
			cone.rotation.z = -0.15
			for k in 3:
				_mesh(cone, PieceKit.torus(0.16 - k * 0.05, 0.025, 20), Vector3(0, -0.18 + k * 0.15, 0), Palette.CORAL)
			_mesh(cone, _sphere(0.07), Vector3(0, 0.3, 0), Palette.SUN)
		"flor":
			var center := _mesh(root, _sphere(0.08), Vector3(0.22, 0.38, 0.12), Palette.SUN)
			for k in 6:
				var angle := TAU * k / 6.0
				var petal := _mesh(center, _sphere(0.07), Vector3(cos(angle) * 0.11, sin(angle) * 0.11, -0.02), Palette.PAPER)
				petal.scale = Vector3(1.0, 1.0, 0.45)
			center.rotation.y = 0.5
		"auriculares":
			var band := _mesh(root, PieceKit.torus(0.47, 0.04, 40), Vector3(0, 0.05, 0), Palette.INK.lightened(0.15))
			band.rotation.x = PI / 2.0
			for side in [-1.0, 1.0]:
				var cup := _mesh(root, _cylinder(0.14, 0.14, 0.12), Vector3(side * 0.46, 0.0, 0), Palette.CORAL)
				cup.rotation.z = PI / 2.0
		"chistera":
			_mesh(root, PieceKit.rounded_disc(0.42, 0.05, 0.02, 32), Vector3(0, 0.3, 0), Palette.INK.lightened(0.1))
			_mesh(root, _cylinder(0.27, 0.27, 0.5), Vector3(0, 0.58, 0), Palette.INK.lightened(0.1))
			_mesh(root, _cylinder(0.275, 0.275, 0.09), Vector3(0, 0.38, 0), Palette.CORAL)
		"corona":
			_mesh(root, _cylinder(0.3, 0.27, 0.16), Vector3(0, 0.38, 0), Palette.SUN)
			for k in 5:
				var angle := TAU * k / 5.0
				var spike := _mesh(root, _cylinder(0.0, 0.07, 0.18), Vector3(cos(angle) * 0.25, 0.54, sin(angle) * 0.25), Palette.SUN)
				_mesh(spike, _sphere(0.035), Vector3(0, 0.1, 0), Palette.CORAL)


static func build_accessory(root: Node3D, id: String) -> void:
	match id:
		"gafas":
			for side in [-1.0, 1.0]:
				_mesh(root, PieceKit.torus(0.12, 0.022, 24), Vector3(side * 0.17, 0.06, 0.46), Palette.INK).rotation.x = PI / 2.0
			_mesh(root, PieceKit.rounded_box(Vector3(0.12, 0.025, 0.025), 0.01), Vector3(0, 0.08, 0.47), Palette.INK)
		"bigote":
			for side in [-1.0, 1.0]:
				var half := _mesh(root, _sphere(0.08), Vector3(side * 0.08, -0.13, 0.42), Color("6b3a22"))
				half.scale = Vector3(1.4, 0.55, 0.6)
				half.rotation.z = side * -0.3
		"pajarita":
			for side in [-1.0, 1.0]:
				var wing := _mesh(root, _cylinder(0.0, 0.11, 0.18), Vector3(side * 0.09, -0.48, 0.4), Palette.CORAL)
				wing.rotation.z = side * PI / 2.0
			_mesh(root, _sphere(0.05), Vector3(0, -0.48, 0.42), Palette.CORAL.darkened(0.2))
		"bufanda":
			var ring := _mesh(root, PieceKit.torus(0.38, 0.1, 32), Vector3(0, -0.42, 0), Palette.MINT)
			ring.scale = Vector3(1.0, 1.0, 1.0)
			var tail := _mesh(root, PieceKit.rounded_box(Vector3(0.16, 0.42, 0.08), 0.04), Vector3(0.2, -0.65, 0.36), Palette.MINT.darkened(0.08))
			tail.rotation.z = 0.15
