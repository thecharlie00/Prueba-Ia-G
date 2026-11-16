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
## Imagen del reverso (cartas, losetas): se ve al voltear la pieza.
@export var back_path: String = ""
## Descripción para los jugadores: se ve al pasar el ratón por la pieza.
@export var notes: String = ""
## Zonas: al empezar a probar, se mezclan las piezas que hay dentro.
@export var shuffle_on_play: bool = false
## Zonas: normal, mano u oculta (PieceShapes.ZONE_KINDS).
@export var zone_kind: String = "normal"
## Modelos 3D: tamaño del modelo ya encajado (a escala 1). La ruta va en mesh_path.
@export var model_size: Vector3 = Vector3.ZERO
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
	data["back_path"] = back_path
	data["notes"] = notes
	data["shuffle_on_play"] = shuffle_on_play
	data["zone_kind"] = zone_kind
	data["model_size"] = model_size
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
	back_path = str(data.get("back_path", back_path))
	notes = str(data.get("notes", notes)).left(TableRecord.MAX_NOTES)
	shuffle_on_play = data.get("shuffle_on_play", shuffle_on_play) == true
	zone_kind = str(data.get("zone_kind", zone_kind)) if str(data.get("zone_kind", zone_kind)) in PieceShapes.ZONE_KINDS else "normal"
	model_size = data.get("model_size", model_size) if data.get("model_size", model_size) is Vector3 else Vector3.ZERO
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
