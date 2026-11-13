class_name RoomDecor
extends Node3D
## Habitación acogedora alrededor de la mesa (docs/ARTE.md): alfombra, dos paredes con zócalo,
## ventana soleada, lámpara colgante cálida con foco cenital suave, estantería y planta.
## Solo decorado: sin colisiones. Las juntas del parqué se agrupan en MultiMeshInstance3D
## (~2 draw calls en lugar de ~460) para mantener 60+ FPS en gl_compatibility.

const WALL := Color("efe5d6")
const TRIM := Color("d9c4a6")
const RUG := Color("9fb3c4")
const RUG_EDGE := Color("7d93a6")
const GLASS := Color("bfe3ff")
const LAMP_SHADE := Color("e39a63")
const WARM_SPOT := Color("ffe4b5")
const BOOKS := [Color("ff6b5e"), Color("4d7cfe"), Color("ffc83d"), Color("3fcf8e"), Color("8a7fd6")]
const DONE_META := &"toon_style_applied"

## Distancia de las paredes al centro de la mesa.
var north_z := -10.0
var west_x := -12.5


func _ready() -> void:
	name = "RoomDecor"
	_floorboards()
	_rug()
	_wall(Vector3(0, 0, north_z), 0.0, 32.0)
	_wall(Vector3(west_x, 0, 0), PI / 2.0, 26.0)
	_window(Vector3(-2.5, 4.2, north_z + 0.02))
	_shelf(Vector3(west_x + 0.25, 2.6, -3.0))
	_plant(Vector3(west_x + 1.2, 0, north_z + 1.2))
	_table_lamp()
	TableVfx.ensure_for.call_deferred(self)


# Juntas entre tablones del suelo agrupadas en MultiMeshInstance3D (2 draw calls totales).
func _floorboards() -> void:
	var seam := _material(Palette.FLOOR.darkened(0.14))
	seam.set_meta(DONE_META, true)
	seam.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	seam.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	seam.roughness = 1.0

	var line_box := BoxMesh.new()
	line_box.size = Vector3(40.0, 0.004, 0.05)
	var line_mm := MultiMesh.new()
	line_mm.transform_format = MultiMesh.TRANSFORM_3D
	line_mm.mesh = line_box
	line_mm.instance_count = 33

	var cut_box := BoxMesh.new()
	cut_box.size = Vector3(0.05, 0.004, 1.1)
	var cut_mm := MultiMesh.new()
	cut_mm.transform_format = MultiMesh.TRANSFORM_3D
	cut_mm.mesh = cut_box
	cut_mm.instance_count = 33 * 13

	var line_idx := 0
	var cut_idx := 0
	for i in range(-16, 17):
		line_mm.set_instance_transform(
			line_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.003, float(i) * 1.1))
		)
		line_idx += 1
		for j in range(-6, 7):
			var stagger := 1.6 if (i % 2 != 0) else 0.0
			cut_mm.set_instance_transform(
				cut_idx,
				Transform3D(
					Basis.IDENTITY,
					Vector3(float(j) * 3.2 + stagger, 0.003, float(i) * 1.1 + 0.55)
				)
			)
			cut_idx += 1

	var lines_node := MultiMeshInstance3D.new()
	lines_node.name = "FloorboardLines"
	lines_node.set_meta(DONE_META, true)
	lines_node.multimesh = line_mm
	lines_node.material_override = seam
	lines_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines_node)

	var cuts_node := MultiMeshInstance3D.new()
	cuts_node.name = "FloorboardCuts"
	cuts_node.set_meta(DONE_META, true)
	cuts_node.multimesh = cut_mm
	cuts_node.material_override = seam
	cuts_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cuts_node)


func _rug() -> void:
	var edge := _mesh(PieceKit.rounded_disc(5.4, 0.03, 0.015, 96), Vector3(0, 0.015, 0), RUG_EDGE)
	edge.scale = Vector3(1.0, 1.0, 0.72)
	var top := _mesh(PieceKit.rounded_disc(5.0, 0.035, 0.015, 96), Vector3(0, 0.02, 0), RUG)
	top.scale = Vector3(1.0, 1.0, 0.72)


func _wall(origin: Vector3, turn: float, width: float) -> void:
	var wall := Node3D.new()
	wall.position = origin
	wall.rotation.y = turn
	add_child(wall)
	var plane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, 9.0)
	plane.mesh = quad
	plane.position.y = 4.5
	plane.material_override = _material(WALL, true)
	wall.add_child(plane)
	var trim := MeshInstance3D.new()
	var strip := QuadMesh.new()
	strip.size = Vector2(width, 0.7)
	trim.mesh = strip
	trim.position = Vector3(0, 0.35, 0.01)
	trim.material_override = _material(TRIM, true)
	wall.add_child(trim)


func _window(center: Vector3) -> void:
	var glass := MeshInstance3D.new()
	var pane := QuadMesh.new()
	pane.size = Vector2(3.2, 2.6)
	glass.mesh = pane
	glass.position = center + Vector3(0, 0, 0.01)
	var glass_material := _material(GLASS, true)
	glass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.material_override = glass_material
	add_child(glass)
	for bar in [
		[Vector3(0, 1.36, 0), Vector3(3.5, 0.18, 0.12)],
		[Vector3(0, -1.36, 0), Vector3(3.6, 0.22, 0.2)],
		[Vector3(-1.66, 0, 0), Vector3(0.18, 2.9, 0.12)],
		[Vector3(1.66, 0, 0), Vector3(0.18, 2.9, 0.12)],
		[Vector3(0, 0, 0), Vector3(3.2, 0.1, 0.08)],
		[Vector3(0, 0, 0), Vector3(0.1, 2.6, 0.08)],
	]:
		_mesh(PieceKit.rounded_box(bar[1], 0.03), center + bar[0] + Vector3(0, 0, 0.06), Palette.PAPER)
	for puff in [Vector3(-0.6, 0.55, 0), Vector3(-0.25, 0.7, 0), Vector3(0.1, 0.55, 0)]:
		var cloud := _mesh(PieceKit.dot(0.28, 0.02), center + puff + Vector3(0, 0, 0.03), Palette.PAPER)
		cloud.rotation_degrees.x = 90
	# Haz cálido suave que entra en diagonal desde la ventana (estilo Demeo).
	var beam := MeshInstance3D.new()
	beam.name = "WindowSunbeam"
	var beam_quad := QuadMesh.new()
	beam_quad.size = Vector2(2.8, 5.2)
	beam.mesh = beam_quad
	beam.position = center + Vector3(0.4, -1.5, 1.8)
	beam.rotation_degrees = Vector3(-34.0, 12.0, 0.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam_mat := StandardMaterial3D.new()
	beam_mat.set_meta(DONE_META, true)
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(1.0, 0.95, 0.80, 0.045)
	beam.material_override = beam_mat
	add_child(beam)


func _table_lamp() -> void:
	var lamp := Node3D.new()
	lamp.name = "TableLamp"
	lamp.position = Vector3(0.0, 6.2, 0.0)
	add_child(lamp)

	var cord := MeshInstance3D.new()
	var cord_cyl := CylinderMesh.new()
	cord_cyl.top_radius = 0.022
	cord_cyl.bottom_radius = 0.022
	cord_cyl.height = 1.6
	cord_cyl.radial_segments = 10
	cord.mesh = cord_cyl
	cord.position = Vector3(0.0, 0.95, 0.0)
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cord.material_override = _material(Palette.INK)
	lamp.add_child(cord)

	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 0.56
	cone.height = 0.36
	cone.radial_segments = 20
	shade.mesh = cone
	shade.position = Vector3(0.0, 0.06, 0.0)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.material_override = _material(LAMP_SHADE)
	lamp.add_child(shade)

	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.22
	sphere.radial_segments = 12
	sphere.rings = 6
	bulb.mesh = sphere
	bulb.position = Vector3(0.0, -0.08, 0.0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.set_meta(DONE_META, true)
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color("fff5cc")
	bulb.material_override = bulb_mat
	lamp.add_child(bulb)

	var spot := SpotLight3D.new()
	spot.name = "TableWarmSpot"
	spot.set_meta(DONE_META, true)
	spot.position = Vector3(0.0, -0.15, 0.0)
	spot.rotation_degrees.x = -90.0
	spot.light_color = WARM_SPOT
	spot.light_energy = 0.44
	spot.spot_range = 11.5
	spot.spot_angle = 54.0
	spot.spot_attenuation = 1.45
	spot.shadow_enabled = false
	lamp.add_child(spot)


func _shelf(origin: Vector3) -> void:
	var board := _mesh(PieceKit.rounded_box(Vector3(0.6, 0.12, 3.2), 0.03), origin, TRIM)
	board.name = "Shelf"
	var z := origin.z - 1.3
	for i in 9:
		var height := 0.5 + float((i * 7) % 4) * 0.08
		var thick := 0.16 + float((i * 3) % 3) * 0.03
		var book := _mesh(
			PieceKit.rounded_box(Vector3(0.42, height, thick), 0.02),
			Vector3(origin.x, origin.y + 0.06 + height * 0.5, z + thick * 0.5),
			BOOKS[i % BOOKS.size()]
		)
		if i == 7:
			book.rotation.x = -0.35
		z += thick + 0.03


func _plant(base: Vector3) -> void:
	var pot := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.55
	cone.bottom_radius = 0.42
	cone.height = 0.9
	cone.radial_segments = 16
	pot.mesh = cone
	pot.position = base + Vector3(0, 0.45, 0)
	pot.material_override = _material(Palette.CORAL)
	add_child(pot)
	for leaf in [
		Vector3(0, 1.5, 0),
		Vector3(-0.45, 1.25, 0.1),
		Vector3(0.45, 1.3, -0.1),
		Vector3(0.1, 1.95, 0.2),
		Vector3(-0.25, 1.75, -0.25),
		Vector3(0.35, 1.8, 0.2),
	]:
		var ball := SphereMesh.new()
		ball.radius = 0.38
		ball.height = 0.76
		ball.radial_segments = 14
		ball.rings = 7
		_mesh(ball, base + leaf, Palette.PLAYER_GREEN.darkened(0.15))


func _mesh(mesh: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color)
	add_child(node)
	return node


func _material(color: Color, one_sided := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic_specular = 0.1
	if one_sided:
		material.cull_mode = BaseMaterial3D.CULL_BACK
	return material
