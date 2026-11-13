extends SceneTree
## Estilo «arcilla»: materiales mates con luz envolvente, contorno fino del color de la pieza,
## paleta de entorno, tema de interfaz y rebote al agarrar.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var style := root.get_node_or_null("ToonStyle")
	if style == null:
		_fail("El autoload ToonStyle debe estar registrado.")
		return
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame

	var dice := main.get_node("Objects/Dice") as InteractiveTableObject
	var dice_material := _first_material(dice.get_node("Visual") as MeshInstance3D)
	if dice_material == null or dice_material.diffuse_mode != BaseMaterial3D.DIFFUSE_LAMBERT_WRAP:
		_fail("El material del dado debe usar luz envolvente (arcilla mate).")
		return
	if dice_material.specular_mode != BaseMaterial3D.SPECULAR_DISABLED or dice_material.roughness < 0.99:
		_fail("El material del dado debe ser mate, sin brillos.")
		return
	var outline := dice_material.next_pass as ShaderMaterial
	if outline == null or outline.shader != style.OUTLINE_SHADER:
		_fail("El dado debe tener contorno como next_pass.")
		return
	if float(outline.get_shader_parameter("width")) <= 0.0:
		_fail("El contorno del dado debe tener grosor.")
		return
	var outline_color: Color = outline.get_shader_parameter("outline_color")
	if outline_color.is_equal_approx(style.INK) or outline_color.get_luminance() >= dice_material.albedo_color.get_luminance():
		_fail("El contorno debe ser el color de la pieza oscurecido, no tinta negra.")
		return
	var button_box := ThemeDB.get_default_theme().get_stylebox("normal", "Button") as StyleBoxFlat
	if button_box == null or button_box.border_width_left != 0 or button_box.border_width_bottom < 4:
		_fail("Los botones deben ser de arcilla: sin contorno y con labio inferior.")
		return

	# Los materiales transparentes (resaltado de selección) no se tocan.
	dice.set_hovered(true)
	var overlay := (dice.get_node("Visual") as MeshInstance3D).material_overlay as StandardMaterial3D
	if overlay == null or overlay.next_pass != null or overlay.diffuse_mode == BaseMaterial3D.DIFFUSE_LAMBERT_WRAP:
		_fail("El resaltado transparente no debe recibir el estilo de arcilla ni contorno.")
		return
	dice.set_hovered(false)

	var world := main.get_node("WorldEnvironment") as WorldEnvironment
	if not world.environment.background_color.is_equal_approx(style.SKY):
		_fail("El entorno debe usar el fondo de la paleta.")
		return

	var theme := ThemeDB.get_default_theme()
	var normal := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	if normal == null or not normal.bg_color.is_equal_approx(style.SUN):
		_fail("El tema por defecto debe tener los botones de la paleta.")
		return

	# Rebote: al agarrar, la malla visual se estira y vuelve a su escala; el cuerpo no cambia.
	var visual := dice.get_node("Visual") as Node3D
	var body_scale := dice.scale
	dice.on_grab()
	for i in 4:
		await process_frame
	if visual.scale.is_equal_approx(Vector3.ONE):
		_fail("Al agarrar, la malla visual debe deformarse un momento.")
		return
	await create_timer(0.5).timeout
	dice.on_release()
	await create_timer(0.5).timeout
	if not visual.scale.is_equal_approx(Vector3.ONE) or not dice.scale.is_equal_approx(body_scale):
		_fail("Tras el rebote, la malla debe volver a su escala y el cuerpo no debe cambiar.")
		return

	style.reduce_motion = true
	dice.on_grab()
	await process_frame
	await process_frame
	dice.on_release()
	await process_frame
	style.reduce_motion = false
	if not visual.scale.is_equal_approx(Vector3.ONE):
		_fail("Con movimiento reducido no debe haber rebote.")
		return

	print("Toon style tests OK")
	quit(0)


func _first_material(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	if mesh_instance.material_override is StandardMaterial3D:
		return mesh_instance.material_override
	if mesh_instance.mesh == null:
		return null
	var material := mesh_instance.get_surface_override_material(0)
	if material == null:
		material = mesh_instance.mesh.surface_get_material(0)
	return material as StandardMaterial3D


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
