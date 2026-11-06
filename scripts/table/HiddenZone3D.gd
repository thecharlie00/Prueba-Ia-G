class_name HiddenZone3D
extends Node3D
## Zona privada de un jugador en la mesa libre (queja 5 de TTS). Lo que se deja dentro solo
## lo ve su dueño: para los demás queda tapado por una caja con el número de piezas, y no se
## puede agarrar. Quién mira lo decide el asiento elegido con V (vista por asiento).

const HIDDEN_META := &"private_hidden"

@export var owner_seat := 1
@export var zone_size := Vector2(2.2, 0.95)
@export var zone_color := Palette.CORAL
var objects: Node
var viewer_seat := 1
var inside: Array[InteractiveTableObject] = []

var _mat: MeshInstance3D
var _cover: MeshInstance3D
var _title: Label3D
var _count: Label3D


func _ready() -> void:
	_mat = MeshInstance3D.new()
	_mat.name = "Mat"
	_mat.mesh = PieceKit.rounded_slab(Vector3(zone_size.x, 0.012, zone_size.y), 0.12, 0.004)
	var mat_material := StandardMaterial3D.new()
	mat_material.albedo_color = zone_color.lerp(Palette.FELT, 0.45)
	mat_material.roughness = 0.9
	_mat.material_override = mat_material
	add_child(_mat)
	_cover = MeshInstance3D.new()
	_cover.name = "Cover"
	# La tapa sobresale un poco para que no asomen esquinas de cartas.
	_cover.mesh = PieceKit.rounded_box(Vector3(zone_size.x + 0.16, 0.42, zone_size.y + 0.16), 0.1)
	_cover.position.y = 0.22
	var cover_material := StandardMaterial3D.new()
	cover_material.albedo_color = zone_color
	cover_material.roughness = 0.6
	_cover.material_override = cover_material
	add_child(_cover)
	_title = _label(Vector3(0, 0.02, zone_size.y * 0.5 + 0.12), 52)
	_title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_title.rotation_degrees.x = -90.0
	_count = _label(Vector3(0, 0.62, 0), 84)
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


func _physics_process(_delta: float) -> void:
	if objects == null:
		return
	var now: Array[InteractiveTableObject] = []
	for child in objects.get_children():
		var object := child as InteractiveTableObject
		if object != null and not object.is_grabbed and contains_point(object.global_position):
			now.append(object)
	for object in inside:
		if is_instance_valid(object) and not now.has(object):
			object.remove_meta(HIDDEN_META)
	inside = now
	_refresh()


func _refresh() -> void:
	var hidden := is_hidden_for_viewer()
	for object in inside:
		if is_instance_valid(object):
			object.set_meta(HIDDEN_META, hidden)
			if hidden and object.hovered:
				object.set_hovered(false)
	if _cover == null:
		return
	_cover.visible = hidden
	_count.visible = hidden
	_count.text = "?" if inside.is_empty() else "%d ?" % inside.size()
	_title.text = (
		tr("Mano de J%d · oculta") % owner_seat
		if hidden
		else tr("Tu mano · J%d · solo la ves tú") % owner_seat
	)
