extends Node
## Calidad gráfica y rendimiento. Elige cuánto dibuja el juego según el equipo para que vaya
## fluido en todos: desde un portátil con gráficos integrados o una Steam Deck hasta un PC
## con tarjeta dedicada.
##
## - Cuatro opciones: Automática (por defecto), Baja, Media y Alta. Se guardan en este equipo.
## - En Automática se parte de una estimación según la tarjeta gráfica y, si una pantalla va
##   lenta varios segundos seguidos, se baja un escalón (nunca se sube sola: no da tirones).
## - Además, en todas las calidades se recortan polígonos que no se notan (esferas y
##   cilindros con 64 lados), y con la ventana en segundo plano el juego casi no gasta.

signal quality_changed(level: String)

const LEVELS := ["auto", "bajo", "medio", "alto"]
const NAMES := {"auto": "Automática", "bajo": "Baja", "medio": "Media", "alto": "Alta"}
const SECTION := "visual"
const KEY := "quality"

## Lo que cambia cada calidad.
const PRESETS := {
	"bajo": {
		"scale_3d": 0.75, "shadows": false, "shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"shadow_distance": 14.0, "outlines": false, "sub_msaa": Viewport.MSAA_DISABLED,
		"small_shadows": false, "grain": true, "detail": 0.6, "max_fps": 60,
	},
	"medio": {
		"scale_3d": 1.0, "shadows": true, "shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"shadow_distance": 18.0, "outlines": true, "sub_msaa": Viewport.MSAA_2X,
		"small_shadows": false, "grain": true, "detail": 0.8, "max_fps": 0,
	},
	"alto": {
		"scale_3d": 1.0, "shadows": true, "shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"shadow_distance": 30.0, "outlines": true, "sub_msaa": Viewport.MSAA_4X,
		"small_shadows": true, "grain": true, "detail": 1.0, "max_fps": 0,
	},
}
## Piezas más pequeñas que esto (en metros, lado mayor) no proyectan sombra en Media y Baja:
## su sombra apenas se ve y cada una vuelve a dibujarse en la pasada de sombras.
const SMALL_SHADOW := 0.22
## Automática: si el tiempo medio por fotograma pasa de esto durante WATCH_SECONDS, se baja.
const SLOW_FRAME_MS := 24.0
const WATCH_SECONDS := 4.0
## Tras cambiar de pantalla se esperan unos segundos (cargas, sombreadores) antes de medir.
const SETTLE_SECONDS := 3.0
const BACKGROUND_FPS := 12
const DETAIL_META := &"graphics_budgeted"

## Lo elegido por el jugador ("auto", "bajo", "medio" o "alto").
var choice := "auto"
## Lo que se está aplicando ahora ("bajo", "medio" o "alto").
var level := "alto"
var settings_path := UserFiles.SETTINGS

var _watch_time := 0.0
var _watch_frames := 0
var _watch_total := 0.0
var _settle := SETTLE_SECONDS
var _focused := true
var _scene: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	get_tree().node_added.connect(_on_node_added)
	_apply_global()


## Detalle de las mallas que se construyen por código (1 = todo; menos, menos lados).
func detail() -> float:
	return float(PRESETS[level]["detail"])


func preset() -> Dictionary:
	return PRESETS[level]


## Cambia la calidad. Con `save`, se recuerda en este equipo.
func set_quality(value: String, save := true) -> void:
	if not value in LEVELS:
		return
	choice = value
	level = guess_level() if value == "auto" else value
	if save:
		var config := ConfigFile.new()
		config.load(settings_path)
		config.set_value(SECTION, KEY, choice)
		config.save(settings_path)
	_apply_global()
	_apply_tree(get_tree().root)
	quality_changed.emit(level)


## Estimación inicial para «Automática» según la tarjeta gráfica.
func guess_level(adapter := "") -> String:
	if adapter == "":
		adapter = RenderingServer.get_video_adapter_name()
	var name := adapter.to_lower().replace("(r)", "").replace("(tm)", "").replace("®", "").replace("™", "")
	# Sin aceleración (o de software): lo mínimo.
	for slow in ["llvmpipe", "softpipe", "swiftshader", "microsoft basic", "virtualbox", "vmware"]:
		if name.contains(slow):
			return "bajo"
	# Gráficos integrados antiguos de Intel: baja. Los Iris Xe y Arc aguantan media.
	if name.contains("intel"):
		return "medio" if (name.contains("iris xe") or name.contains("arc")) else "bajo"
	# Integrados de AMD (Vega, «Radeon Graphics» a secas, Steam Deck) y móviles: media.
	for mid in ["vega", "radeon graphics", "custom gpu 0405", "custom gpu 0932",
			"adreno", "mali", "powervr", "apple m1", "apple m2"]:
		if name.contains(mid):
			return "medio"
	return "alto"


## Fila de ajustes «Calidad gráfica» con su desplegable (la usan los paneles de ajustes).
func make_quality_row(label_color := Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "QualityRow"
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = "Calidad gráfica"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", label_color)
	row.add_child(label)
	var option := OptionButton.new()
	option.name = "QualityOption"
	option.tooltip_text = "Automática elige según tu equipo y baja sola si el juego va lento"
	for key in LEVELS:
		option.add_item(NAMES[key])
	option.select(LEVELS.find(choice))
	_label_auto(option)
	option.item_selected.connect(func(index: int) -> void:
		set_quality(LEVELS[index])
		_label_auto(option)
	)
	# Referencia débil: el panel de ajustes se libera y la señal no debe retener el desplegable.
	var ref: WeakRef = weakref(option)
	var relabel := func(_level: String) -> void:
		var alive: OptionButton = ref.get_ref() as OptionButton
		if alive != null:
			_label_auto(alive)
	quality_changed.connect(relabel)
	option.tree_exiting.connect(func() -> void:
		if quality_changed.is_connected(relabel):
			quality_changed.disconnect(relabel)
	)
	row.add_child(option)
	return row


## «Automática (Media)»: se ve qué ha elegido.
func _label_auto(option: OptionButton) -> void:
	option.set_item_text(0, tr("Automática (%s)") % tr(NAMES[level]))


func _load() -> void:
	var config := ConfigFile.new()
	var saved := "auto"
	if config.load(settings_path) == OK:
		saved = str(config.get_value(SECTION, KEY, "auto"))
	choice = saved if saved in LEVELS else "auto"
	level = guess_level() if choice == "auto" else choice


# --- Aplicar ------------------------------------------------------------------------

func _apply_global() -> void:
	var p: Dictionary = PRESETS[level]
	var root_viewport := get_tree().root
	root_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root_viewport.scaling_3d_scale = p["scale_3d"]
	Engine.max_fps = p["max_fps"] if _focused else BACKGROUND_FPS
	# Si un equipo va justo, mejor perder pasos de física que entrar en una espiral de tirones.
	Engine.max_physics_steps_per_frame = 4 if level == "bajo" else 8
	RenderingServer.directional_shadow_atlas_set_size({"bajo": 512, "medio": 2048, "alto": 4096}[level], true)
	var toon := get_node_or_null("/root/ToonStyle")
	if toon != null:
		if toon.has_method("set_outlines"):
			toon.set_outlines(p["outlines"])
		if toon.has_method("set_grain_enabled"):
			toon.set_grain_enabled(p["grain"])


func _apply_tree(node: Node) -> void:
	_apply_node(node)
	for child in node.get_children():
		_apply_tree(child)


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D or node is Light3D or node is SubViewport:
		# Diferido: muchas escenas ponen la malla o el tamaño justo después de add_child.
		_apply_later.call_deferred(node)


func _apply_later(node: Variant) -> void:
	if is_instance_valid(node):
		_apply_node(node)


func _apply_node(node: Node) -> void:
	var p: Dictionary = PRESETS[level]
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		budget_mesh(mesh_instance.mesh)
		_apply_mesh_shadow(mesh_instance, p)
	elif node is DirectionalLight3D:
		var sun := node as DirectionalLight3D
		if not sun.has_meta(&"graphics_wanted_shadow"):
			sun.set_meta(&"graphics_wanted_shadow", sun.shadow_enabled)
		# La luz conserva su sombra activa aunque en Baja nada la proyecte: en el renderer de
		# compatibilidad, apagarla cambia cómo ilumina y la escena se ve más oscura. Sin
		# piezas que la proyecten, la pasada de sombras no cuesta casi nada.
		sun.shadow_enabled = bool(sun.get_meta(&"graphics_wanted_shadow"))
		sun.directional_shadow_mode = p["shadow_mode"]
		sun.directional_shadow_max_distance = minf(sun.directional_shadow_max_distance, p["shadow_distance"]) if sun.directional_shadow_max_distance > 0.0 else p["shadow_distance"]
	elif node is Light3D:
		# Luces puntuales y focos: su sombra es la más cara; sólo en Alta.
		var light := node as Light3D
		if not light.has_meta(&"graphics_wanted_shadow"):
			light.set_meta(&"graphics_wanted_shadow", light.shadow_enabled)
		light.shadow_enabled = bool(light.get_meta(&"graphics_wanted_shadow")) and level == "alto"
	elif node is SubViewport:
		var viewport := node as SubViewport
		if not viewport.has_meta(&"graphics_wanted_msaa"):
			viewport.set_meta(&"graphics_wanted_msaa", viewport.msaa_3d)
		viewport.msaa_3d = mini(int(viewport.get_meta(&"graphics_wanted_msaa")), int(p["sub_msaa"])) as Viewport.MSAA


func _apply_mesh_shadow(mesh_instance: MeshInstance3D, p: Dictionary) -> void:
	if mesh_instance.mesh == null:
		return
	if not mesh_instance.has_meta(&"graphics_wanted_shadow"):
		mesh_instance.set_meta(&"graphics_wanted_shadow", mesh_instance.cast_shadow)
	var wanted: int = mesh_instance.get_meta(&"graphics_wanted_shadow")
	if wanted == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		return
	var size := mesh_instance.mesh.get_aabb().size * mesh_instance.global_transform.basis.get_scale() if mesh_instance.is_inside_tree() else mesh_instance.mesh.get_aabb().size
	var small := maxf(size.x, maxf(size.y, size.z)) < SMALL_SHADOW
	var cast: bool = p["shadows"] and (p["small_shadows"] or not small)
	mesh_instance.cast_shadow = wanted if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Recorta las mallas primitivas de Godot que vienen con 64 lados (esferas, cilindros,
## cápsulas, toros): a la distancia de la mesa no se distinguen de 16–32 y cuestan mucho
## menos. Se hace una vez por malla.
func budget_mesh(mesh: Mesh) -> void:
	if mesh == null or mesh.has_meta(DETAIL_META) or not mesh is PrimitiveMesh:
		return
	mesh.set_meta(DETAIL_META, true)
	var k := detail()
	if mesh is SphereMesh:
		var sphere := mesh as SphereMesh
		var sides := _sides(sphere.radius, k)
		if sphere.radial_segments > sides:
			sphere.radial_segments = sides
			sphere.rings = maxi(sides / 2, 4)
	elif mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		var sides := _sides(maxf(cylinder.top_radius, cylinder.bottom_radius), k)
		if cylinder.radial_segments > sides:
			cylinder.radial_segments = sides
		if cylinder.rings > 1:
			cylinder.rings = 1
	elif mesh is CapsuleMesh:
		var capsule := mesh as CapsuleMesh
		var sides := _sides(capsule.radius, k)
		if capsule.radial_segments > sides:
			capsule.radial_segments = sides
			capsule.rings = maxi(sides / 4, 3)
	elif mesh is TorusMesh:
		var torus := mesh as TorusMesh
		var sides := _sides(torus.outer_radius, k)
		if torus.rings > sides:
			torus.rings = sides
			torus.ring_segments = maxi(sides / 2, 6)


## Lados según el tamaño: una cuenta de 3 cm no necesita los mismos que una lámpara.
static func _sides(radius: float, k: float) -> int:
	var base := clampi(int(12.0 + radius * 48.0), 12, 32)
	return maxi(int(base * k), 8)


# --- Automática: bajar si va lento, y casi parar en segundo plano ----------------------

func _notification(what: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		Engine.max_fps = BACKGROUND_FPS
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		Engine.max_fps = PRESETS[level]["max_fps"]


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_settle = SETTLE_SECONDS
		_reset_watch()
	if choice != "auto" or level == "bajo" or not _focused or DisplayServer.get_name() == "headless":
		return
	if _settle > 0.0:
		_settle -= delta
		return
	_watch_time += delta
	_watch_frames += 1
	_watch_total += delta
	if _watch_time < WATCH_SECONDS:
		return
	var average_ms := _watch_total / maxf(_watch_frames, 1) * 1000.0
	_reset_watch()
	if average_ms > SLOW_FRAME_MS:
		step_down()


## Baja un escalón la calidad automática (Alta → Media → Baja).
func step_down() -> bool:
	var index := ["bajo", "medio", "alto"].find(level)
	if index <= 0:
		return false
	level = ["bajo", "medio", "alto"][index - 1]
	_apply_global()
	_apply_tree(get_tree().root)
	_settle = SETTLE_SECONDS
	quality_changed.emit(level)
	return true


func _reset_watch() -> void:
	_watch_time = 0.0
	_watch_frames = 0
	_watch_total = 0.0
