class_name PieceKit
extends RefCounted
## Mallas cartoon comunes a todas las piezas (docs/ARTE.md): formas redondeadas de una sola
## pieza con normales suaves, para que el contorno de tinta sea limpio y todo comparta lenguaje.
## Las mallas se cachean por parámetros; los colisionadores de las piezas no cambian.

static var _cache: Dictionary = {}


## Sólido de revolución. `profile` va de abajo arriba en (radio, altura); si empieza o acaba
## con radio > 0 se cierra con una tapa plana.
static func lathe(profile: PackedVector2Array, segments := 32, caps := true) -> ArrayMesh:
	var key := "lathe:%d:%s:%s" % [segments, caps, str(profile)]
	if _cache.has(key):
		return _cache[key]
	var points := PackedVector2Array()
	if caps and profile[0].x > 0.0001:
		points.append(Vector2(0.0, profile[0].y))
	points.append_array(profile)
	if caps and profile[profile.size() - 1].x > 0.0001:
		points.append(Vector2(0.0, profile[profile.size() - 1].y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normals := _profile_normals(points)
	for i in points.size():
		for s in segments + 1:
			var a := TAU * float(s) / float(segments)
			var dir := Vector3(cos(a), 0.0, sin(a))
			st.set_normal((dir * normals[i].x + Vector3.UP * normals[i].y).normalized())
			st.set_uv(Vector2(float(s) / segments, float(i) / (points.size() - 1)))
			st.add_vertex(dir * points[i].x + Vector3.UP * points[i].y)
	var ring := segments + 1
	for i in points.size() - 1:
		for s in segments:
			var a := i * ring + s
			var b := a + ring
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Normales del perfil 2D: perpendicular a la media de los segmentos vecinos (forma suave),
## salvo en los vértices del eje, que miran hacia arriba o abajo.
static func _profile_normals(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	result.resize(points.size())
	for i in points.size():
		var prev := points[maxi(i - 1, 0)]
		var next := points[mini(i + 1, points.size() - 1)]
		var tangent := (next - prev).normalized()
		var normal := Vector2(tangent.y, -tangent.x)
		if points[i].x < 0.0001:
			normal = Vector2(0.0, -1.0 if i == 0 else 1.0)
		result[i] = normal
	return result


## Perfil de disco con canto redondeado (fichas de damas, monedas, bases de pieza).
static func rounded_disc_profile(radius: float, height: float, bevel: float, steps := 4) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.append(Vector2(radius - bevel, 0.0))
	for i in range(1, steps + 1):
		var a := -PI * 0.5 + PI * 0.5 * float(i) / steps
		p.append(Vector2(radius - bevel + cos(a) * bevel, bevel + sin(a) * bevel))
	for i in range(0, steps + 1):
		var a := PI * 0.5 * float(i) / steps
		p.append(Vector2(radius - bevel + cos(a) * bevel, height - bevel + sin(a) * bevel))
	p.append(Vector2(radius - bevel, height))
	return p


## Disco redondeado centrado en el origen (como CylinderMesh).
static func rounded_disc(radius: float, height: float, bevel: float, segments := 32) -> ArrayMesh:
	var profile := rounded_disc_profile(radius, height, bevel)
	for i in profile.size():
		profile[i].y -= height * 0.5
	return lathe(profile, segments)


## Caja de esquinas redondeadas, centrada en el origen (sustituye a BoxMesh).
static func rounded_box(size: Vector3, radius: float, steps := 6) -> ArrayMesh:
	return rounded_box_xyz(size, Vector3.ONE * radius, steps)


## Losa con esquinas muy redondeadas en planta y canto fino (cartas, mazos, losetas):
## `corner` redondea el contorno visto desde arriba y `edge` el canto.
static func rounded_slab(size: Vector3, corner: float, edge: float, steps := 7) -> ArrayMesh:
	return rounded_box_xyz(size, Vector3(corner, edge, corner), steps)


## Caja redondeada con un radio por eje (esquinas elipsoidales).
static func rounded_box_xyz(size: Vector3, radii: Vector3, steps := 6) -> ArrayMesh:
	var key := "rbox:%s:%s:%d" % [str(size), str(radii), steps]
	if _cache.has(key):
		return _cache[key]
	var half := size * 0.5
	radii = radii.clamp(Vector3.ONE * 0.0005, half)
	var inner := half - radii
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	var base := 0
	for face in faces:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var us := _axis_samples(absf(u.dot(half)), absf(u.dot(inner)), steps)
		var vs := _axis_samples(absf(v.dot(half)), absf(v.dot(inner)), steps)
		for a_u in us:
			for a_v in vs:
				var p: Vector3 = normal * half + u * a_u + v * a_v
				var core := p.clamp(-inner, inner)
				var e := (p - core) / radii
				var unit := e.normalized() if e.length() > 0.00001 else normal
				st.set_normal((unit / radii).normalized())
				st.add_vertex(core + unit * radii)
		var cols := vs.size()
		for iy in us.size() - 1:
			for ix in cols - 1:
				var a := base + iy * cols + ix
				var b := a + cols
				st.add_index(a)
				st.add_index(a + 1)
				st.add_index(b)
				st.add_index(a + 1)
				st.add_index(b + 1)
				st.add_index(b)
		base += us.size() * cols
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Coordenadas a lo largo de un eje de la cara: más muestras en las curvas que en lo plano.
static func _axis_samples(half: float, inner: float, steps: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in steps + 1:
		out.append(lerpf(-half, -inner, float(i) / steps))
	for i in range(1, steps + 1):
		out.append(lerpf(inner, half, float(i) / steps))
	return out


## Anillo (toro) de radio `ring` y grosor de tubo `tube`, centrado en el origen.
static func torus(ring: float, tube: float, segments := 32) -> ArrayMesh:
	var p := PackedVector2Array()
	for i in 13:
		var a := -PI + TAU * float(i) / 12.0
		p.append(Vector2(ring - cos(a) * tube, -sin(a) * tube))
	return lathe(p, segments, false)


## Perfil suave a partir de puntos de control (radio, altura), con una curva Catmull-Rom.
static func smooth_profile(points: PackedVector2Array, subdivisions := 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]
		for k in subdivisions:
			var t := float(k) / subdivisions
			var t2 := t * t
			var t3 := t2 * t
			out.append(
				0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			)
	out.append(points[points.size() - 1])
	for i in out.size():
		out[i].x = maxf(out[i].x, 0.0)
	return out


## Esfera achatada para puntos de dado y dominó: una "gota" de tinta que asoma de la cara.
static func dot(radius: float, depth: float) -> ArrayMesh:
	var p := PackedVector2Array()
	for i in range(0, 7):
		var a := -PI * 0.5 + PI * float(i) / 6.0
		p.append(Vector2(cos(a) * radius, sin(a) * depth))
	return lathe(p, 20)
