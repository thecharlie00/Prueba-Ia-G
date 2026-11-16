class_name HomeProps
## Atrezo de la habitación: ventana, cuadros con portadas, plantas, guirnalda de luces,
## reloj, puf con gato, suelo de tablas y cajas de juegos. Solo construye; las animaciones
## viven en Home (que guarda las referencias que devuelven estas funciones).

const LEAF := Color("4fb36d")
const POT := Color("e2765a")


static func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


## Tablas del suelo: franjas algo más oscuras cada metro.
static func floor_planks(parent: Node) -> void:
	for i in range(-9, 10):
		var strip := QuadMesh.new()
		strip.size = Vector2(0.05, 16)
		var line := HomeDecor.add_mesh(parent, strip, Vector3(i + 0.5, 0.004, -0.5), Palette.FLOOR.darkened(0.07))
		line.rotation.x = -PI / 2.0


## Ventana con cielo, marco y cortinas. Devuelve las cortinas (para mecerlas).
static func window(parent: Node, center: Vector3, facing_y: float) -> Array[Node3D]:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = facing_y
	parent.add_child(root)
	var sky := QuadMesh.new()
	sky.size = Vector2(2.2, 1.7)
	var glass := MeshInstance3D.new()
	glass.mesh = sky
	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("ffd9a0"), Color("8fd0ff")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 1)
	texture.fill_to = Vector2(0, 0)
	sky_mat.albedo_texture = texture
	glass.material_override = sky_mat
	glass.position.z = 0.02
	root.add_child(glass)
	# Nubes y un sol.
	for cloud in [Vector3(-0.45, 0.35, 0.04), Vector3(0.5, 0.05, 0.04)]:
		for k in 3:
			var puff := MeshInstance3D.new()
			puff.mesh = _sphere(0.16 - k * 0.02)
			puff.scale = Vector3(1, 1, 0.15)
			puff.material_override = _mat(Color.WHITE, true)
			puff.position = cloud + Vector3(k * 0.17 - 0.17, absf(k - 1) * -0.04, 0)
			root.add_child(puff)
	var sun := MeshInstance3D.new()
	sun.mesh = _sphere(0.18)
	sun.scale = Vector3(1, 1, 0.15)
	sun.material_override = _mat(Color("ffe27a"), true)
	sun.position = Vector3(0.65, 0.5, 0.03)
	root.add_child(sun)
	HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(2.5, 0.16, 0.22), 0.05), Vector3(0, 0.93, 0.08), Palette.PAPER)
	HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(2.7, 0.18, 0.45), 0.06), Vector3(0, -0.93, 0.16), Palette.PAPER)
	for side in [-1.0, 1.0]:
		HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(0.16, 1.9, 0.22), 0.05), Vector3(side * 1.18, 0, 0.08), Palette.PAPER)
	HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(0.08, 1.7, 0.1), 0.03), Vector3(0, 0, 0.06), Palette.PAPER)
	HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(2.2, 0.08, 0.1), 0.03), Vector3(0, 0, 0.06), Palette.PAPER)
	var curtains: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 1.45, 1.05, 0.3)
		root.add_child(pivot)
		var cloth := HomeDecor.add_mesh(pivot, PieceKit.rounded_box(Vector3(0.55, 2.4, 0.12), 0.06), Vector3(0, -1.2, 0), Palette.CORAL)
		cloth.scale = Vector3(1, 1, 1)
		HomeDecor.add_mesh(pivot, PieceKit.rounded_box(Vector3(0.6, 0.1, 0.16), 0.04), Vector3(0, -1.5, 0.02), Palette.SUN)
		curtains.append(pivot)
	HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(3.6, 0.08, 0.08), 0.03), Vector3(0, 1.1, 0.32), Palette.WOOD.darkened(0.2))
	# Haz de luz que entra por la ventana.
	var beam := MeshInstance3D.new()
	var beam_mesh := PrismMesh.new()
	beam_mesh.size = Vector3(2.0, 3.2, 0.02)
	beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(1.0, 0.92, 0.7, 0.13)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beam_mat
	beam.set_meta(&"toon_skip", true)
	beam.position = Vector3(0, -1.2, 1.3)
	beam.rotation = Vector3(-0.9, 0, PI)
	root.add_child(beam)
	return curtains


## Cuadro enmarcado con una portada y una placa con el nombre del juego.
static func poster(parent: Node, cover_key: String, center: Vector3, facing_y: float, tilt := 0.0, height := 1.5) -> Node3D:
	var root := Node3D.new()
	root.name = "Poster_" + cover_key
	root.position = center
	root.rotation = Vector3(0, facing_y, deg_to_rad(tilt))
	parent.add_child(root)
	var width := height * GameCovers.ASPECT
	HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(width + 0.22, height + 0.22, 0.1), 0.05), Vector3(0, 0, 0.05), Palette.WOOD.darkened(0.15))
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var art := MeshInstance3D.new()
	art.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = GameCovers.texture(cover_key)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	art.material_override = material
	art.set_meta(&"toon_skip", true)
	art.position.z = 0.115
	root.add_child(art)
	var plate := Label3D.new()
	plate.text = GameCovers.title(cover_key)
	plate.font = MenuStyle.DISPLAY_FONT
	plate.font_size = 40
	plate.pixel_size = 0.006
	plate.outline_size = 12
	plate.outline_modulate = Palette.INK
	plate.modulate = Palette.PAPER
	plate.position = Vector3(0, -height * 0.5 - 0.3, 0.12)
	root.add_child(plate)
	return root


## Caja de juego de pie con la portada en la cara de delante.
static func game_box(parent: Node, cover_key: String, center: Vector3, size := Vector3(0.6, 0.75, 0.5)) -> MeshInstance3D:
	var info := MenuStyle.theme_info(cover_key)
	var box := HomeDecor.add_mesh(parent, PieceKit.rounded_box(size, 0.04), center, (info["accent"] as Color))
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x - 0.04, size.y - 0.04)
	var art := MeshInstance3D.new()
	art.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = GameCovers.texture(cover_key)
	art.material_override = material
	art.set_meta(&"toon_skip", true)
	art.position.z = size.z * 0.5 + 0.004
	box.add_child(art)
	return box


## Maceta con hojas. Devuelve el nodo de las hojas (para mecerlas).
static func plant(parent: Node, center: Vector3, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = center
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	var pot := CylinderMesh.new()
	pot.top_radius = 0.42
	pot.bottom_radius = 0.32
	pot.height = 0.7
	HomeDecor.add_mesh(root, pot, Vector3(0, 0.35, 0), POT)
	HomeDecor.add_mesh(root, PieceKit.rounded_disc(0.45, 0.1, 0.04, 32), Vector3(0, 0.68, 0), POT.darkened(0.12))
	var leaves := Node3D.new()
	leaves.position.y = 0.7
	root.add_child(leaves)
	for i in 7:
		var angle := TAU * float(i) / 7.0
		var leaf := HomeDecor.add_mesh(leaves, _sphere(0.22), Vector3(cos(angle) * 0.22, 0.45 + float(i % 3) * 0.22, sin(angle) * 0.22), LEAF.lightened(float(i % 3) * 0.08))
		leaf.scale = Vector3(0.55, 1.9, 0.3)
		leaf.rotation = Vector3(sin(angle) * 0.6, -angle, cos(angle) * 0.6)
	return leaves


## Guirnalda de bombillas que cuelga de un punto a otro. Devuelve las bombillas.
static func garland(parent: Node, from: Vector3, to: Vector3, count := 14, sag := 0.5) -> Array[MeshInstance3D]:
	var bulbs: Array[MeshInstance3D] = []
	var colors := [Palette.SUN, Palette.CORAL, Palette.MINT, Color("7cc6fe"), Palette.LAVENDER]
	var previous := from
	for i in count + 1:
		var t := float(i) / float(count)
		var point := from.lerp(to, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		if i > 0:
			var cable := CylinderMesh.new()
			cable.top_radius = 0.012
			cable.bottom_radius = 0.012
			cable.height = previous.distance_to(point)
			var piece := HomeDecor.add_mesh(parent, cable, (previous + point) * 0.5, Palette.INK)
			piece.look_at_from_position(piece.position, point, Vector3.UP if absf((point - previous).normalized().y) < 0.99 else Vector3.RIGHT)
			piece.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		if i > 0 and i < count:
			var bulb := MeshInstance3D.new()
			bulb.mesh = _sphere(0.075)
			bulb.scale = Vector3(1, 1.3, 1)
			bulb.position = point + Vector3(0, -0.09, 0)
			var material := _mat(colors[i % colors.size()], true)
			bulb.material_override = material
			bulb.set_meta(&"toon_skip", true)
			parent.add_child(bulb)
			bulbs.append(bulb)
		previous = point
	return bulbs


## Reloj de pared. Devuelve [aguja de horas, aguja de minutos] (pivotes).
static func clock(parent: Node, center: Vector3) -> Array[Node3D]:
	var root := Node3D.new()
	root.position = center
	parent.add_child(root)
	var face := HomeDecor.add_mesh(root, PieceKit.rounded_disc(0.42, 0.1, 0.04, 40), Vector3.ZERO, Palette.PAPER)
	face.rotation.x = PI / 2.0
	var rim := HomeDecor.add_mesh(root, PieceKit.torus(0.42, 0.05, 40), Vector3(0, 0, 0.02), Palette.CORAL)
	rim.rotation.x = PI / 2.0
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var tick := HomeDecor.add_mesh(root, _sphere(0.025 if i % 3 else 0.04), Vector3(sin(angle) * 0.32, cos(angle) * 0.32, 0.07), Palette.INK)
		tick.scale.z = 0.4
	var hands: Array[Node3D] = []
	for spec in [[0.18, 0.035], [0.29, 0.025]]:
		var pivot := Node3D.new()
		pivot.position.z = 0.08
		root.add_child(pivot)
		HomeDecor.add_mesh(pivot, PieceKit.rounded_box(Vector3(spec[1], spec[0], 0.02), 0.008), Vector3(0, spec[0] * 0.5, 0), Palette.INK)
		hands.append(pivot)
	HomeDecor.add_mesh(root, _sphere(0.04), Vector3(0, 0, 0.1), Palette.SUN)
	return hands


## Puf con un gato de arcilla dormido. Devuelve el gato (con hijos Head, Tail, EyesOpen, EyesClosed).
static func cat_on_beanbag(parent: Node, center: Vector3, facing_y: float) -> Node3D:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = facing_y
	parent.add_child(root)
	var bag := HomeDecor.add_mesh(root, _sphere(0.85), Vector3(0, 0.45, 0), Color("7cc6fe"))
	bag.scale = Vector3(1.0, 0.55, 1.0)
	var dent := HomeDecor.add_mesh(root, _sphere(0.6), Vector3(0, 0.72, 0), Color("6ab4ec"))
	dent.scale = Vector3(1.0, 0.25, 1.0)
	var cat := Node3D.new()
	cat.name = "Cat"
	cat.position = Vector3(0, 0.82, 0)
	root.add_child(cat)
	var fur := Color("ff9d4d")
	var body := HomeDecor.add_mesh(cat, _sphere(0.36), Vector3(0, 0.12, 0), fur)
	body.name = "Body"
	body.scale = Vector3(1.25, 0.72, 0.95)
	var head := HomeDecor.add_mesh(cat, _sphere(0.24), Vector3(0.36, 0.2, 0.12), fur.lightened(0.05))
	head.name = "Head"
	for side in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.09
		ear.height = 0.16
		HomeDecor.add_mesh(head, ear, Vector3(-0.02, 0.2, side * 0.11), fur.darkened(0.08))
	var closed := Node3D.new()
	closed.name = "EyesClosed"
	head.add_child(closed)
	var opened := Node3D.new()
	opened.name = "EyesOpen"
	opened.visible = false
	head.add_child(opened)
	for side in [-1.0, 1.0]:
		var lid := HomeDecor.add_mesh(closed, PieceKit.rounded_box(Vector3(0.02, 0.025, 0.09), 0.01), Vector3(0.22, 0.03, side * 0.08), Palette.INK)
		lid.rotation.y = 0.0
		var eye := HomeDecor.add_mesh(opened, _sphere(0.075), Vector3(0.19, 0.05, side * 0.09), Palette.PAPER)
		HomeDecor.add_mesh(eye, _sphere(0.04), Vector3(0.045, 0, 0), Palette.INK)
	HomeDecor.add_mesh(head, _sphere(0.035), Vector3(0.235, -0.03, 0), Palette.CORAL)
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(-0.38, 0.08, -0.1)
	cat.add_child(tail)
	var tail_mesh := HomeDecor.add_mesh(tail, PieceKit.rounded_box(Vector3(0.1, 0.1, 0.5), 0.05), Vector3(0, 0, -0.22), fur.darkened(0.05))
	tail_mesh.rotation.y = 0.4
	return cat
