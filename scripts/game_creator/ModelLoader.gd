# ModelLoader.gd
# Modelos 3D para las piezas del editor: .glb (glTF en un solo archivo, con sus materiales)
# y .obj (geometría; se pinta con el color o la imagen de la pieza). TTS sólo acepta OBJ;
# aquí valen los dos, se copian a la carpeta del juego y viajan dentro del .tablerama.
class_name ModelLoader
extends RefCounted

const FOLDER := "user://creador/modelos/"
const EXTENSIONS := ["glb", "obj"]
const MAX_BYTES := 24 * 1024 * 1024
## Lado mayor del modelo al ponerlo en la mesa (a escala 1).
const FIT := 0.5

static var _cache := {}


static func supported(path: String) -> bool:
	return path.get_extension().to_lower() in EXTENSIONS


## Copia un modelo a la carpeta del juego. {"path"} o {"error"}.
static func import_model(source: String) -> Dictionary:
	if not supported(source):
		return {"error": "Sólo modelos .glb u .obj."}
	if not FileAccess.file_exists(source):
		return {"error": "No se encuentra el archivo."}
	var bytes := FileAccess.get_file_as_bytes(source)
	if bytes.is_empty() or bytes.size() > MAX_BYTES:
		return {"error": "El modelo está vacío o pasa de 24 MB."}
	return save_bytes(bytes, source.get_file())


static func save_bytes(bytes: PackedByteArray, file_name: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var ext := file_name.get_extension().to_lower()
	if not ext in EXTENSIONS:
		return {"error": "Sólo modelos .glb u .obj."}
	var base := file_name.get_basename().validate_filename().left(60)
	var dest := FOLDER + base + "." + ext
	var i := 1
	while FileAccess.file_exists(dest):
		dest = FOLDER + base + str(i) + "." + ext
		i += 1
	var file := FileAccess.open(dest, FileAccess.WRITE)
	if file == null:
		return {"error": "No se pudo guardar el modelo."}
	file.store_buffer(bytes)
	file.close()
	var size := model_size(dest)
	if size == Vector3.ZERO:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dest))
		return {"error": "El archivo no tiene un modelo que se pueda leer."}
	return {"path": dest, "size": size}


## Tamaño encajado del modelo (Vector3.ZERO si no se puede leer), sin crear nodos.
static func model_size(path: String) -> Vector3:
	return _ensure(path).get("size", Vector3.ZERO)


## {"node": Node3D nuevo con el modelo ya encajado (base en y = 0, centrado, lado mayor FIT),
##  "size": tamaño encajado} o {} si no se puede leer.
static func load_model(path: String) -> Dictionary:
	var cached := _ensure(path)
	if cached.is_empty():
		return {}
	return {"node": (cached["scene"] as PackedScene).instantiate(), "size": cached["size"]}


static func _ensure(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	if not _cache.has(path):
		var source: Node3D = _read(path)
		if source == null:
			return {}
		var box := _bounds(source, Transform3D.IDENTITY)
		if box.size.length() < 0.00001:
			source.free()
			return {}
		var k := FIT / maxf(box.size.x, maxf(box.size.y, box.size.z))
		var holder := Node3D.new()
		holder.name = "Model"
		holder.add_child(source)
		source.transform = Transform3D(Basis.from_scale(Vector3.ONE * k), -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k)
		# Se guarda empaquetado (un recurso), no como nodos sueltos.
		_own(source, holder)
		var packed := PackedScene.new()
		packed.pack(holder)
		holder.free()
		_cache[path] = {"scene": packed, "size": box.size * k}
	return _cache[path]


static func _own(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_own(child, owner)


static func _read(path: String) -> Node3D:
	match path.get_extension().to_lower():
		"glb":
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			if document.append_from_file(path, state) != OK:
				return null
			return document.generate_scene(state) as Node3D
		"obj":
			var mesh := parse_obj(FileAccess.get_file_as_string(path))
			if mesh == null:
				return null
			var instance := MeshInstance3D.new()
			instance.name = "ObjMesh"
			instance.mesh = mesh
			return instance
	return null


## Lee un OBJ (v, vt, vn y caras de 3 o más vértices, índices negativos incluidos).
static func parse_obj(text: String) -> ArrayMesh:
	var positions: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var normals: Array[Vector3] = []
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := 0
	var has_normals := true
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("v "):
			var p := line.substr(2).split(" ", false)
			if p.size() >= 3:
				positions.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
		elif line.begins_with("vt "):
			var t := line.substr(3).split(" ", false)
			if t.size() >= 2:
				uvs.append(Vector2(float(t[0]), 1.0 - float(t[1])))
		elif line.begins_with("vn "):
			var n := line.substr(3).split(" ", false)
			if n.size() >= 3:
				normals.append(Vector3(float(n[0]), float(n[1]), float(n[2])))
		elif line.begins_with("f "):
			var corners: Array = []
			for part in line.substr(2).split(" ", false):
				var idx := part.split("/")
				var vi := _index(idx[0], positions.size())
				if vi < 0:
					return null
				var ti := _index(idx[1], uvs.size()) if idx.size() > 1 and idx[1] != "" else -1
				var ni := _index(idx[2], normals.size()) if idx.size() > 2 and idx[2] != "" else -1
				if ni < 0:
					has_normals = false
				corners.append([vi, ti, ni])
			# Abanico de triángulos; Godot usa el orden de vértices inverso al de OBJ.
			for k in range(1, corners.size() - 1):
				for corner in [corners[0], corners[k + 1], corners[k]]:
					if corner[1] >= 0:
						tool.set_uv(uvs[corner[1]])
					if corner[2] >= 0:
						tool.set_normal(normals[corner[2]])
					tool.add_vertex(positions[corner[0]])
				faces += 1
				if faces > 500000:
					return null
	if faces == 0:
		return null
	if not has_normals:
		tool.generate_normals()
	return tool.commit()


static func _index(value: String, count: int) -> int:
	if not value.is_valid_int():
		return -1
	var i := int(value)
	i = i - 1 if i > 0 else count + i
	return i if i >= 0 and i < count else -1


static func _bounds(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var here := xform * (node as Node3D).transform if node is Node3D else xform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = here * (node as MeshInstance3D).mesh.get_aabb()
		first = false
	for child in node.get_children():
		var inner := _bounds(child, here)
		if inner.size == Vector3.ZERO and inner.position == Vector3.ZERO:
			continue
		box = inner if first else box.merge(inner)
		first = false
	return box
