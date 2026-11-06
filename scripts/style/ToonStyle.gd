extends Node
## Estilo visual cartoon común a todas las mesas (fase 1 del roadmap).
##
## Se registra como autoload y actúa sobre cada nodo que entra en el árbol, sin que las
## escenas tengan que cambiar:
## - materiales opacos de las mallas: iluminación por bandas (toon) y contorno grueso;
## - WorldEnvironment: fondo y luz ambiente de la paleta, sin tonemapping que apague colores;
## - DirectionalLight3D: luz cálida y sombras más suaves.
## Modifica los materiales en su sitio (no los sustituye), así que los scripts que guardan
## una referencia a un material y cambian su color siguen funcionando.
## Paleta y criterios: docs/ARTE.md.

const OUTLINE_SHADER := preload("res://shaders/toon_outline.gdshader")
const BODY_FONT := preload("res://assets/fonts/Nunito.ttf")
const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const DONE_META := &"toon_style_applied"

## Paleta de escena (ver docs/ARTE.md).
const INK := Palette.INK
const SKY := Palette.SKY
const AMBIENT := Palette.AMBIENT
const SUNLIGHT := Palette.SUNLIGHT
const FLOOR := Palette.FLOOR
const WOOD := Palette.WOOD
const FELT := Palette.FELT
const PANEL := Palette.PANEL
const PAPER := Palette.PAPER
const SUN := Palette.SUN
const SUN_LIGHT := Palette.SUN_LIGHT
const MUTED := Palette.MUTED
const LAVENDER := Palette.LAVENDER
## Etiquetas con este tamaño de letra o más usan la fuente de titulares.
const DISPLAY_SIZE := 22

## Grosor del contorno: proporcional a la mayor dimensión de la malla, entre estos límites
## (un dado de 0,5 m recibe unos 2 cm; la mesa, el máximo).
const OUTLINE_RATIO := 0.036
const OUTLINE_MIN := 0.008
const OUTLINE_MAX := 0.03
## Láminas más finas que esto (marcas, separadores, casillas del imán) no llevan contorno:
## solo dibujarían una raya negra.
const THIN_SHEET := 0.012

## Si es false no se añaden contornos (opción de rendimiento o preferencia).
var outlines_enabled := true
## Reduce animaciones de "juice" (rebotes, estiramientos) para quien prefiera menos movimiento.
## Se guarda junto a los ajustes de controles; cambiarlo con set_reduce_motion().
var reduce_motion := false
var settings_path := "user://diceon_controls.cfg"

var _outline_by_mode := {}


func _ready() -> void:
	_load_settings()
	RenderingServer.set_default_clear_color(SKY)
	# Escenas sin WorldEnvironment propio usan este entorno de la paleta.
	get_viewport().world_3d.fallback_environment = _make_environment()
	# Se fusiona con el tema por defecto del motor: así llega también a las interfaces que
	# cuelgan de un CanvasLayer, que no heredan el tema de la ventana.
	var theme := _build_theme()
	ThemeDB.get_default_theme().merge_with(theme)
	ThemeDB.get_default_theme().default_font = theme.default_font
	ThemeDB.get_default_theme().default_font_size = theme.default_font_size
	ThemeDB.fallback_font = theme.default_font
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D or node is WorldEnvironment or node is DirectionalLight3D or node is Control:
		# Diferido: muchas escenas asignan malla o material justo después de add_child o en _ready.
		_style_later.call_deferred(node)


# Sin tipo en el parámetro: el nodo puede haberse liberado antes de que llegue la llamada.
func _style_later(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	if node is MeshInstance3D:
		_style_mesh(node)
	elif node is WorldEnvironment:
		_style_environment(node)
	elif node is DirectionalLight3D:
		_style_sun(node)
	elif node is Control:
		_style_control(node)


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	var config := ConfigFile.new()
	config.load(settings_path)  # Conserva el resto de ajustes si el archivo ya existe.
	config.set_value("visual", "reduce_motion", enabled)
	config.save(settings_path)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var saved: Variant = config.get_value("visual", "reduce_motion", false)
	if saved is bool:
		reduce_motion = saved


## Reaplica el estilo a una malla cuya forma o material ha cambiado en tiempo de ejecución
## (por ejemplo, una promoción de ajedrez que cambia la silueta).
func restyle(mesh_instance: MeshInstance3D) -> void:
	_style_mesh(mesh_instance)


func _style_mesh(mesh_instance: MeshInstance3D) -> void:
	if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
		return
	var mode := _outline_mode(mesh_instance.mesh)
	var width := _outline_width(mesh_instance.mesh)
	# El suelo bajo la mesa toma el color de la paleta y no lleva contorno.
	var parent := mesh_instance.get_parent()
	if parent != null and parent.name == "Floor":
		_recolor(mesh_instance, FLOOR)
		width = 0.0
	elif parent != null and parent.name == "Table" and mesh_instance.name == "Visual":
		_recolor(mesh_instance, WOOD)
	elif mesh_instance.name == "Felt":
		_recolor(mesh_instance, FELT)
	if mesh_instance.material_override is StandardMaterial3D:
		_style_material(mesh_instance.material_override, mode, width)
	for surface in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.get_surface_override_material(surface)
		if material == null:
			material = mesh_instance.mesh.surface_get_material(surface)
		if material is StandardMaterial3D:
			_style_material(material, mode, width)


func _recolor(mesh_instance: MeshInstance3D, color: Color) -> void:
	var material := mesh_instance.material_override as StandardMaterial3D
	if material == null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		material = mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
	if material != null and material.albedo_texture == null:
		material.albedo_color = color


func _style_material(material: StandardMaterial3D, mode: int, width: float) -> void:
	if material.has_meta(DONE_META):
		return
	material.set_meta(DONE_META, true)
	# Los materiales transparentes o sin iluminación son resaltados, vistas previas,
	# marcas o paredes de cristal: se dejan como están.
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	if material.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		return
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.roughness = clampf(material.roughness, 0.45, 0.8)
	material.metallic = 0.0
	if outlines_enabled and width > 0.0 and material.next_pass == null:
		material.next_pass = _outline_material(mode, width)


func _outline_material(mode: int, width: float) -> ShaderMaterial:
	var key := "%d:%.4f" % [mode, width]
	if _outline_by_mode.has(key):
		return _outline_by_mode[key]
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("outline_color", INK)
	outline.set_shader_parameter("width", width)
	outline.set_shader_parameter("mode", mode)
	_outline_by_mode[key] = outline
	return outline


## 0 = según normales (mallas generadas), 1 = desde el centro, 2 = esquinas de caja.
func _outline_mode(mesh: Mesh) -> int:
	if mesh is BoxMesh:
		return 2
	# Cilindros rectos (fichas) desde el centro para cerrar el borde de las tapas; los cónicos
	# (troncos de piezas compuestas) por normal, o su contorno atraviesa las piezas vecinas.
	if mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		return 1 if is_equal_approx(cylinder.top_radius, cylinder.bottom_radius) else 0
	if mesh is CapsuleMesh:
		return 1
	return 0


func _outline_width(mesh: Mesh) -> float:
	if mesh is PlaneMesh or mesh is QuadMesh or mesh is TextMesh:
		return 0.0
	var size := mesh.get_aabb().size
	var largest := maxf(size.x, maxf(size.y, size.z))
	var thinnest := minf(size.x, minf(size.y, size.z))
	if largest <= 0.0 or thinnest < THIN_SHEET:
		return 0.0
	# Tapetes grandes y finos (el fieltro sobre la mesa): ya los contornea la mesa.
	if thinnest < 0.03 and largest > 1.0:
		return 0.0
	return clampf(largest * OUTLINE_RATIO, OUTLINE_MIN, OUTLINE_MAX)


func _style_environment(world: WorldEnvironment) -> void:
	if not is_instance_valid(world) or world.environment == null:
		return
	var environment := world.environment
	if environment.has_meta(DONE_META):
		return
	environment.set_meta(DONE_META, true)
	_apply_palette(environment)


func _make_environment() -> Environment:
	var environment := Environment.new()
	environment.set_meta(DONE_META, true)
	_apply_palette(environment)
	return environment


func _apply_palette(environment: Environment) -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT
	# Lado en sombra = color propio apagado (unos 0,45): contraste de dibujo animado.
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR


func _style_sun(light: DirectionalLight3D) -> void:
	if not is_instance_valid(light) or light.has_meta(DONE_META):
		return
	light.set_meta(DONE_META, true)
	light.light_color = SUNLIGHT
	light.light_energy = 0.85
	light.shadow_opacity = 0.55
	# La iluminación por bandas convierte el "acné" de sombra en rayas: más sesgo.
	light.shadow_bias = maxf(light.shadow_bias, 0.08)
	light.shadow_normal_bias = maxf(light.shadow_normal_bias, 2.5)


# --- Interfaz ---------------------------------------------------------------

func _build_theme() -> Theme:
	var theme := Theme.new()
	var body := FontVariation.new()
	body.base_font = BODY_FONT
	body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 750}
	theme.default_font = body
	theme.default_font_size = 15

	var button_normal := _box(SUN, INK, 3, 12)
	button_normal.border_width_bottom = 6
	var button_hover := _box(SUN_LIGHT, INK, 3, 12)
	button_hover.border_width_bottom = 6
	var button_pressed := _box(SUN, INK, 3, 12)
	button_pressed.border_width_bottom = 3
	button_pressed.content_margin_top += 3
	var button_disabled := _box(MUTED.lerp(PANEL, 0.35), INK, 3, 12)
	button_disabled.border_width_bottom = 3
	var focus := _box(Color(0, 0, 0, 0), PAPER, 3, 14)
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	for type in ["Button", "OptionButton", "MenuButton", "CheckButton", "CheckBox"]:
		theme.set_stylebox("normal", type, button_normal)
		theme.set_stylebox("hover", type, button_hover)
		theme.set_stylebox("pressed", type, button_pressed)
		theme.set_stylebox("hover_pressed", type, button_pressed)
		theme.set_stylebox("disabled", type, button_disabled)
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_disabled_color", type, PANEL)
		theme.set_color("icon_normal_color", type, INK)
	# Casillas y conmutadores no llevan relleno: se ven sobre el panel.
	for type in ["CheckButton", "CheckBox"]:
		var flat := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, type, flat)
		theme.set_color("font_color", type, PAPER)
		theme.set_color("font_hover_color", type, SUN_LIGHT)
		theme.set_color("font_pressed_color", type, PAPER)
		theme.set_color("font_hover_pressed_color", type, SUN_LIGHT)
		theme.set_color("font_focus_color", type, PAPER)

	var panel := _box(PANEL, INK, 3, 18)
	panel.shadow_color = INK
	panel.shadow_size = 1
	panel.shadow_offset = Vector2(5, 5)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PopupPanel", panel)
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_color("font_color", "PopupMenu", PAPER)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	var popup_hover := _box(SUN, INK, 2, 8)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_color", "Label", PAPER)

	var field := _box(PAPER, INK, 3, 10)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", INK)

	var tab_on := _box(SUN, INK, 3, 10)
	tab_on.corner_radius_bottom_left = 0
	tab_on.corner_radius_bottom_right = 0
	var tab_off := _box(PANEL.lightened(0.15), INK, 3, 10)
	tab_off.corner_radius_bottom_left = 0
	tab_off.corner_radius_bottom_right = 0
	for type in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type, tab_on)
		theme.set_stylebox("tab_unselected", type, tab_off)
		theme.set_stylebox("tab_hovered", type, tab_off)
		theme.set_color("font_selected_color", type, INK)
		theme.set_color("font_unselected_color", type, PAPER)
		theme.set_color("font_hovered_color", type, SUN_LIGHT)
	theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	return theme


func _box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.anti_aliasing = true
	return box


## Paneles y etiquetas con estilos propios de cada escena: se adaptan sin perder su intención.
func _style_control(control: Control) -> void:
	if not is_instance_valid(control) or control.has_meta(DONE_META):
		return
	control.set_meta(DONE_META, true)
	if control.has_theme_stylebox_override("panel"):
		var box := control.get_theme_stylebox("panel") as StyleBoxFlat
		if box != null and box.bg_color.a > 0.5 and box.bg_color.get_luminance() < 0.3:
			var styled := box.duplicate() as StyleBoxFlat
			styled.bg_color = Color(PANEL, maxf(box.bg_color.a, 0.94))
			styled.border_color = INK
			styled.set_border_width_all(3)
			styled.set_corner_radius_all(maxi(box.corner_radius_top_left, 18))
			styled.shadow_color = INK
			styled.shadow_size = 1
			styled.shadow_offset = Vector2(5, 5)
			control.add_theme_stylebox_override("panel", styled)
	if control is Label and control.has_theme_font_size_override("font_size"):
		if control.get_theme_font_size("font_size") >= DISPLAY_SIZE:
			control.add_theme_font_override("font", DISPLAY_FONT)
