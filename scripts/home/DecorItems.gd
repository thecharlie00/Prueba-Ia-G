class_name DecorItems
## Decoración que se compra en Dadazon. Cada objeto tiene su sitio fijo en la habitación
## (SLOTS) y su constructor; Home los coloca al abrir el paquete y al volver a entrar.
## Lo que se mueve (bola, pez, bot) lleva la meta «spin», «swim» o «follow» y Home lo anima.

const SLOTS := {
	"sofa": [Vector3(-8.0, 0, 5.2), PI / 2.0],
	"lampara": [Vector3(6.4, 0, 6.2), 0.0],
	"pecera": [Vector3(2.2, 0, -7.25), 0.0],
	"trofeo": [Vector3(7.75, 1.12, 3.35), -PI / 2.0],
	"neon": [Vector3(7.2, 3.3, -7.9), 0.0],
	"bola_disco": [Vector3(-3.6, 4.3, 1.4), 0.0],
	"cactus": [Vector3(-3.0, 0, 6.5), 0.0],
	"botito": [Vector3(1.4, 0, 5.4), 0.0],
}
## Huella en el suelo para que el peón no los atraviese (los colgados no tienen).
const FOOTPRINT := {
	"sofa": Vector3(1.3, 1.2, 2.8),
	"lampara": Vector3(0.6, 2.4, 0.6),
	"pecera": Vector3(0.8, 1.6, 0.8),
	"cactus": Vector3(0.6, 1.0, 0.6),
}


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


static func _glass(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## Construye el objeto en su sitio y lo devuelve (nodo raíz «Decor_<id>»).
static func build(parent: Node, id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Decor_" + id
	if SLOTS.has(id):
		root.position = SLOTS[id][0]
		root.rotation.y = SLOTS[id][1]
	parent.add_child(root)
	make(root, id)
	return root


## Solo la forma, en el origen de «root» (también sirve para las miniaturas de la tienda).
static func make(root: Node3D, id: String) -> void:
	match id:
		"sofa":
			var fabric := Color("b48cff")
			HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(1.2, 0.5, 2.7), 0.18), Vector3(0, 0.45, 0), fabric)
			HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(0.35, 0.9, 2.7), 0.16), Vector3(-0.45, 0.85, 0), fabric.darkened(0.08))
			for side in [-1.0, 1.0]:
				HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(1.2, 0.55, 0.32), 0.14), Vector3(0, 0.75, side * 1.3), fabric.darkened(0.12))
			var cushion := HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(0.18, 0.5, 0.5), 0.15), Vector3(-0.2, 0.95, 0.6), Palette.SUN) as MeshInstance3D
			cushion.rotation.x = 0.3
			for z in [-1.1, 1.1]:
				HomeDecor.add_mesh(root, _cylinder(0.06, 0.06, 0.2), Vector3(0.4, 0.1, z), Palette.WOOD.darkened(0.2))
		"lampara":
			HomeDecor.add_mesh(root, PieceKit.rounded_disc(0.3, 0.06, 0.02, 32), Vector3(0, 0.03, 0), Palette.INK.lightened(0.2))
			HomeDecor.add_mesh(root, _cylinder(0.035, 0.035, 2.0), Vector3(0, 1.05, 0), Palette.INK.lightened(0.2))
			HomeDecor.add_mesh(root, _cylinder(0.22, 0.38, 0.45), Vector3(0, 2.15, 0), Palette.MINT.lightened(0.2))
			var glow := OmniLight3D.new()
			glow.position = Vector3(0, 1.9, 0)
			glow.light_color = RoomDecor.WARM_SPOT
			glow.light_energy = 0.8
			glow.omni_range = 3.5
			root.add_child(glow)
		"pecera":
			HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(0.7, 0.9, 0.6), 0.06), Vector3(0, 0.45, 0), Palette.WOOD)
			var water := MeshInstance3D.new()
			water.mesh = _sphere(0.36)
			water.material_override = _glass(Color("7cc6fe"), 0.45)
			water.position = Vector3(0, 1.25, 0)
			water.scale = Vector3(1.0, 0.85, 1.0)
			root.add_child(water)
			HomeDecor.add_mesh(root, PieceKit.torus(0.22, 0.03, 32), Vector3(0, 1.53, 0), Color("dff3ff"))
			var fish := Node3D.new()
			fish.name = "Fish"
			fish.position = Vector3(0, 1.22, 0)
			fish.set_meta(&"swim", true)
			root.add_child(fish)
			var body := HomeDecor.add_mesh(fish, _sphere(0.09), Vector3(0.14, 0, 0), Palette.SUN.lerp(Palette.CORAL, 0.5)) as MeshInstance3D
			body.scale = Vector3(1.0, 0.75, 0.55)
			var tail := HomeDecor.add_mesh(fish, _cylinder(0.0, 0.07, 0.1), Vector3(0.24, 0, 0), Palette.CORAL) as MeshInstance3D
			tail.rotation.z = -PI / 2.0
			HomeDecor.add_mesh(fish, _sphere(0.02), Vector3(0.07, 0.025, 0.04), Palette.INK)
		"trofeo":
			HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(0.4, 0.14, 0.4), 0.04), Vector3(0, 0.07, 0), Palette.WOOD.darkened(0.2))
			var gold := Palette.SUN.lerp(Color("e0a92a"), 0.4)
			var mini := HomeDecor.make_meeple(gold)
			mini.scale = Vector3.ONE * 0.22
			mini.position.y = 0.14
			root.add_child(mini)
		"neon":
			var sign := Label3D.new()
			sign.text = "¡A JUGAR!"
			sign.font = MenuStyle.DISPLAY_FONT
			sign.font_size = 72
			sign.pixel_size = 0.008
			sign.modulate = Color("ff7ad9")
			sign.outline_size = 18
			sign.outline_modulate = Color("ffd1f1")
			sign.shaded = false
			sign.set_meta(&"neon", true)
			root.add_child(sign)
			var plate := HomeDecor.add_mesh(root, PieceKit.rounded_box(Vector3(2.1, 0.75, 0.05), 0.08), Vector3(0, 0, -0.04), Palette.INK) as MeshInstance3D
			plate.name = "Plate"
		"bola_disco":
			HomeDecor.add_mesh(root, _cylinder(0.015, 0.015, 1.2), Vector3(0, 0.75, 0), Palette.INK)
			var ball := HomeDecor.add_mesh(root, _sphere(0.36), Vector3.ZERO, Color("dfe6f2")) as MeshInstance3D
			ball.name = "Ball"
			ball.set_meta(&"spin", true)
			for k in 26:
				var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
				var tile := HomeDecor.add_mesh(ball, PieceKit.rounded_box(Vector3(0.09, 0.09, 0.02), 0.01), dir * 0.35, [Color("7cc6fe"), Palette.LAVENDER, Palette.PAPER, Palette.SUN][k % 4]) as MeshInstance3D
				tile.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		"cactus":
			HomeDecor.add_mesh(root, _cylinder(0.26, 0.2, 0.36), Vector3(0, 0.18, 0), Palette.CORAL)
			var green := Color("5fbf6a")
			var trunk := HomeDecor.add_mesh(root, _sphere(0.17), Vector3(0, 0.7, 0), green) as MeshInstance3D
			trunk.scale = Vector3(1.0, 2.2, 1.0)
			for side in [-1.0, 1.0]:
				var arm := HomeDecor.add_mesh(root, _sphere(0.09), Vector3(side * 0.2, 0.75 + side * 0.08, 0), green.lightened(0.05)) as MeshInstance3D
				arm.scale = Vector3(1.0, 1.9, 1.0)
			HomeDecor.add_mesh(root, _sphere(0.06), Vector3(0, 1.1, 0), Palette.CORAL.lightened(0.3))
		"botito":
			var bot := HomeDecor.make_meeple(Color("8fd0ff"))
			bot.name = "BotitoBody"
			bot.scale = Vector3.ONE * 0.38
			root.add_child(bot)
			var antenna := HomeDecor.add_mesh(bot.get_node("Head"), _cylinder(0.04, 0.04, 0.5), Vector3(0, 0.5, 0), Palette.INK) as MeshInstance3D
			HomeDecor.add_mesh(antenna, _sphere(0.1), Vector3(0, 0.3, 0), Palette.CORAL)
			root.set_meta(&"follow", true)
