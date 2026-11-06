class_name TableSeats
extends Node3D
## Jugadores sentados alrededor de la mesa: un personaje cartoon por asiento, con su color,
## nombre y estado encima. El asiento con el turno salta y tiene un aro amarillo; los bots
## llevan antena y ojos de pantalla. Es solo visual: no tiene colisiones ni recibe clics.

const BODY_HEIGHT := 1.25

var seats: Array[Dictionary] = []
var active := -1
## true para los asientos del lado de la cámara: su personaje se oculta (taparía la mesa y
## saldría cortado) y la interfaz lo muestra como ficha de jugador en pantalla.
var near: Array[bool] = []
var center := Vector3.ZERO
var _avatars: Array[Node3D] = []
var _name_labels: Array[Label3D] = []
var _status_labels: Array[Label3D] = []
var _rings: Array[MeshInstance3D] = []
var _time := 0.0


## Cada asiento: {name: String, color: Color, bot: bool, position: Vector3 (global, a ras de
## suelo), look_at: Vector3 (global)}.
func setup(new_seats: Array) -> void:
	for child in get_children():
		child.queue_free()
	seats.clear()
	_avatars.clear()
	_name_labels.clear()
	_status_labels.clear()
	_rings.clear()
	near.clear()
	for seat in new_seats:
		near.append(false)
		seats.append(seat)
		_build_avatar(seat)
	set_active(active)


func set_active(index: int) -> void:
	active = index
	for i in _avatars.size():
		var on := i == index
		_rings[i].visible = on
		_name_labels[i].modulate = Palette.SUN if on else Palette.PAPER
		_name_labels[i].font_size = 72 if on else 60


func set_status(index: int, text: String) -> void:
	if index >= 0 and index < _status_labels.size():
		_status_labels[index].text = text


## Recalcula qué asientos quedan del lado de la cámara. Devuelve true si algo cambió.
func update_near(camera_position: Vector3) -> bool:
	var to_camera := Vector2(camera_position.x - center.x, camera_position.z - center.z)
	if to_camera.length() < 0.01:
		return false
	to_camera = to_camera.normalized()
	var changed := false
	for i in _avatars.size():
		var spot := _avatars[i].global_position
		var to_seat := Vector2(spot.x - center.x, spot.z - center.z).normalized()
		var is_near := to_seat.dot(to_camera) > 0.55
		if is_near != near[i]:
			near[i] = is_near
			_avatars[i].visible = not is_near
			changed = true
	return changed


func avatar(index: int) -> Node3D:
	return _avatars[index] if index >= 0 and index < _avatars.size() else null


## Asientos repartidos en círculo alrededor de center, mirando al centro. angles en grados
## (0 = +x, 90 = +z, hacia la cámara por defecto). floor_y: altura del suelo.
static func ring(center: Vector3, radius: float, floor_y: float, angles: Array) -> Array:
	var spots := []
	for angle in angles:
		var a := deg_to_rad(float(angle))
		spots.append(
			{
				"position": Vector3(center.x + cos(a) * radius, floor_y, center.z + sin(a) * radius),
				"look_at": Vector3(center.x, floor_y, center.z),
			}
		)
	return spots


func _process(delta: float) -> void:
	_time += delta
	# Oculta los personajes del lado de la cámara aunque la vista no use TableHud.
	var camera := get_viewport().get_camera_3d()
	if camera != null and not _avatars.is_empty():
		update_near(camera.global_position)
	var style := get_node_or_null("/root/ToonStyle")
	var calm: bool = style != null and style.reduce_motion
	for i in _avatars.size():
		var body := _avatars[i].get_node("Body") as Node3D
		if i == active and not calm:
			var hop := absf(sin(_time * 4.0))
			body.position.y = hop * 0.12
			body.scale = Vector3(1.0 + (1.0 - hop) * 0.05, 1.0 - (1.0 - hop) * 0.05, 1.0 + (1.0 - hop) * 0.05)
		else:
			# Respiración suave para que los que esperan no parezcan estatuas.
			var breath := sin(_time * 1.6 + i) * 0.015 if not calm else 0.0
			body.position.y = 0.0
			body.scale = Vector3(1.0 - breath, 1.0 + breath, 1.0 - breath)


func _build_avatar(seat: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Seat%d" % _avatars.size()
	add_child(root)
	var position: Vector3 = seat.get("position", Vector3.ZERO)
	root.global_position = position
	var target: Vector3 = seat.get("look_at", Vector3.ZERO)
	target.y = position.y
	if target.distance_to(position) > 0.01:
		root.look_at(target, Vector3.UP)
	_avatars.append(root)

	var color: Color = seat.get("color", Palette.SUN)
	var is_bot: bool = seat.get("bot", false)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var skin := StandardMaterial3D.new()
	skin.albedo_color = color
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = PieceKit.lathe(
		PieceKit.smooth_profile(
			PackedVector2Array(
				[
					Vector2(0.36, 0.0), Vector2(0.44, 0.18), Vector2(0.43, 0.6),
					Vector2(0.37, 0.98), Vector2(0.22, 1.18), Vector2(0.0, BODY_HEIGHT)
				]
			),
			4
		),
		36
	)
	shell.material_override = skin
	body.add_child(shell)

	var belly := StandardMaterial3D.new()
	belly.albedo_color = color.lerp(Palette.PAPER, 0.55)
	var patch := MeshInstance3D.new()
	patch.mesh = PieceKit.dot(0.24, 0.05)
	patch.material_override = belly
	patch.position = Vector3(0, 0.42, -0.41)
	patch.rotation_degrees.x = -90
	body.add_child(patch)

	var white := StandardMaterial3D.new()
	white.albedo_color = Palette.PAPER
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Palette.INK
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var pupil := MeshInstance3D.new()
		if is_bot:
			eye.mesh = PieceKit.rounded_box(Vector3(0.17, 0.12, 0.05), 0.03)
			pupil.mesh = PieceKit.rounded_box(Vector3(0.07, 0.07, 0.03), 0.015)
		else:
			eye.mesh = PieceKit.dot(0.1, 0.04)
			pupil.mesh = PieceKit.dot(0.05, 0.03)
			eye.rotation_degrees.x = -90
			pupil.rotation_degrees.x = -90
		eye.material_override = white
		pupil.material_override = ink
		eye.position = Vector3(side * 0.13, 0.93, -0.33)
		pupil.position = Vector3(side * 0.13, 0.92, -0.37)
		body.add_child(eye)
		body.add_child(pupil)
	var mouth := MeshInstance3D.new()
	mouth.mesh = PieceKit.torus(0.06, 0.014, 20)
	mouth.material_override = ink
	mouth.position = Vector3(0, 0.78, -0.36)
	mouth.rotation_degrees = Vector3(-70, 0, 0)
	mouth.scale = Vector3(1.0, 1.0, 0.45)
	body.add_child(mouth)
	if is_bot:
		var antenna := MeshInstance3D.new()
		antenna.mesh = PieceKit.rounded_box(Vector3(0.04, 0.26, 0.04), 0.018)
		antenna.material_override = ink
		antenna.position = Vector3(0, BODY_HEIGHT + 0.1, 0)
		body.add_child(antenna)
		var bulb := StandardMaterial3D.new()
		bulb.albedo_color = Palette.SUN
		bulb.emission_enabled = true
		bulb.emission = Palette.SUN
		bulb.emission_energy_multiplier = 0.6
		var ball := MeshInstance3D.new()
		ball.mesh = PieceKit.dot(0.07, 0.07)
		ball.material_override = bulb
		ball.position = Vector3(0, BODY_HEIGHT + 0.26, 0)
		body.add_child(ball)

	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Palette.SUN
	var ring := MeshInstance3D.new()
	ring.name = "TurnRing"
	ring.mesh = PieceKit.torus(0.6, 0.05, 40)
	ring.material_override = ring_material
	ring.position.y = 0.04
	ring.visible = false
	root.add_child(ring)
	_rings.append(ring)

	# Estado justo encima de la cabeza (o de la antena) y nombre encima, sin solaparse.
	var status := _label("", 40)
	status.position.y = BODY_HEIGHT + (0.52 if is_bot else 0.22)
	var name_label := _label(str(seat.get("name", "Jugador")), 60)
	name_label.position.y = status.position.y + 0.3
	root.add_child(name_label)
	_name_labels.append(name_label)
	status.modulate = Palette.LAVENDER
	root.add_child(status)
	_status_labels.append(status)


func _label(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = get_node_or_null("/root/ToonStyle").DISPLAY_FONT if has_node("/root/ToonStyle") else null
	label.font_size = size
	label.pixel_size = 0.005
	label.outline_size = 18
	label.outline_modulate = Palette.INK
	label.modulate = Palette.PAPER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	return label
