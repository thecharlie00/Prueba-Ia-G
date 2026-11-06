class_name HiddenZone3D
extends Node3D
## Zona privada de un jugador en la mesa libre (queja 5 de TTS). Lo que se deja dentro solo
## lo ve su dueño: para los demás cada pieza se convierte en una nubecilla con un «?» que
## flota en su sitio (se sabe cuántas hay, no cuáles son) y no se puede agarrar. Quién mira lo
## decide el asiento elegido con V (vista por asiento).

const HIDDEN_META := &"private_hidden"

@export var owner_seat := 1
@export var zone_size := Vector2(2.2, 0.95)
@export var zone_color := Palette.CORAL
var objects: Node
var viewer_seat := 1
var inside: Array[InteractiveTableObject] = []

var _mat: MeshInstance3D
var _title: Label3D
## Nubecilla que sustituye a cada pieza oculta (pieza -> marcador).
var _puffs := {}
var _time := 0.0


func _ready() -> void:
	_mat = MeshInstance3D.new()
	_mat.name = "Mat"
	_mat.mesh = PieceKit.rounded_slab(Vector3(zone_size.x, 0.012, zone_size.y), 0.12, 0.004)
	var mat_material := StandardMaterial3D.new()
	mat_material.albedo_color = zone_color.lerp(Palette.FELT, 0.45)
	mat_material.roughness = 0.9
	_mat.material_override = mat_material
	add_child(_mat)
	# Ribete fino del color del jugador alrededor del tapete.
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = PieceKit.rounded_slab(Vector3(zone_size.x + 0.07, 0.008, zone_size.y + 0.07), 0.15, 0.003)
	rim.position.y = -0.003
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = zone_color
	rim.material_override = rim_material
	add_child(rim)
	_title = _label(Vector3(0, 0.02, zone_size.y * 0.5 + 0.12), 52)
	_title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_title.rotation_degrees.x = -90.0
	_title.font_size = 40
	_refresh()


func _label(at: Vector3, size: int) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = size
	label.pixel_size = 0.003
	label.outline_size = 18
	label.outline_modulate = Palette.INK
	label.modulate = Palette.PAPER
	label.position = at
	var style := get_node_or_null("/root/ToonStyle")
	if style != null:
		label.font = style.DISPLAY_FONT
	add_child(label)
	return label


func is_hidden_for_viewer() -> bool:
	return viewer_seat != owner_seat


func set_viewer(seat: int) -> void:
	viewer_seat = seat
	_refresh()


func contains_point(point: Vector3) -> bool:
	var local := to_local(point)
	return (
		absf(local.x) <= zone_size.x * 0.5
		and absf(local.z) <= zone_size.y * 0.5
		and local.y > -0.2
		and local.y < 0.8
	)


func _physics_process(delta: float) -> void:
	if objects == null:
		return
	_time += delta
	var now: Array[InteractiveTableObject] = []
	for child in objects.get_children():
		var object := child as InteractiveTableObject
		if object != null and not object.is_grabbed and contains_point(object.global_position):
			now.append(object)
	for object in inside:
		if is_instance_valid(object) and not now.has(object):
			_reveal(object)
	inside = now
	_refresh()


func _exit_tree() -> void:
	for object in inside:
		if is_instance_valid(object):
			_reveal(object)


## Número de piezas que los demás ven como nubecillas.
func hidden_count() -> int:
	return _puffs.size()


func _refresh() -> void:
	var hidden := is_hidden_for_viewer()
	for object in inside:
		if not is_instance_valid(object):
			continue
		object.set_meta(HIDDEN_META, hidden)
		# La pieza deja de dibujarse pero su física sigue igual.
		object.visible = not hidden
		if hidden:
			if object.hovered:
				object.set_hovered(false)
			_place_puff(object)
		elif _puffs.has(object):
			_drop_puff(object)
	for object in _puffs.keys():
		if not is_instance_valid(object) or not inside.has(object):
			_drop_puff(object)
	if _title == null:
		return
	_title.text = (
		tr("Mano de J%d · oculta") % owner_seat
		if hidden
		else tr("Tu mano · J%d · solo la ves tú") % owner_seat
	)


func _reveal(object: InteractiveTableObject) -> void:
	object.remove_meta(HIDDEN_META)
	object.visible = true
	_drop_puff(object)


func _place_puff(object: InteractiveTableObject) -> void:
	var puff: Node3D = _puffs.get(object)
	if puff == null:
		puff = _make_puff()
		_puffs[object] = puff
	var bob := sin(_time * 2.2 + float(object.get_instance_id() % 97)) * 0.025
	puff.global_position = Vector3(object.global_position.x, global_position.y + 0.16 + bob, object.global_position.z)


func _drop_puff(object: Variant) -> void:
	var puff: Node3D = _puffs.get(object)
	if puff != null:
		puff.queue_free()
	_puffs.erase(object)


## Tres bolitas suaves del color del jugador y un «?» encima: discreto y legible.
func _make_puff() -> Node3D:
	var puff := Node3D.new()
	puff.name = "Puff"
	puff.scale = Vector3.ONE * 1.9
	add_child(puff)
	var material := StandardMaterial3D.new()
	material.albedo_color = zone_color.lightened(0.35)
	material.roughness = 0.8
	for spec in [[Vector3(-0.07, 0, 0), 0.075], [Vector3(0.07, 0, 0.01), 0.07], [Vector3(0, 0.04, -0.02), 0.09]]:
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = spec[1]
		sphere.height = spec[1] * 1.6
		sphere.radial_segments = 16
		sphere.rings = 8
		ball.mesh = sphere
		ball.position = spec[0]
		ball.material_override = material
		puff.add_child(ball)
	var mark := _label(Vector3(0, 0.17, 0), 44)
	mark.text = "?"
	mark.reparent(puff, false)
	return puff
