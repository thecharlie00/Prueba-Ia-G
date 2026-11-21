extends SceneTree
## Verifica el autoload Graphics: niveles de calidad, recorte de mallas, contornos,
## detección por GPU y guardado del ajuste.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var graphics: Node = root.get_node("Graphics")
	var toon: Node = root.get_node("ToonStyle")
	var saved_path: String = graphics.settings_path
	graphics.settings_path = "user://test_graphics_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(graphics.settings_path))

	# Detección por adaptador.
	_check(graphics.guess_level("llvmpipe (LLVM 15.0.7, 256 bits)") == "bajo", "llvmpipe → Baja")
	_check(graphics.guess_level("Intel(R) UHD Graphics 620") == "bajo", "Intel UHD → Baja")
	_check(graphics.guess_level("Intel(R) Iris(R) Xe Graphics") == "medio", "Iris Xe → Media")
	_check(graphics.guess_level("AMD Custom GPU 0405") == "medio", "Steam Deck → Media")
	_check(graphics.guess_level("NVIDIA GeForce RTX 3060") == "alto", "RTX → Alta")

	# Recorte de primitivas.
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	graphics.budget_mesh(sphere)
	_check(sphere.radial_segments <= 32 and sphere.radial_segments >= 8, "esfera pequeña recortada (%d)" % sphere.radial_segments)
	var segs: int = sphere.radial_segments
	graphics.budget_mesh(sphere)
	_check(sphere.radial_segments == segs, "el recorte se aplica una sola vez")
	var cylinder := CylinderMesh.new()
	graphics.budget_mesh(cylinder)
	_check(cylinder.rings == 1 and cylinder.radial_segments <= 32, "cilindro recortado")

	# Niveles y contornos sobre una escena con una pieza estilizada.
	var scene := Node3D.new()
	root.add_child(scene)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	scene.add_child(sun)
	var piece := MeshInstance3D.new()
	piece.mesh = BoxMesh.new()
	piece.material_override = StandardMaterial3D.new()
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	scene.add_child(piece)
	for i in 4:
		await process_frame

	graphics.set_quality("bajo")
	await process_frame
	_check(graphics.level == "bajo", "nivel Baja aplicado")
	_check(not toon.outlines_enabled, "Baja apaga los contornos")
	_check(piece.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Baja quita la sombra de las piezas")
	_check(sun.shadow_enabled, "la luz conserva la sombra activa (evita oscurecer la escena)")
	_check(is_equal_approx(root.scaling_3d_scale, 0.75), "Baja renderiza el 3D al 75 %")
	_check(is_equal_approx(graphics.detail(), 0.6), "detalle de Baja")

	graphics.set_quality("alto")
	await process_frame
	_check(toon.outlines_enabled, "Alta recupera los contornos")
	_check(piece.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Alta devuelve la sombra")
	_check(is_equal_approx(root.scaling_3d_scale, 1.0), "Alta renderiza el 3D a resolución completa")
	_check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Alta usa dos cascadas")

	# Guardado.
	graphics.set_quality("medio")
	var config := ConfigFile.new()
	_check(config.load(graphics.settings_path) == OK, "ajuste guardado")
	_check(str(config.get_value("visual", "quality", "")) == "medio", "se guarda Media")

	# Fila de ajustes.
	var row: HBoxContainer = graphics.make_quality_row()
	var option := row.get_node("QualityOption") as OptionButton
	_check(option != null and option.item_count == 4, "selector con 4 opciones")
	row.free()

	scene.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(graphics.settings_path))
	graphics.settings_path = saved_path
	graphics.set_quality("auto", false)

	if _failures > 0:
		push_error("graphics_quality: %d fallos" % _failures)
		quit(1)
	else:
		print("graphics_quality: OK")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		printerr("  FALLO  ", label)
