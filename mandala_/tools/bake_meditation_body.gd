extends SceneTree
## Готовит меши божества медитации (transformation.gd, BODY_CACHE): собирает тело из частей Даттатрейи заново
## и сохраняет изменённые меши. Запуск после любой правки модели или правил сборки тела:
##   Godot --headless --path mandala_ -s res://tools/bake_meditation_body.gd
const Transformation := preload("res://src/practice/transformation.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(Transformation.BODY_CACHE)
	var scene: Node = load("res://teurgia1.tscn").instantiate()
	var saved := 0
	for part in scene.get_node("Gods/Datta").get_children():
		if not (part is Node3D) or part.name == "CameraOrigin":
			continue
		var copy := part.duplicate() as Node3D
		var before := {}
		for m in copy.find_children("*", "MeshInstance3D", true, false):
			before[m] = (m as MeshInstance3D).mesh
		Transformation.make_meditation_body(copy, false)
		for m in before:
			var mi := m as MeshInstance3D
			if mi.is_queued_for_deletion() or mi.mesh == before[m]:
				continue
			var path := Transformation.cached_mesh_path(copy, mi)
			var err := ResourceSaver.save(mi.mesh, path, ResourceSaver.FLAG_COMPRESS)
			print("BAKE %s %s %s" % [path.get_file(), mi.mesh.get_surface_count(), error_string(err)])
			saved += 1
		copy.free()
	scene.free()
	print("BAKE done, meshes: %d" % saved)
	quit()
