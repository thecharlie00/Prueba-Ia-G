class_name IslandBoard
extends RefCounted

const RESOURCE_NAMES := ["Madera", "Ladrillo", "Lana", "Trigo", "Mineral"]
const DESERT := -1
const DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, -1)
]
const CORNERS := [
	Vector2i(1, 1),
	Vector2i(0, 2),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
	Vector2i(0, -2),
	Vector2i(1, -1)
]

var tiles: Array[Dictionary] = []
var vertices: Array[Vector2i] = []
var edges: Array[Vector2i] = []
var vertex_tiles: Array = []
var vertex_edges: Array = []
var tile_by_coord: Dictionary = {}
# resource -1 denotes a generic 3:1 port; 0..4 denote specialist 2:1 ports.
var ports: Array[Dictionary] = []


func _init(seed_value: int = -1) -> void:
	_build_topology()
	_assign_terrain(seed_value)


func _build_topology() -> void:
	var vertex_ids := {}
	var edge_ids := {}
	for r in range(-2, 3):
		for q in range(-2, 3):
			if absi(q + r) > 2:
				continue
			var coord := Vector2i(q, r)
			var tile_id := tiles.size()
			tile_by_coord[coord] = tile_id
			var corner_ids: Array[int] = []
			for corner: Vector2i in CORNERS:
				var point := Vector2i(2 * q + r, 3 * r) + corner
				if not vertex_ids.has(point):
					vertex_ids[point] = vertices.size()
					vertices.append(point)
					vertex_tiles.append([])
					vertex_edges.append([])
				var id: int = vertex_ids[point]
				corner_ids.append(id)
				vertex_tiles[id].append(tile_id)
			var tile_edges: Array[int] = []
			for i in range(6):
				var a := corner_ids[i]
				var b := corner_ids[(i + 1) % 6]
				var pair := Vector2i(mini(a, b), maxi(a, b))
				if not edge_ids.has(pair):
					edge_ids[pair] = edges.size()
					edges.append(pair)
					vertex_edges[a].append(edge_ids[pair])
					vertex_edges[b].append(edge_ids[pair])
				tile_edges.append(edge_ids[pair])
			tiles.append(
				{
					"coord": coord,
					"vertices": corner_ids,
					"edges": tile_edges,
					"terrain": DESERT,
					"number": 0
				}
			)


func _assign_terrain(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var terrain: Array[int] = [0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, DESERT]
	_shuffle(terrain, rng)
	for i in range(tiles.size()):
		tiles[i]["terrain"] = terrain[i]
	var values: Array[int] = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]
	# Ubicar primero los cuatro números rojos en hexágonos no adyacentes.
	var candidates: Array[int] = []
	for i in range(tiles.size()):
		if terrain[i] != DESERT:
			candidates.append(i)
	_shuffle(candidates, rng)
	var red: Array[int] = []
	_find_non_adjacent(candidates, 0, red)
	var others: Array[int] = []
	for n in values:
		if n not in [6, 8]:
			others.append(n)
	_shuffle(others, rng)
	_shuffle(red, rng)
	for i in range(4):
		tiles[red[i]]["number"] = 6 if i < 2 else 8
	for i in candidates:
		if i not in red:
			tiles[i]["number"] = others.pop_back()
	_assign_ports(rng)


func _assign_ports(rng: RandomNumberGenerator) -> void:
	var use_count: Array[int] = []
	use_count.resize(edges.size())
	use_count.fill(0)
	for tile in tiles:
		for edge in tile["edges"]:
			use_count[edge] += 1
	var boundary: Array[int] = []
	for i in range(edges.size()):
		if use_count[i] == 1:
			boundary.append(i)
	# Follow the actual coastal cycle, not the arbitrary ID order.
	var ordered: Array[int] = [boundary[0]]
	var start: Vector2i = edges[boundary[0]]
	var vertex := start.y
	while ordered.size() < boundary.size():
		var next := -1
		for edge_id in vertex_edges[vertex]:
			if edge_id in boundary and edge_id not in ordered:
				next = edge_id
				break
		if next < 0:
			break
		ordered.append(next)
		var pair: Vector2i = edges[next]
		vertex = pair.y if pair.x == vertex else pair.x
	var types: Array[int] = [-1, -1, -1, -1, 0, 1, 2, 3, 4]
	_shuffle(types, rng)
	var offset := rng.randi_range(0, 29)
	for i in range(9):
		var edge_id := ordered[(offset + (i * 30) / 9) % 30]
		ports.append({"edge": edge_id, "resource": types[i]})


func _find_non_adjacent(candidates: Array[int], start: int, selected: Array[int]) -> bool:
	if selected.size() == 4:
		return true
	for i in range(start, candidates.size()):
		var id := candidates[i]
		var suitable := true
		for other in selected:
			if are_neighbors(id, other):
				suitable = false
				break
		if suitable:
			selected.append(id)
			if _find_non_adjacent(candidates, i + 1, selected):
				return true
			selected.pop_back()
	return false


func are_neighbors(a: int, b: int) -> bool:
	var ca: Vector2i = tiles[a]["coord"]
	var cb: Vector2i = tiles[b]["coord"]
	return cb - ca in DIRECTIONS


func _shuffle(array: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value := array[i]
		array[i] = array[j]
		array[j] = value
