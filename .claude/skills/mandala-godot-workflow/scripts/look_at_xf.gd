# Печатает строку transform = Transform3D(...) для узла в позиции FROM, смотрящего на TO,
# в формате .tscn (базис построчно: x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z, затем origin).
# Запуск: godot_console.exe --headless -s <этот файл> -- "x,y,z" "x,y,z" [ещё пары...]
extends SceneTree

func _init():
	var a := OS.get_cmdline_user_args()
	for i in range(0, a.size() - 1, 2):
		var f := a[i].split_floats(",")
		var to := a[i + 1].split_floats(",")
		var t := Transform3D(Basis(), Vector3(f[0], f[1], f[2])).looking_at(Vector3(to[0], to[1], to[2]), Vector3.UP)
		var b := t.basis
		var nums := [b.x.x, b.y.x, b.z.x, b.x.y, b.y.y, b.z.y, b.x.z, b.y.z, b.z.z, t.origin.x, t.origin.y, t.origin.z]
		print("XF transform = Transform3D(", ", ".join(nums.map(func(v): return str(snappedf(v, 0.000001)))), ")")
	quit()
