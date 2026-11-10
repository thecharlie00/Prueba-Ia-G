class_name TableSeats
extends Node3D
## Jugadores sentados alrededor de la mesa: busto cartoon expresivo con cabeza articulada
## (Look-At suavizado), cejas y pupilas dinámicas, manos flotantes, abanico 3D de cartas
## rivales en tiempo real (RivalHandFan3D) y bocadillos de reacción estilo cómic (EmoteBubble3D).
## Es puramente visual: no tiene colisiones ni interfiere con Jolt Physics.

const BODY_HEIGHT := 1.25
const AVATAR_CLEARANCE := 0.6

var seats: Array[Dictionary] = []
var active := -1
## true para los asientos del lado de la cámara: su personaje se oculta (taparía la mesa y
## saldría cortado) y la interfaz lo muestra como ficha de jugador en pantalla.
var near: Array[bool] = []
var center := Vector3.ZERO

var _avatars: Array[Node3D] = []
var _heads: Array[Node3D] = []
var _brows_l: Array[Node3D] = []
var _brows_r: Array[Node3D] = []
var _pupils_l: Array[Node3D] = []
var _pupils_r: Array[Node3D] = []
var _mouths: Array[Node3D] = []
var _hands_l: Array[Node3D] = []
var _hands_r: Array[Node3D] = []
var _fans: Array[RivalHandFan3D] = []
var _emotes: Array[EmoteBubble3D] = []
var _emote_states: Array[String] = []
var _emote_timers: Array[float] = []
var _name_labels: Array[Label3D] = []
var _status_labels: Array[Label3D] = []
var _rings: Array[MeshInstance3D] = []
var _time := 0.0
var _turn_elapsed := 0.0
var _focus_target := Vector3.ZERO
var _focus_hold := 0.0


## Cada asiento: {name: String, color: Color, bot: bool, position: Vector3 (global, a ras de
## suelo), look_at: Vector3 (global)}.
func setup(new_seats: Array) -> void:
	for child in get_children():
		child.queue_free()
	seats.clear()
	_avatars.clear()
	_heads.clear()
	_brows_l.clear()
	_brows_r.clear()
	_pupils_l.clear()
	_pupils_r.clear()
	_mouths.clear()
	_hands_l.clear()
	_hands_r.clear()
	_fans.clear()
	_emotes.clear()
	_emote_states.clear()
	_emote_timers.clear()
	_name_labels.clear()
	_status_labels.clear()
	_rings.clear()
	near.clear()
	for item in new_seats:
		var seat_dict: Dictionary = item
		near.append(false)
		seats.append(seat_dict)
		_build_avatar(seat_dict)
	set_active(active)


func set_active(index: int) -> void:
	if index != active:
		_turn_elapsed = 0.0
		if active != -1 and index != -1:
			var sfx := get_node_or_null("/root/Sfx")
			if sfx != null:
				sfx.play("turn")
	active = index
	for i in _avatars.size():
		var on := i == index
		_rings[i].visible = on
		_name_labels[i].modulate = Palette.SUN if on else Palette.PAPER
		_name_labels[i].font_size = 72 if on else 60


func set_status(index: int, text: String) -> void:
	if index >= 0 and index < _status_labels.size():
		_status_labels[index].text = text


## Actualiza en tiempo real el abanico 3D de dorsos del asiento (solo entero público).
func set_card_count(index: int, count: int) -> void:
	if index >= 0 and index < _fans.size() and is_instance_valid(_fans[index]):
		_fans[index].set_card_count(maxi(count, 0))


func card_count(index: int) -> int:
	if index >= 0 and index < _fans.size() and is_instance_valid(_fans[index]):
		return _fans[index].card_count
	return 0


## Define hacia qué punto 3D de la mesa miran los avatares (dado rodando, ficha agarrada, ping).
func set_focus_target(world_pos: Vector3, hold_seconds: float = 1.0) -> void:
	_focus_target = world_pos
	_focus_hold = maxf(_focus_hold, hold_seconds)


## Dispara un bocadillo cómic y expresión facial/gestual en el avatar del asiento indicado.
func trigger_emote(index: int, emote_id: String, duration: float = 2.15) -> void:
	if index < 0 or index >= _emotes.size():
		return
	_emote_states[index] = emote_id
	_emote_timers[index] = duration
	if is_instance_valid(_emotes[index]):
		_emotes[index].show_emote(emote_id, duration)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("pop", -4.0)


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


## Asientos repartidos en círculo alrededor de center, mirando al centro.
static func ring(center_pos: Vector3, radius: float, floor_y: float, angles: Array) -> Array:
	var spots := []
	for angle in angles:
		var a := deg_to_rad(float(angle))
		spots.append(
			{
				"position": Vector3(
					center_pos.x + cos(a) * radius, floor_y, center_pos.z + sin(a) * radius
				),
				"look_at": Vector3(center_pos.x, floor_y, center_pos.z),
			}
		)
	return spots


## Caja de la mesa física (BoxShape3D del colisionador), en coordenadas globales.
static func table_aabb(shape_node: CollisionShape3D) -> AABB:
	var box := shape_node.shape as BoxShape3D
	if box == null:
		return AABB()
	var half := box.size * 0.5
	return AABB(shape_node.global_position - half, half * 2.0)


## Asiento fuera de la caja de la mesa expandida `clearance`, a ras de suelo.
static func seat_outside(
	center_pos: Vector3,
	dir: Vector3,
	floor_y: float,
	bounds: AABB,
	clearance: float
) -> Vector3:
	var d := Vector2(dir.x, dir.z)
	if d.length() < 0.01:
		return Vector3(center_pos.x, floor_y, center_pos.z)
	d = d.normalized()
	var radius := INF
	var max_corner := bounds.position + bounds.size
	if d.x > 0.01:
		radius = minf(radius, (max_corner.x + clearance - center_pos.x) / d.x)
	elif d.x < -0.01:
		radius = minf(radius, (bounds.position.x - clearance - center_pos.x) / d.x)
	if d.y > 0.01:
		radius = minf(radius, (max_corner.z + clearance - center_pos.z) / d.y)
	elif d.y < -0.01:
		radius = minf(radius, (bounds.position.z - clearance - center_pos.z) / d.y)
	if radius == INF:
		return Vector3(center_pos.x, floor_y, center_pos.z)
	radius = maxf(radius, 0.0)
	return Vector3(center_pos.x + d.x * radius, floor_y, center_pos.z + d.y * radius)


func _process(delta: float) -> void:
	_time += delta
	_turn_elapsed += delta
	if _focus_hold > 0.0:
		_focus_hold = maxf(_focus_hold - delta, 0.0)

	var camera := get_viewport().get_camera_3d()
	if camera != null and not _avatars.is_empty():
		update_near(camera.global_position)

	var style := get_node_or_null("/root/ToonStyle")
	var calm: bool = style != null and style.reduce_motion
	var head_blend := 1.0 - exp(-8.5 * delta)
	var eye_blend := 1.0 - exp(-18.0 * delta)
	var hand_blend := 1.0 - exp(-11.0 * delta)

	for i in _avatars.size():
		if _emote_timers[i] > 0.0:
			_emote_timers[i] = maxf(_emote_timers[i] - delta, 0.0)
			if _emote_timers[i] <= 0.0:
				_emote_states[i] = ""

		var body := _avatars[i].get_node("Body") as Node3D
		if i == active and not calm:
			var hop := absf(sin(_time * 4.0))
			body.position.y = hop * 0.11
			body.scale = Vector3(
				1.0 + (1.0 - hop) * 0.045,
				1.0 - (1.0 - hop) * 0.045,
				1.0 + (1.0 - hop) * 0.045
			)
			_rings[i].rotation.y = _time * 0.8
		else:
			var breath := sin(_time * 1.65 + float(i) * 1.3) * 0.016 if not calm else 0.0
			body.position.y = 0.0
			body.scale = Vector3(1.0 - breath, 1.0 + breath, 1.0 - breath)

		_animate_head_and_face(i, calm, head_blend, eye_blend)
		_animate_hands(i, calm, hand_blend)


func _animate_head_and_face(
	i: int,
	calm: bool,
	head_blend: float,
	eye_blend: float
) -> void:
	var head := _heads[i]
	var look_world := center + Vector3(0.0, 0.85, 0.0)
	if _focus_hold > 0.0:
		look_world = _focus_target
	elif i != active and active >= 0 and active < _avatars.size():
		var cycle := fmod(_time + float(i) * 2.1, 7.5)
		if cycle < 2.5:
			look_world = _avatars[active].global_position + Vector3(0.0, 0.95, 0.0)
		elif cycle > 5.8 and _fans[i].card_count > 0:
			look_world = _fans[i].global_position
	elif not calm:
		look_world += Vector3(
			sin(_time * 0.85 + float(i)) * 0.55,
			0.0,
			cos(_time * 0.72 + float(i) * 1.4) * 0.45
		)

	var local_target := _avatars[i].to_local(look_world) - Vector3(0.0, 0.96, 0.0)
	var fwd := maxf(-local_target.z, 0.30)
	var target_yaw := 0.0 if calm else clampf(atan2(-local_target.x, fwd), -0.68, 0.68)
	var target_pitch := 0.0 if calm else clampf(atan2(local_target.y, fwd), -0.34, 0.25)

	var emote := _emote_states[i]
	if emote == "laugh" and not calm:
		target_pitch += sin(_time * 18.0) * 0.12 + 0.08
	elif emote == "shock" and not calm:
		target_yaw += sin(_time * 24.0) * 0.06

	head.rotation.y = lerpf(head.rotation.y, target_yaw, head_blend)
	head.rotation.x = lerpf(head.rotation.x, target_pitch, head_blend)

	var px := 0.0 if calm else clampf(local_target.x * 0.016, -0.024, 0.024)
	var py := 0.0 if calm else clampf(local_target.y * 0.014, -0.018, 0.018)
	_pupils_l[i].position.x = lerpf(_pupils_l[i].position.x, -0.12 + px, eye_blend)
	_pupils_l[i].position.y = lerpf(_pupils_l[i].position.y, 0.22 + py, eye_blend)
	_pupils_r[i].position.x = lerpf(_pupils_r[i].position.x, 0.12 + px, eye_blend)
	_pupils_r[i].position.y = lerpf(_pupils_r[i].position.y, 0.22 + py, eye_blend)

	# Expresión de cejas y boca según estado de turno / emote.
	var brow_l_rot := 0.06
	var brow_r_rot := -0.06
	var brow_y := 0.32
	var mouth_scale := Vector3(1.0, 1.0, 0.45)
	if emote == "victory" or emote == "clap":
		brow_y = 0.35
		brow_l_rot = -0.16
		brow_r_rot = 0.16
		mouth_scale = Vector3(1.25, 1.15, 0.65)
	elif emote == "shock":
		brow_y = 0.37
		brow_l_rot = -0.28
		brow_r_rot = 0.08
		mouth_scale = Vector3(0.75, 1.35, 0.85)
	elif emote == "laugh":
		brow_y = 0.35
		brow_l_rot = -0.20
		brow_r_rot = 0.20
		mouth_scale = Vector3(1.35, 1.25, 0.75)
	elif emote == "hurry":
		brow_y = 0.30
		brow_l_rot = 0.22
		brow_r_rot = -0.22
	elif i == active and _turn_elapsed > 3.5:
		# Pensando su jugada: una ceja arqueada.
		brow_l_rot = 0.16
		brow_r_rot = -0.18
		mouth_scale = Vector3(0.72, 0.9, 0.45)

	_brows_l[i].position.y = lerpf(_brows_l[i].position.y, brow_y, head_blend)
	_brows_r[i].position.y = lerpf(_brows_r[i].position.y, brow_y, head_blend)
	_brows_l[i].rotation.z = lerpf(_brows_l[i].rotation.z, brow_l_rot, head_blend)
	_brows_r[i].rotation.z = lerpf(_brows_r[i].rotation.z, brow_r_rot, head_blend)
	_mouths[i].scale = _mouths[i].scale.lerp(mouth_scale, head_blend)


func _animate_hands(i: int, calm: bool, hand_blend: float) -> void:
	var has_cards := _fans[i].card_count > 0
	var emote := _emote_states[i]
	var target_l := Vector3(-0.33, 0.62, -0.28)
	var target_r := Vector3(0.33, 0.62, -0.28)
	if has_cards:
		# Mano izquierda sostiene el abanico; derecha lista junto a las cartas.
		target_l = Vector3(-0.22, 0.84, -0.44)
		target_r = Vector3(0.26, 0.80, -0.40)

	if not calm:
		var sway := sin(_time * 2.1 + float(i)) * 0.022
		target_l.y += sway
		target_r.y -= sway
		if emote == "victory":
			var wave := absf(sin(_time * 10.0)) * 0.12
			target_l = Vector3(-0.34, 1.22 + wave, -0.22)
			target_r = Vector3(0.34, 1.22 + wave, -0.22)
		elif emote == "clap":
			var clap := absf(sin(_time * 15.0)) * 0.11
			target_l = Vector3(-0.07 - clap, 0.88, -0.42)
			target_r = Vector3(0.07 + clap, 0.88, -0.42)
		elif emote == "shock":
			target_l = Vector3(-0.28, 1.02, -0.34)
			target_r = Vector3(0.28, 1.02, -0.34)
		elif i == active and _turn_elapsed > 3.5:
			# Mano derecha en la barbilla pensando jugada.
			target_r = Vector3(0.11, 0.83 + sin(_time * 5.0) * 0.015, -0.39)

	_hands_l[i].position = _hands_l[i].position.lerp(target_l, hand_blend)
	_hands_r[i].position = _hands_r[i].position.lerp(target_r, hand_blend)


func _build_avatar(seat: Dictionary) -> void:
	var seat_idx := _avatars.size()
	var root := Node3D.new()
	root.name = "Seat%d" % seat_idx
	add_child(root)
	var position: Vector3 = seat.get("position", Vector3.ZERO)
	root.global_position = position
	var target: Vector3 = seat.get("look_at", Vector3.ZERO)
	target.y = position.y
	if target.distance_to(position) > 0.01:
		root.look_at(target, Vector3.UP)
	_avatars.append(root)

	var color: Color = seat.get("color", Palette.SUN)
	var is_bot: bool = seat.get("bot", false) == true
	var is_host: bool = seat.get("host", false) == true
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var skin := StandardMaterial3D.new()
	skin.albedo_color = color
	skin.roughness = 0.52

	# 1. Torso redondeado con hombros cartoon y cuello de camisa claro.
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = PieceKit.lathe(
		PieceKit.smooth_profile(
			PackedVector2Array(
				[
					Vector2(0.36, 0.0),
					Vector2(0.43, 0.18),
					Vector2(0.41, 0.52),
					Vector2(0.28, 0.72),
					Vector2(0.0, 0.76),
				]
			),
			4
		),
		28
	)
	shell.material_override = skin
	body.add_child(shell)

	var collar_mat := StandardMaterial3D.new()
	collar_mat.albedo_color = Palette.PAPER
	var collar := MeshInstance3D.new()
	collar.name = "Collar"
	collar.mesh = PieceKit.torus(0.23, 0.038, 22)
	collar.position = Vector3(0.0, 0.72, 0.0)
	collar.material_override = collar_mat
	body.add_child(collar)

	var belly := StandardMaterial3D.new()
	belly.albedo_color = color.lerp(Palette.PAPER, 0.55)
	var patch := MeshInstance3D.new()
	patch.mesh = PieceKit.dot(0.21, 0.045)
	patch.material_override = belly
	patch.position = Vector3(0.0, 0.38, -0.39)
	patch.rotation_degrees.x = -90.0
	body.add_child(patch)

	# 2. Cabeza articulada (HeadPivot) para Look-At expresivo y reacciones.
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 0.74, 0.0)
	body.add_child(head_pivot)
	_heads.append(head_pivot)

	var head_mesh := MeshInstance3D.new()
	head_mesh.name = "HeadMesh"
	head_mesh.mesh = PieceKit.lathe(
		PieceKit.smooth_profile(
			PackedVector2Array(
				[
					Vector2(0.0, 0.0),
					Vector2(0.28, 0.06),
					Vector2(0.34, 0.24),
					Vector2(0.29, 0.43),
					Vector2(0.0, 0.52),
				]
			),
			4
		),
		26
	)
	head_mesh.material_override = skin
	head_pivot.add_child(head_mesh)

	var white := StandardMaterial3D.new()
	white.albedo_color = Palette.PAPER
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Palette.INK

	var brow_box := PieceKit.rounded_box(Vector3(0.115, 0.028, 0.032), 0.01, 3)
	for side_idx in 2:
		var side := -1.0 if side_idx == 0 else 1.0
		var eye := MeshInstance3D.new()
		var pupil := MeshInstance3D.new()
		if is_bot:
			eye.mesh = PieceKit.rounded_box(Vector3(0.15, 0.11, 0.045), 0.025, 3)
			pupil.mesh = PieceKit.rounded_box(Vector3(0.062, 0.062, 0.03), 0.012, 3)
		else:
			eye.mesh = PieceKit.dot(0.088, 0.035)
			pupil.mesh = PieceKit.dot(0.044, 0.028)
			eye.rotation_degrees.x = -90.0
			pupil.rotation_degrees.x = -90.0
		eye.material_override = white
		pupil.material_override = ink
		eye.position = Vector3(side * 0.12, 0.23, -0.31)
		pupil.position = Vector3(side * 0.12, 0.22, -0.345)
		head_pivot.add_child(eye)
		head_pivot.add_child(pupil)
		if side_idx == 0:
			_pupils_l.append(pupil)
		else:
			_pupils_r.append(pupil)

		var brow := MeshInstance3D.new()
		brow.name = "BrowL" if side_idx == 0 else "BrowR"
		brow.mesh = brow_box
		brow.material_override = ink
		brow.position = Vector3(side * 0.125, 0.32, -0.315)
		brow.rotation.z = 0.06 if side_idx == 0 else -0.06
		head_pivot.add_child(brow)
		if side_idx == 0:
			_brows_l.append(brow)
		else:
			_brows_r.append(brow)

	var mouth := MeshInstance3D.new()
	mouth.name = "Mouth"
	mouth.mesh = PieceKit.torus(0.056, 0.013, 18)
	mouth.material_override = ink
	mouth.position = Vector3(0.0, 0.11, -0.325)
	mouth.rotation_degrees = Vector3(-70.0, 0.0, 0.0)
	mouth.scale = Vector3(1.0, 1.0, 0.45)
	head_pivot.add_child(mouth)
	_mouths.append(mouth)

	if is_bot:
		var antenna := MeshInstance3D.new()
		antenna.mesh = PieceKit.rounded_box(Vector3(0.038, 0.24, 0.038), 0.016, 3)
		antenna.material_override = ink
		antenna.position = Vector3(0.0, 0.60, 0.0)
		head_pivot.add_child(antenna)
		var bulb := StandardMaterial3D.new()
		bulb.albedo_color = Palette.SUN
		bulb.emission_enabled = true
		bulb.emission = Palette.SUN
		bulb.emission_energy_multiplier = 0.6
		var ball := MeshInstance3D.new()
		ball.mesh = PieceKit.dot(0.068, 0.068)
		ball.material_override = bulb
		ball.position = Vector3(0.0, 0.74, 0.0)
		head_pivot.add_child(ball)
	elif is_host:
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Palette.SUN
		gold.roughness = 0.35
		var crown := MeshInstance3D.new()
		crown.name = "HostCrown"
		crown.mesh = PieceKit.torus(0.14, 0.032, 16)
		crown.position = Vector3(0.0, 0.53, 0.0)
		crown.material_override = gold
		head_pivot.add_child(crown)

	# 3. Manos flotantes expresivas estilo cartoon (manoplas redondeadas).
	var mitten_mesh := SphereMesh.new()
	mitten_mesh.radius = 0.095
	mitten_mesh.height = 0.17
	mitten_mesh.radial_segments = 14
	mitten_mesh.rings = 7
	var cuff_mesh := PieceKit.torus(0.072, 0.022, 14)
	for hand_idx in 2:
		var hand := Node3D.new()
		hand.name = "HandL" if hand_idx == 0 else "HandR"
		var side := -1.0 if hand_idx == 0 else 1.0
		hand.position = Vector3(side * 0.33, 0.62, -0.28)
		var glove := MeshInstance3D.new()
		glove.mesh = mitten_mesh
		glove.material_override = white
		hand.add_child(glove)
		var cuff := MeshInstance3D.new()
		cuff.mesh = cuff_mesh
		cuff.position = Vector3(0.0, 0.0, 0.055)
		cuff.rotation_degrees.x = 90.0
		cuff.material_override = skin
		hand.add_child(cuff)
		body.add_child(hand)
		if hand_idx == 0:
			_hands_l.append(hand)
		else:
			_hands_r.append(hand)

	# 4. Abanico 3D de cartas rivales y bocadillo cómic de emotes.
	var fan := RivalHandFan3D.new()
	fan.name = "RivalHandFan"
	fan.seat_index = seat_idx
	fan.position = Vector3(0.0, 0.94, -0.50)
	root.add_child(fan)
	_fans.append(fan)

	var emote_bubble := EmoteBubble3D.new()
	emote_bubble.name = "EmoteBubble"
	emote_bubble.position = Vector3(0.46, BODY_HEIGHT + 0.42, -0.10)
	root.add_child(emote_bubble)
	_emotes.append(emote_bubble)
	_emote_states.append("")
	_emote_timers.append(0.0)

	# 5. Aro de turno activo y etiquetas flotantes.
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Palette.SUN
	var turn_ring := MeshInstance3D.new()
	turn_ring.name = "TurnRing"
	turn_ring.mesh = PieceKit.torus(0.6, 0.05, 36)
	turn_ring.material_override = ring_material
	turn_ring.position.y = 0.04
	turn_ring.visible = false
	root.add_child(turn_ring)
	_rings.append(turn_ring)

	var status := _label("", 40)
	status.position.y = BODY_HEIGHT + (0.52 if is_bot else 0.24)
	var name_label := _label(str(seat.get("name", "Jugador")), 60)
	name_label.position.y = status.position.y + 0.30
	root.add_child(name_label)
	_name_labels.append(name_label)
	status.modulate = Palette.LAVENDER
	root.add_child(status)
	_status_labels.append(status)


func _label(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = (
		get_node_or_null("/root/ToonStyle").DISPLAY_FONT if has_node("/root/ToonStyle") else null
	)
	label.font_size = size
	label.pixel_size = 0.005
	label.outline_size = 18
	label.outline_modulate = Palette.INK
	label.modulate = Palette.PAPER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	return label
