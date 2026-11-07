class_name TableBrush
extends Node3D
## Pincel para dibujar sobre la mesa (queja 16 de TTS): D lo activa, clic izquierdo y
## arrastrar dibuja, C cambia de color, Retroceso borra el último trazo y Mayús+Retroceso
## borra todos. Los trazos son planos, sin luz ni contorno, y no tienen física.

const COLORS := [Palette.SUN, Palette.CORAL, Palette.MINT, Palette.PLAYER_BLUE, Palette.PAPER]
const COLOR_NAMES := ["amarillo", "coral", "menta", "azul", "blanco"]
const WIDTH := 0.07
const MIN_STEP := 0.03
const MAX_POINTS := 600
const MAX_STROKES := 80

signal active_changed(active: bool)

var camera: Camera3D
var active := false
var color_index := 0
var strokes: Array[MeshInstance3D] = []
## Datos de cada trazo para guardarlo con la mesa: {"color": índice, "points": [[x,y,z], …]}.
var stroke_data: Array[Dictionary] = []
var _points: PackedVector3Array = PackedVector3Array()
var _drawing := false
var _chip: PanelContainer
var _chip_text: Label
var _swatch: ColorRect


static func attach(view: Node, view_camera: Camera3D) -> TableBrush:
	var brush := TableBrush.new()
	brush.name = "TableBrush"
	brush.camera = view_camera
	view.add_child(brush)
	return brush


func _ready() -> void:
	_build_chip()


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	_drawing = false
	_chip.visible = active
	if DisplayServer.get_name() != "headless":
		Input.set_default_cursor_shape(Input.CURSOR_CROSS if active else Input.CURSOR_ARROW)
	active_changed.emit(active)


func next_color() -> void:
	color_index = (color_index + 1) % COLORS.size()
	_refresh_chip()


func undo_stroke() -> void:
	if strokes.is_empty():
		return
	var last: MeshInstance3D = strokes.pop_back()
	last.queue_free()
	if not stroke_data.is_empty():
		stroke_data.pop_back()


func clear() -> void:
	for stroke in strokes:
		stroke.queue_free()
	strokes.clear()
	stroke_data.clear()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			return
		if event.keycode == KEY_D:
			set_active(not active)
			get_viewport().set_input_as_handled()
		elif active and event.keycode == KEY_C:
			next_color()
			get_viewport().set_input_as_handled()
		elif active and event.keycode == KEY_BACKSPACE:
			if event.shift_pressed:
				clear()
			else:
				undo_stroke()
			get_viewport().set_input_as_handled()
		elif active and event.keycode == KEY_ESCAPE:
			set_active(false)
			get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_viewport().gui_get_hovered_control() != null:
			return
		if event.pressed:
			begin_stroke(event.position)
		else:
			end_stroke()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drawing:
		extend_stroke(event.position)


## API de dibujo en coordenadas de pantalla (también la usan los tests).
func begin_stroke(screen_point: Vector2) -> bool:
	if strokes.size() >= MAX_STROKES:
		strokes.pop_front().queue_free()
		stroke_data.pop_front()
	_points = PackedVector3Array()
	var hit: Variant = surface_point(screen_point)
	if hit == null:
		return false
	_drawing = true
	_add_stroke(color_index)
	_points.append(hit)
	_rebuild()
	return true


func _add_stroke(index: int) -> void:
	var stroke := MeshInstance3D.new()
	stroke.name = "Stroke"
	stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLORS[index]
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	stroke.material_override = material
	add_child(stroke)
	strokes.append(stroke)
	stroke_data.append({"color": index, "points": []})


func extend_stroke(screen_point: Vector2) -> void:
	if not _drawing or strokes.is_empty() or _points.size() >= MAX_POINTS:
		return
	var hit: Variant = surface_point(screen_point)
	if hit == null:
		return
	if _points[_points.size() - 1].distance_to(hit) < MIN_STEP:
		return
	_points.append(hit)
	_rebuild()


func end_stroke() -> void:
	_drawing = false


## Punto de la superficie bajo la pantalla (mesa, tablero o piezas), un pelo por encima.
func surface_point(screen_point: Vector2) -> Variant:
	if not is_instance_valid(camera):
		return null
	var origin := camera.project_ray_origin(screen_point)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(screen_point) * 100.0
	)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit["position"] + Vector3.UP * 0.012


func _rebuild() -> void:
	var stroke: MeshInstance3D = strokes[strokes.size() - 1]
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var half := WIDTH * 0.5
	# Puntos redondos en cada vértice y cintas entre ellos: el trazo parece de rotulador.
	for i in _points.size():
		var p := _points[i]
		for k in 10:
			var a0 := TAU * k / 10.0
			var a1 := TAU * (k + 1) / 10.0
			vertices.append(p)
			vertices.append(p + Vector3(cos(a1), 0, sin(a1)) * half)
			vertices.append(p + Vector3(cos(a0), 0, sin(a0)) * half)
		if i == 0:
			continue
		var q := _points[i - 1]
		var along := p - q
		along.y = 0.0
		if along.length() < 0.0001:
			continue
		var side := along.normalized().cross(Vector3.UP) * half
		vertices.append_array(PackedVector3Array([q + side, p + side, p - side, q + side, p - side, q - side]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	stroke.mesh = mesh
	var saved: Array = []
	for p in _points:
		saved.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
	stroke_data[stroke_data.size() - 1]["points"] = saved


## Trazos para guardar con la mesa.
func export_strokes() -> Array:
	return stroke_data.duplicate(true)


## Restaura trazos guardados (ya validados con valid_strokes).
func import_strokes(data: Array) -> void:
	clear()
	for entry in data:
		_add_stroke(int(entry["color"]))
		_points = PackedVector3Array()
		for p in entry["points"]:
			_points.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
		_rebuild()
	_points = PackedVector3Array()
	_drawing = false


static func valid_strokes(data: Variant) -> bool:
	if not data is Array or data.size() > MAX_STROKES:
		return false
	for entry in data:
		if not entry is Dictionary:
			return false
		var color: Variant = entry.get("color")
		if not (color is int or color is float) or int(color) < 0 or int(color) >= COLORS.size():
			return false
		var points: Variant = entry.get("points")
		if not points is Array or points.is_empty() or points.size() > MAX_POINTS:
			return false
		for p in points:
			if not p is Array or p.size() != 3:
				return false
			for value in p:
				if not (value is float or value is int) or absf(float(value)) > 50.0:
					return false
	return true


func _build_chip() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_chip = PanelContainer.new()
	_chip.name = "BrushChip"
	_chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chip.offset_bottom = -84
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PANEL
	box.border_color = Palette.SUN
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	_chip.add_theme_stylebox_override("panel", box)
	layer.add_child(_chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_child(row)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(22, 22)
	_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_swatch)
	_chip_text = Label.new()
	_chip_text.add_theme_color_override("font_color", Palette.PAPER)
	_chip_text.add_theme_font_size_override("font_size", 15)
	row.add_child(_chip_text)
	_chip.visible = false
	_refresh_chip()


func _refresh_chip() -> void:
	_swatch.color = COLORS[color_index]
	_chip_text.text = (
		tr("PINCEL (%s) · arrastra para dibujar · C color · ⌫ deshacer · Mayús+⌫ borrar · D salir")
		% tr(COLOR_NAMES[color_index])
	)
