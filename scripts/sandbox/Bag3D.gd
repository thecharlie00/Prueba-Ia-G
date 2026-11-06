class_name Bag3D
extends TableUtility
## Bolsa de tela: suelta una pieza encima para guardarla; N saca una al azar. Muestra cuántas
## piezas lleva dentro. Guarda las piezas con el mismo formato que la mesa.

const MAX_CONTENTS := 60
const DROP_RADIUS := 0.5

var contents: Array[Dictionary] = []
# Se carga en tiempo de ejecución: SandboxPersistence ya precarga la escena de la bolsa y una
# referencia directa crearía un ciclo de scripts que no se libera al salir.
var _persistence: Script = null
var _label: Label3D


func _ready() -> void:
	super._ready()
	var sack := PieceKit.smooth_profile(
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.26, 0.02), Vector2(0.34, 0.14), Vector2(0.32, 0.3),
			Vector2(0.18, 0.42), Vector2(0.12, 0.46), Vector2(0.17, 0.54), Vector2(0.0, 0.55),
		])
	)
	$Visual.mesh = PieceKit.lathe(sack, 28)
	$Visual.position.y = -0.24
	$Visual.material_override = _material(piece_color, 0.9)
	var cord := MeshInstance3D.new()
	cord.name = "Cord"
	cord.mesh = PieceKit.torus(0.13, 0.022)
	cord.position.y = 0.44
	cord.material_override = _material(Palette.SUN)
	$Visual.add_child(cord)
	_label = _make_label(0.62, 80)
	_refresh()


func can_hold(object: InteractiveTableObject) -> bool:
	return (
		is_instance_valid(object)
		and object != self
		and not (object is Bag3D)
		and contents.size() < MAX_CONTENTS
	)


## Guarda la pieza dentro de la bolsa (la pieza desaparece de la mesa).
func put(object: InteractiveTableObject) -> bool:
	if not can_hold(object):
		return false
	var data: Dictionary = _store().piece_data(object)
	if data.is_empty():
		return false
	contents.append(data)
	object.get_parent().remove_child(object)
	object.queue_free()
	_refresh()
	_juice(Vector3(1.18, 0.86, 1.18))
	_sound("pop")
	return true


## Saca una pieza al azar y la deja junto a la bolsa.
func draw_random() -> InteractiveTableObject:
	if contents.is_empty() or is_grabbed or not is_inside_tree():
		return null
	var index := randi() % contents.size()
	var data: Dictionary = contents[index]
	var object: InteractiveTableObject = _store().instantiate_piece(data)
	if object == null:
		return null
	contents.remove_at(index)
	var base_name := String(data["name"])
	object.name = base_name
	get_parent().add_child(object, true)
	var side := Vector3(randf_range(-0.25, 0.25), 0.0, 0.62).rotated(Vector3.UP, global_rotation.y)
	object.global_position = global_position + side + Vector3.UP * 0.35
	object.sleeping = false
	_refresh()
	_juice(Vector3(0.88, 1.15, 0.88))
	_sound("pop")
	return object


func _store() -> Script:
	if _persistence == null:
		_persistence = load("res://scripts/sandbox/SandboxPersistence.gd")
	return _persistence


func _refresh() -> void:
	if _label != null:
		_label.text = "×%d" % contents.size()


func handle_shortcut(keycode: int) -> bool:
	if keycode == KEY_N:
		draw_random()
	elif keycode == KEY_R:
		contents.shuffle()
		_juice(Vector3(1.1, 0.9, 1.1))
		_sound("dice")
	else:
		return false
	return true


func radial_actions() -> Array[Dictionary]:
	return [
		{"label": "Sacar al azar", "key": "N", "keycode": KEY_N},
		{"label": "Agitar", "key": "R", "keycode": KEY_R},
	]


func shortcut_hint() -> String:
	return "Bolsa · suelta piezas encima · N sacar al azar · R agitar"


func extra_data() -> Dictionary:
	return {
		"contents": contents.duplicate(true),
		"color": [piece_color.r, piece_color.g, piece_color.b, piece_color.a],
	}


func apply_extra(data: Dictionary) -> void:
	contents.clear()
	for entry in data["contents"]:
		contents.append(entry)
	_refresh()
