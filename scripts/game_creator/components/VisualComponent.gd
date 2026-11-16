# VisualComponent.gd
# Apariencia 3D de una entidad: malla, material, escala y tinte de color.
class_name VisualComponent
extends BehaviorComponent

## Forma de la pieza (PieceShapes.SHAPES).
@export var shape: String = "ficha"
## Texto escrito en la cara de arriba (números de carta, nombres de zona…).
@export var label: String = ""
## Dibujo de la cara de arriba (PieceShapes.PATTERNS) y casillas por lado.
@export var pattern: String = "liso"
@export var cells: int = 8
## Acabado del material (PieceShapes.FINISHES).
@export var finish: String = "mate"
@export var mesh_path: String = ""
## Imagen que se ve en la pieza (ruta de ImageImporter).
@export var texture_path: String = ""
@export var material_path: String = ""
@export var scale_factor: float = 1.0
@export var color_tint: Color = Color.WHITE
@export var billboard: bool = false  # siempre mira a la cámara

# Nodo MeshInstance3D asociado en la escena.
var mesh_node: MeshInstance3D = null

func _serialize_extra(data: Dictionary) -> void:
	data["shape"] = shape
	data["label"] = label
	data["pattern"] = pattern
	data["cells"] = cells
	data["finish"] = finish
	data["mesh_path"] = mesh_path
	data["texture_path"] = texture_path
	data["material_path"] = material_path
	data["scale_factor"] = scale_factor
	data["color_tint"] = color_tint
	data["billboard"] = billboard

func _deserialize_extra(data: Dictionary) -> void:
	shape = PieceShapes.valid(str(data.get("shape", shape)))
	label = str(data.get("label", label)).left(TableRecord.MAX_LABEL)
	pattern = str(data.get("pattern", pattern)) if str(data.get("pattern", pattern)) in PieceShapes.PATTERNS else "liso"
	cells = clampi(int(data.get("cells", cells)), PieceShapes.MIN_CELLS, PieceShapes.MAX_CELLS)
	finish = str(data.get("finish", finish)) if str(data.get("finish", finish)) in PieceShapes.FINISHES else "mate"
	mesh_path = data.get("mesh_path", mesh_path)
	texture_path = data.get("texture_path", texture_path)
	material_path = data.get("material_path", material_path)
	scale_factor = data.get("scale_factor", scale_factor)
	color_tint = data.get("color_tint", color_tint)
	billboard = data.get("billboard", billboard)

# Carga e instancia la malla asignada a mesh_node.
func load_mesh() -> void:
	if mesh_path == "":
		return
	var scene: PackedScene = load(mesh_path)
	if scene == null:
		return
	var instance: Node = scene.instantiate()
	if instance is MeshInstance3D:
		mesh_node = instance
		mesh_node.scale = Vector3.ONE * scale_factor
		if material_path != "":
			var mat: Material = load(material_path)
			if mat is Material:
				mesh_node.material_override = mat
