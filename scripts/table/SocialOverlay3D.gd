class_name SocialOverlay3D
extends Node3D
## Capa social y de presencia 3D para todas las mesas de Tablerama:
## - Punteros 3D multijugador (manos cartoon con color de butaca, suavizadas a 60 FPS desde 10 Hz).
## - Pings 3D sincronizados (tecla P) con foco de mirada compartido en TableSeats.
## - Rueda/barra rápida de Emotes tipo cómic (tecla G o botón ☺) con aviso 2D si el asiento
##   está oculto detrás de la cámara.
## Totalmente desacoplado de las reglas deterministas (no altera snapshot ni export_record).

const CURSOR_SEND_INTERVAL := 0.10
const CURSOR_IDLE_HIDE := 3.5
const EMOTE_COOLDOWN_MS := 1000
const TABLE_PLANE_Y := 0.82
const MAX_SEATS := 4
const DONE_META := &"toon_style_applied"

const SEAT_FALLBACK_COLORS := [
	Color("ff6b5e"),
	Color("4d7cfe"),
	Color("ff9a3d"),
	Color("3fcf8e"),
]

var view: Node3D
var seats: TableSeats
var net_table: NetTable
var grabber: PhysicsGrabber3D

var _pointers: Array[Node3D] = []
var _pointer_targets: Array[Vector3] = []
var _pointer_states: Array[int] = []
var _pointer_last_seen: Array[float] = []
var _pointer_cuffs: Array[MeshInstance3D] = []
var _pointer_spots: Array[MeshInstance3D] = []
var _pointer_fingers: Array[Node3D] = []
var _pointer_tags: Array[Label3D] = []

var _dice_cache: Array[Dice3D] = []
var _dice_scan_timer := 0.0
var _cursor_send_timer := 0.0
var _last_sent_pos := Vector3(999.0, 999.0, 999.0)
var _last_sent_state := -1
var _last_local_emote_ms := -5000
var _clock := 0.0

var _ui_layer: CanvasLayer
var _emote_toggle: Button
var _emote_bar: PanelContainer
var _near_toast: PanelContainer
var _near_toast_label: Label
var _toast_tween: Tween


static func attach(
	view_node: Node3D,
	seats_node: TableSeats,
	net_node: NetTable = null
) -> SocialOverlay3D:
	if view_node == null:
		return null
	var existing := view_node.get_node_or_null("SocialOverlay3D") as SocialOverlay3D
	if existing != null:
		existing.bind_targets(seats_node, net_node)
		return existing
	var overlay := SocialOverlay3D.new()
	overlay.name = "SocialOverlay3D"
	overlay.view = view_node
	overlay.seats = seats_node
	overlay.net_table = net_node
	view_node.add_child(overlay)
	return overlay


func _ready() -> void:
	_build_pointers()
	_build_ui()
	_discover_links.call_deferred()


func bind_targets(seats_node: TableSeats, net_node: NetTable = null) -> void:
	if seats_node != null:
		seats = seats_node
	if net_node != null and net_node != net_table:
		_connect_net_table(net_node)
	_refresh_pointer_styles()


func _discover_links() -> void:
	if view == null or not is_instance_valid(view):
		return
	if seats == null:
		seats = view.get_node_or_null("TableSeats") as TableSeats
	if net_table == null:
		var found_net := view.get_node_or_null("NetTable") as NetTable
		if found_net != null:
			_connect_net_table(found_net)
	if grabber == null:
		grabber = view.find_child("PhysicsGrabber3D", true, false) as PhysicsGrabber3D
		if grabber != null and not grabber.pinged.is_connected(_on_local_grabber_ping):
			grabber.pinged.connect(_on_local_grabber_ping)
	_scan_dice()
	_refresh_pointer_styles()


func _connect_net_table(node: NetTable) -> void:
	net_table = node
	if net_table == null:
		return
	if not net_table.cursor_received.is_connected(on_remote_cursor):
		net_table.cursor_received.connect(on_remote_cursor)
	if not net_table.emote_received.is_connected(on_remote_emote):
		net_table.emote_received.connect(on_remote_emote)
	if not net_table.ping_received.is_connected(on_remote_ping):
		net_table.ping_received.connect(on_remote_ping)
	if not net_table.rule_applied.is_connected(_on_rule_applied):
		net_table.rule_applied.connect(_on_rule_applied)


func _scan_dice() -> void:
	_dice_cache.clear()
	if view == null:
		return
	for node in view.find_children("*", "Dice3D", true, false):
		if node is Dice3D:
			_dice_cache.append(node as Dice3D)


func _seat_color(seat_idx: int) -> Color:
	if seats != null and seat_idx >= 0 and seat_idx < seats.seats.size():
		var c: Variant = seats.seats[seat_idx].get("color")
		if c is Color:
			return c as Color
	return SEAT_FALLBACK_COLORS[posmod(seat_idx, SEAT_FALLBACK_COLORS.size())]


func _seat_name(seat_idx: int) -> String:
	if seats != null and seat_idx >= 0 and seat_idx < seats.seats.size():
		return str(seats.seats[seat_idx].get("name", "J%d" % (seat_idx + 1)))
	return "J%d" % (seat_idx + 1)


func _local_seat_index() -> int:
	if net_table != null:
		var s := net_table.local_seat()
		if s >= 0:
			return s
	var net := get_node_or_null("/root/Net")
	if net != null and net.has_method("local_seat"):
		var ns := int(net.local_seat())
		if ns >= 0:
			return ns
	return 0


# --- Punteros 3D Multijugador ------------------------------------------------

func _build_pointers() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Palette.PAPER
	white.roughness = 0.45

	var palm_mesh := SphereMesh.new()
	palm_mesh.radius = 0.085
	palm_mesh.height = 0.13
	palm_mesh.radial_segments = 14
	palm_mesh.rings = 7

	var finger_mesh := PieceKit.rounded_box(Vector3(0.052, 0.048, 0.13), 0.018, 3)
	var cuff_mesh := PieceKit.torus(0.068, 0.022, 14)
	var spot_mesh := QuadMesh.new()
	spot_mesh.size = Vector2(0.24, 0.24)

	for i in MAX_SEATS:
		var root := Node3D.new()
		root.name = "RemotePointer%d" % i
		root.visible = false
		add_child(root)
		_pointers.append(root)
		_pointer_targets.append(Vector3(0.0, TABLE_PLANE_Y, 0.0))
		_pointer_states.append(0)
		_pointer_last_seen.append(-100.0)

		var hand_rig := Node3D.new()
		hand_rig.name = "HandRig"
		hand_rig.position = Vector3(0.0, 0.16, 0.0)
		root.add_child(hand_rig)

		var palm := MeshInstance3D.new()
		palm.mesh = palm_mesh
		palm.material_override = white
		palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand_rig.add_child(palm)

		var finger_pivot := Node3D.new()
		finger_pivot.name = "FingerPivot"
		finger_pivot.position = Vector3(0.0, -0.01, -0.08)
		hand_rig.add_child(finger_pivot)
		_pointer_fingers.append(finger_pivot)

		var finger := MeshInstance3D.new()
		finger.mesh = finger_mesh
		finger.position = Vector3(0.0, 0.0, -0.03)
		finger.material_override = white
		finger.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		finger_pivot.add_child(finger)

		var cuff_mat := StandardMaterial3D.new()
		cuff_mat.albedo_color = SEAT_FALLBACK_COLORS[i]
		var cuff := MeshInstance3D.new()
		cuff.mesh = cuff_mesh
		cuff.position = Vector3(0.0, 0.01, 0.075)
		cuff.rotation_degrees.x = 90.0
		cuff.material_override = cuff_mat
		cuff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand_rig.add_child(cuff)
		_pointer_cuffs.append(cuff)

		var spot_mat := StandardMaterial3D.new()
		spot_mat.set_meta(DONE_META, true)
		spot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spot_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		spot_mat.albedo_texture = TableVfx.shared_shadow_material().albedo_texture
		spot_mat.albedo_color = Color(
			SEAT_FALLBACK_COLORS[i].r,
			SEAT_FALLBACK_COLORS[i].g,
			SEAT_FALLBACK_COLORS[i].b,
			0.65
		)
		var spot := MeshInstance3D.new()
		spot.mesh = spot_mesh
		spot.rotation_degrees.x = -90.0
		spot.position = Vector3(0.0, 0.004, 0.0)
		spot.material_override = spot_mat
		spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(spot)
		_pointer_spots.append(spot)

		var tag := Label3D.new()
		tag.name = "Tag"
		tag.set_meta(DONE_META, true)
		if has_node("/root/ToonStyle"):
			tag.font = get_node("/root/ToonStyle").DISPLAY_FONT
		tag.font_size = 34
		tag.pixel_size = 0.0032
		tag.outline_size = 12
		tag.outline_modulate = Palette.INK
		tag.modulate = SEAT_FALLBACK_COLORS[i].lightened(0.2)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.render_priority = 4
		tag.position = Vector3(0.0, 0.34, 0.0)
		tag.text = "J%d" % (i + 1)
		root.add_child(tag)
		_pointer_tags.append(tag)


func _refresh_pointer_styles() -> void:
	for i in MAX_SEATS:
		var col := _seat_color(i)
		var cuff_mat := _pointer_cuffs[i].material_override as StandardMaterial3D
		if cuff_mat != null:
			cuff_mat.albedo_color = col
		var spot_mat := _pointer_spots[i].material_override as StandardMaterial3D
		if spot_mat != null:
			spot_mat.albedo_color = Color(col.r, col.g, col.b, 0.65)
		_pointer_tags[i].modulate = col.lightened(0.22)
		_pointer_tags[i].text = _seat_name(i)


func on_remote_cursor(seat: int, world_pos: Vector3, state: int) -> void:
	if seat < 0 or seat >= MAX_SEATS or seat == _local_seat_index():
		return
	_refresh_pointer_styles()
	if not _pointers[seat].visible:
		_pointers[seat].global_position = world_pos
	_pointers[seat].visible = true
	_pointer_targets[seat] = world_pos
	_pointer_states[seat] = state
	_pointer_last_seen[seat] = _clock
	if seats != null and (state == 1 or seat == seats.active):
		seats.set_focus_target(world_pos, 0.65)


func on_remote_emote(seat: int, emote_id: String) -> void:
	_display_emote_for_seat(seat, emote_id)


func on_remote_ping(seat: int, world_pos: Vector3) -> void:
	var col := _seat_color(seat)
	if grabber != null:
		grabber.ping(world_pos, col, false)
	else:
		_spawn_standalone_ping(world_pos, col)
	if seats != null:
		seats.set_focus_target(world_pos, 2.2)


func _on_local_grabber_ping(world_pos: Vector3) -> void:
	if seats != null:
		seats.set_focus_target(world_pos, 2.2)
	if net_table != null:
		net_table.send_ping(world_pos)


func _on_rule_applied(change: Dictionary) -> void:
	var kind := str(change.get("type", ""))
	if kind in ["robber", "steal", "knight", "monopoly"]:
		TableVfx.spawn_hero_impact(self, Vector3(0.0, TABLE_PLANE_Y, 0.0), Palette.CORAL, 0.24)
	elif kind in ["settlement", "city", "play", "move"]:
		TableVfx.spawn_drop(self, Vector3(0.0, TABLE_PLANE_Y, 0.0), 1.05, Palette.SUN_LIGHT)


# --- Interfaz de Emotes Cómic (KEY_G + botón compacto ☺) ---------------------

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "SocialHud"
	_ui_layer.layer = 5
	add_child(_ui_layer)

	var root_ctrl := Control.new()
	root_ctrl.name = "SocialRoot"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(root_ctrl)

	_emote_toggle = Button.new()
	_emote_toggle.name = "EmoteToggle"
	_emote_toggle.text = "☺"
	_emote_toggle.tooltip_text = tr("Reacciones rápidas (G)")
	_emote_toggle.focus_mode = Control.FOCUS_NONE
	_emote_toggle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_emote_toggle.offset_left = -64
	_emote_toggle.offset_right = -18
	_emote_toggle.offset_top = -64
	_emote_toggle.offset_bottom = -18
	_emote_toggle.add_theme_font_size_override("font_size", 22)
	_emote_toggle.pressed.connect(toggle_emote_bar)
	root_ctrl.add_child(_emote_toggle)

	_emote_bar = PanelContainer.new()
	_emote_bar.name = "EmoteBar"
	_emote_bar.visible = false
	_emote_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_emote_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_emote_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_emote_bar.offset_right = -18
	_emote_bar.offset_bottom = -74
	var bar_box := StyleBoxFlat.new()
	bar_box.bg_color = Palette.PANEL
	bar_box.border_color = Palette.INK
	bar_box.set_border_width_all(3)
	bar_box.set_corner_radius_all(16)
	bar_box.shadow_color = Palette.INK
	bar_box.shadow_size = 1
	bar_box.shadow_offset = Vector2(4, 4)
	bar_box.content_margin_left = 8
	bar_box.content_margin_right = 8
	bar_box.content_margin_top = 6
	bar_box.content_margin_bottom = 6
	_emote_bar.add_theme_stylebox_override("panel", bar_box)
	root_ctrl.add_child(_emote_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_emote_bar.add_child(row)

	var catalog := EmoteBubble3D.catalog()
	for emote_key in EmoteBubble3D.emote_ids():
		var id_str: String = str(emote_key)
		var item: Dictionary = catalog[id_str]
		var btn := Button.new()
		btn.name = "Emote_" + id_str
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(88, 38)
		btn.add_theme_font_size_override("font_size", 13)
		btn.text = "%s %s" % [str(item.get("glyph", "★")), tr(str(item.get("label", "")))]
		btn.pressed.connect(func() -> void: trigger_local_emote(id_str))
		row.add_child(btn)

	# Aviso 2D flotante cuando quien reacciona está del lado de la cámara (near == true).
	_near_toast = PanelContainer.new()
	_near_toast.name = "NearEmoteToast"
	_near_toast.visible = false
	_near_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_near_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_near_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_near_toast.offset_left = 20
	_near_toast.offset_bottom = -132
	var toast_box := StyleBoxFlat.new()
	toast_box.bg_color = Palette.PAPER
	toast_box.border_color = Palette.INK
	toast_box.set_border_width_all(3)
	toast_box.set_corner_radius_all(16)
	toast_box.shadow_color = Palette.INK
	toast_box.shadow_size = 1
	toast_box.shadow_offset = Vector2(4, 4)
	toast_box.content_margin_left = 14
	toast_box.content_margin_right = 14
	toast_box.content_margin_top = 6
	toast_box.content_margin_bottom = 6
	_near_toast.add_theme_stylebox_override("panel", toast_box)
	_near_toast_label = Label.new()
	_near_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_near_toast_label.add_theme_font_size_override("font_size", 18)
	_near_toast_label.add_theme_color_override("font_color", Palette.INK)
	if has_node("/root/ToonStyle"):
		_near_toast_label.add_theme_font_override("font", get_node("/root/ToonStyle").DISPLAY_FONT)
	_near_toast.add_child(_near_toast_label)
	root_ctrl.add_child(_near_toast)


func toggle_emote_bar() -> void:
	if _emote_bar != null:
		_emote_bar.visible = not _emote_bar.visible


func trigger_local_emote(emote_id: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_local_emote_ms < EMOTE_COOLDOWN_MS:
		return
	_last_local_emote_ms = now
	if _emote_bar != null:
		_emote_bar.visible = false
	var my_seat := _local_seat_index()
	_display_emote_for_seat(my_seat, emote_id)
	if net_table != null:
		net_table.send_emote(emote_id, my_seat)


func _display_emote_for_seat(seat: int, emote_id: String) -> void:
	if seats != null and seat >= 0 and seat < seats.seats.size():
		seats.trigger_emote(seat, emote_id)
		if seat < seats.near.size() and seats.near[seat]:
			_show_near_toast(seat, emote_id)
	else:
		_show_near_toast(maxi(seat, 0), emote_id)


func _show_near_toast(seat: int, emote_id: String) -> void:
	if _near_toast == null or _near_toast_label == null:
		return
	var catalog := EmoteBubble3D.catalog()
	var item: Dictionary = catalog.get(emote_id, catalog["victory"])
	_near_toast_label.text = "%s: %s %s" % [
		_seat_name(seat),
		str(item.get("glyph", "★")),
		tr(str(item.get("label", "¡TOMA!"))),
	]
	_near_toast.visible = true
	_near_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	if is_inside_tree():
		_toast_tween = create_tween()
		_toast_tween.tween_interval(1.85)
		_toast_tween.tween_property(_near_toast, "modulate:a", 0.0, 0.25)
		_toast_tween.tween_callback(func() -> void: _near_toast.visible = false)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_ev := event as InputEventKey
	if key_ev.ctrl_pressed or key_ev.alt_pressed or key_ev.meta_pressed:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return
	if key_ev.keycode == KEY_G:
		toggle_emote_bar()
		get_viewport().set_input_as_handled()
	elif key_ev.keycode == KEY_P and grabber == null:
		var pt := _project_mouse_to_table()
		var col := _seat_color(_local_seat_index())
		_spawn_standalone_ping(pt, col)
		if seats != null:
			seats.set_focus_target(pt, 2.2)
		if net_table != null:
			net_table.send_ping(pt)
		get_viewport().set_input_as_handled()


func _spawn_standalone_ping(at: Vector3, tint: Color) -> void:
	TableVfx.spawn_hero_impact(self, at, tint, 0.0)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("pop")


func _project_mouse_to_table() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(0.0, TABLE_PLANE_Y, 0.0)
	var mouse := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if absf(dir.y) < 0.001:
		return Vector3(0.0, TABLE_PLANE_Y, 0.0)
	var t := (TABLE_PLANE_Y - origin.y) / dir.y
	if t <= 0.0 or t > 40.0:
		return Vector3(0.0, TABLE_PLANE_Y, 0.0)
	var hit := origin + dir * t
	return Vector3(clampf(hit.x, -6.5, 6.5), TABLE_PLANE_Y, clampf(hit.z, -6.5, 6.5))


func _process(delta: float) -> void:
	_clock += delta
	_dice_scan_timer += delta
	if _dice_scan_timer >= 2.0:
		_dice_scan_timer = 0.0
		if net_table == null or grabber == null or seats == null:
			_discover_links()

	# 1. Atención automática de los avatares hacia piezas agarradas o dados rodando.
	if seats != null:
		if grabber != null and is_instance_valid(grabber.held):
			seats.set_focus_target(grabber.held.global_position, 0.25)
		else:
			for die in _dice_cache:
				if is_instance_valid(die) and (not die.sleeping or die.is_forced_rolling()):
					seats.set_focus_target(die.global_position, 0.35)
					break

	# 2. Envío a 10 Hz del puntero 3D local cuando hay partida online activa.
	_cursor_send_timer += delta
	if (
		_cursor_send_timer >= CURSOR_SEND_INTERVAL
		and net_table != null
		and Engine.has_singleton("Fusion")
		and Fusion.is_in_room()
	):
		_cursor_send_timer = 0.0
		var state: int = 1 if (grabber != null and is_instance_valid(grabber.held)) else 0
		var cur_pos: Vector3 = (
			grabber.held.global_position
			if (state == 1 and grabber != null and is_instance_valid(grabber.held))
			else _project_mouse_to_table()
		)
		if cur_pos.distance_to(_last_sent_pos) > 0.035 or state != _last_sent_state:
			_last_sent_pos = cur_pos
			_last_sent_state = state
			net_table.send_cursor(cur_pos, state)

	# 3. Interpolación exponencial suave de punteros remotos a 60+ FPS.
	var smooth := 1.0 - exp(-16.0 * delta)
	for i in MAX_SEATS:
		if not _pointers[i].visible:
			continue
		if _clock - _pointer_last_seen[i] > CURSOR_IDLE_HIDE:
			_pointers[i].visible = false
			continue
		_pointers[i].global_position = _pointers[i].global_position.lerp(_pointer_targets[i], smooth)
		# Orientar la mano desde la posición del asiento de ese jugador hacia el puntero.
		if seats != null:
			var seat_node := seats.avatar(i)
			if seat_node != null:
				var from_seat := _pointers[i].global_position - seat_node.global_position
				if Vector2(from_seat.x, from_seat.z).length_squared() > 0.01:
					var yaw := atan2(-from_seat.x, -from_seat.z)
					_pointers[i].rotation.y = lerp_angle(_pointers[i].rotation.y, yaw, smooth)
		var pinch_rot := -0.42 if _pointer_states[i] == 1 else 0.0
		_pointer_fingers[i].rotation.x = lerpf(_pointer_fingers[i].rotation.x, pinch_rot, smooth)
