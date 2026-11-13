# VisualComponent.gd
# Apariencia 3D de una entidad: malla, material, escala y tinte de color.
class_name VisualComponent
extends BehaviorComponent

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
	data["mesh_path"] = mesh_path
	data["texture_path"] = texture_path
	data["material_path"] = material_path
	data["scale_factor"] = scale_factor
	data["color_tint"] = color_tint
	data["billboard"] = billboard

func _deserialize_extra(data: Dictionary) -> void:
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
