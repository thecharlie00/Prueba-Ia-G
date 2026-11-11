# InteractiveComponent.gd
# Permite hacer clic, arrastrar, rotar en el aire, voltear (flip) e inspeccionar en primer plano.
class_name InteractiveComponent
extends BehaviorComponent

@export var clickable: Boolean = true
@export var draggable: Boolean = true
@export var flippable: Boolean = true
@export var inspect_on_hover: Boolean = false
@export var drag_snap_to_grid: Boolean = false
@export var grid_size: float = 0.25

# Nodo MeshInstance3D o similar que se manipula.
var target_node: Node3D = null

# Estado de arrastre activo.
var _is_dragging: Boolean = false
var _drag_start_position: Vector3 = Vector3.ZERO
var _drag_current_position: Vector3 = Vector3.ZERO

func _serialize_extra(data: Dictionary) -> void:
	data["clickable"] = clickable
	data["draggable"] = draggable
	data["flippable"] = flippable
	data["inspect_on_hover"] = inspect_on_hover
	data["drag_snap_to_grid"] = drag_snap_to_grid
	data["grid_size"] = grid_size

func _deserialize_extra(data: Dictionary) -> void:
	clickable = data.has("clickable") ? data["clickable"] : clickable
	draggable = data.has("draggable") ? data["draggable"] : draggable
	flippable = data.has("flippable") ? data["flippable"] : flippable
	inspect_on_hover = data.has("inspect_on_hover") ? data["inspect_on_hover"] : inspect_on_hover
	drag_snap_to_grid = data.has("drag_snap_to_grid") ? data["drag_snap_to_grid"] : drag_snap_to_grid
	grid_size = data.has("grid_size") ? data["grid_size"] : grid_size

# Invierte la entidad (frente <-> dorso) si es flippable.
func flip() -> void:
	if not flippable:
		return
	if target_node != null:
		target_node.rotation.y += PI

# Aplica snap a rejilla a una posición.
func snap_to_grid(position: Vector3) -> Vector3:
	if not drag_snap_to_grid or grid_size <= 0:
		return position
	return Vector3(
		round(position.x / grid_size) * grid_size,
		round(position.y / grid_size) * grid_size,
		round(position.z / grid_size) * grid_size
	)
