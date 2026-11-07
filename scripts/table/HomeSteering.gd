class_name HomeSteering
extends RefCounted
## Lleva una pieza física a su casa lógica con fuerzas (ajedrez, damas y dominó guiados).
## Si la casa está lejos, la pieza sube por encima de las demás, viaja y baja al llegar: así
## una pieza comida cruza el tablero hasta la bandeja sin quedarse atascada contra otras (lo
## encontraron las partidas completas de la fase 0).

const TRAVEL_START := 0.35  # A partir de esta distancia horizontal la pieza vuela.
const TRAVEL_END := 0.06  # Y aterriza cuando está así de cerca.
const LIFT := 0.45  # Altura de vuelo por encima de la casa.
const META := &"home_travel"
const MASK_META := &"home_travel_mask"
const PIECES_LAYER := 2  # Capa física de las piezas (layer_names: «Piezas»).


## Devuelve true si la pieza sigue en movimiento.
## lift: altura de vuelo sobre la casa (debe superar la pieza más alta de la mesa más media
## pieza). keep_upright: endereza las piezas altas que se inclinan (ajedrez).
static func steer(
	body: RigidBody3D, home: Vector3, spring: float, damping: float, max_acceleration: float,
	lift := LIFT, keep_upright := false
) -> bool:
	if keep_upright:
		_upright(body)
	var flat := Vector3(home.x - body.global_position.x, 0, home.z - body.global_position.z)
	var distance := flat.length()
	var traveling := bool(body.get_meta(META, false))
	if not traveling and distance > TRAVEL_START:
		traveling = true
		body.set_meta(META, true)
		# En el aire no choca con otras piezas: varias pueden viajar a la vez (la cadena del
		# dominó se desplaza entera al jugar por la izquierda) sin estorbarse.
		body.set_meta(MASK_META, body.collision_mask)
		body.collision_mask = body.collision_mask & ~PIECES_LAYER
	elif traveling and distance < TRAVEL_END:
		traveling = false
		land(body)
	var velocity := Vector3(body.linear_velocity.x, 0, body.linear_velocity.z)
	if not traveling and distance < 0.015 and velocity.length() < 0.03:
		return false
	var acceleration := flat * spring - velocity * damping
	if traveling:
		# Primero sube; solo avanza cuando ya va por encima de las demás piezas.
		var height := home.y + lift
		var climb := (height - body.global_position.y) * 40.0 - body.linear_velocity.y * 10.0
		climb += float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * body.gravity_scale
		if body.global_position.y < height - 0.2:
			acceleration = -velocity * damping
		acceleration.y = climb
		# Sin girar en el aire.
		body.angular_velocity *= 0.85
	if body.sleeping:
		body.sleeping = false
	body.apply_central_force(acceleration.limit_length(max_acceleration * (2.5 if traveling else 1.0)) * body.mass)
	return true


## Par que lleva el eje vertical de la pieza hacia arriba si se ha inclinado.
static func _upright(body: RigidBody3D) -> void:
	var up := body.global_basis.y.normalized()
	var tilt := up.cross(Vector3.UP)
	if tilt.length() < 0.03 and body.angular_velocity.length() < 0.05:
		return
	body.sleeping = false
	var torque := tilt * 6.0 - body.angular_velocity * 0.8
	body.apply_torque(torque * body.mass * 0.1)


## Termina el viaje: recupera las colisiones con las demás piezas.
static func land(body: RigidBody3D) -> void:
	body.remove_meta(META)
	if body.has_meta(MASK_META):
		body.collision_mask = int(body.get_meta(MASK_META))
		body.remove_meta(MASK_META)


static func is_traveling(body: Node) -> bool:
	return bool(body.get_meta(META, false))
