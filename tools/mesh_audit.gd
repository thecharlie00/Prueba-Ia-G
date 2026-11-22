extends SceneTree
## Auditoría de mallas de una pantalla: cuántos triángulos y dibujos aporta cada tipo de
## malla (contando el contorno de ToonStyle, que la vuelve a dibujar), las sombras y las
## mallas repetidas que se podrían compartir o juntar.
## Uso: godot --headless --path . --script res://tools/mesh_audit.gd -- res://scenes/Home.tscn

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://scenes/Home.tscn"
	change_scene_to_file(path)
	for i in 30:
		await process_frame
	var groups := {}
	var total_tris := 0
	var total_draws := 0
	var shadow_casters := 0
	var unique_meshes := {}
	var unique_materials := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var tris := 0
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			tris += (index.size() / 3) if index != null and index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		var material := mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(0)
		var passes := 1
		if material != null and material.next_pass != null:
			passes = 2
		unique_meshes[mi.mesh.get_rid()] = true
		if material != null:
			unique_materials[material.get_rid()] = true
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow_casters += 1
		var key := "%s (%s)" % [mi.mesh.get_class(), str(mi.get_parent().name).left(18)]
		if not groups.has(key):
			groups[key] = {"count": 0, "tris": 0, "draws": 0}
		groups[key]["count"] += 1
		groups[key]["tris"] += tris * passes
		groups[key]["draws"] += passes
		total_tris += tris * passes
		total_draws += passes
	var keys := groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return groups[a]["tris"] > groups[b]["tris"])
	print("total: %d triángulos, %d dibujos, %d mallas distintas, %d materiales distintos, %d proyectan sombra" % [total_tris, total_draws, unique_meshes.size(), unique_materials.size(), shadow_casters])
	for key in keys.slice(0, 25):
		print("  %-48s x%-4d %8d tri  %4d dibujos" % [key, groups[key]["count"], groups[key]["tris"], groups[key]["draws"]])
	quit()
