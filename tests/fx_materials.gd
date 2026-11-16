extends SceneTree
## Los efectos efímeros comparten shader con un material base que vive toda la sesión:
## así no se recompila (con tirón) cada vez que el peón arranca a andar. Y Esc en los menús
## vuelve atrás sin errores.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var base := FxMaterials.base(FxMaterials.GLOW_ALPHA)
	_check(FxMaterials.base(FxMaterials.GLOW_ALPHA) == base, "el material base es siempre el mismo (vive toda la sesión)")
	var copy := FxMaterials.make(FxMaterials.GLOW_ALPHA, Color(1, 0, 0, 0.3))
	_check(copy != base and _same_shader(copy, base), "las copias tienen la configuración del base (mismo shader)")
	_check(copy.albedo_color == Color(1, 0, 0, 0.3), "cada copia tiene su color")

	# El peón: las nubecillas usan la malla compartida y el material de efectos.
	change_scene_to_file("res://scenes/Home.tscn")
	for i in 8:
		await process_frame
	var home := current_scene as Home
	_check(home.find_child("FxPrewarm", true, false) != null, "la habitación precalienta los shaders de efectos")
	home.pawn.call("_puff", home.pawn.position)
	await process_frame
	var puff: MeshInstance3D = home.get_child(home.get_child_count() - 1) as MeshInstance3D
	_check(puff != null and _same_shader(puff.material_override, base), "el polvo del peón usa la configuración compartida")

	# Esc en los menús: vuelve atrás (antes fallaba al marcar la tecla tras cambiar de escena).
	for path in ["res://scenes/Menu.tscn", "res://scenes/BotSelect.tscn", "res://scenes/ModeSelect.tscn", "res://scenes/Credits.tscn"]:
		change_scene_to_file(path)
		for i in 6:
			await process_frame
		var esc := InputEventAction.new()
		esc.action = "ui_cancel"
		esc.pressed = true
		root.push_input(esc)
		for i in 6:
			await process_frame
		_check(current_scene != null and current_scene.scene_file_path != path, "Esc sale de %s" % path.get_file())

	if _failed:
		quit(1)
	else:
		print("fx_materials: ok")
		quit(0)


## Mismas opciones que deciden el shader de un StandardMaterial3D.
func _same_shader(a: StandardMaterial3D, b: StandardMaterial3D) -> bool:
	return (
		a.shading_mode == b.shading_mode
		and a.transparency == b.transparency
		and a.cull_mode == b.cull_mode
		and a.diffuse_mode == b.diffuse_mode
		and a.specular_mode == b.specular_mode
		and a.next_pass == b.next_pass
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
