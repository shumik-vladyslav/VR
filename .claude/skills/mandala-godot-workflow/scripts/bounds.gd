# Габариты (AABB) моделей или сцен в мировых координатах Godot.
# Запуск: godot_console.exe --headless --path <проект> -s <этот файл> -- res://a.tscn res://b.glb ...
extends SceneTree

func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_aabb(c, t, acc)

func _init():
	for p in OS.get_cmdline_user_args():
		var inst: Node = load(p).instantiate()
		var acc := [null]
		_aabb(inst, Transform3D.IDENTITY, acc)
		var a: AABB = acc[0]
		print("BOUNDS ", p, " min=", a.position, " max=", a.end, " center=", a.get_center(), " size=", a.size)
		inst.free()
	quit()
