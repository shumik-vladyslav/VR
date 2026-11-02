extends RefCounted
## Убирает из меша отдельные куски геометрии (связные части) — чтобы из шестирукого трёхголового Даттатрейи
## получить божество медитации без атрибутов: одна голова, две руки. Модель не меняется — строится новый меш
## с теми же материалами.
## После импорта меш разрезан по швам UV и жёстким рёбрам, а соседние части (руки, торс, головы) касаются
## друг друга вершинами. Поэтому части собираются так: по общим вершинам и совпадающим позиции+нормали
## (это склеивает швы UV, но не соседние части), а мелкие осколки (жёсткие рёбра) прикрепляются к крупной
## части, которой касаются.

const BIG_PART := 60   # вершин — меньше считается осколком

## mi — меш; to_model — перевод из координат меша в координаты модели Даттатрейи;
## keep — Callable(center: Vector3, aabb: AABB) -> bool: оставить ли часть;
## keep_inside — Callable(p: Vector3) -> bool (необязательно): у убранных частей всё же оставить треугольники,
## все вершины которых внутри этой области (например, корень руки в плече — иначе в плече дыра)
## cut — Callable(p: Vector3, aabb: AABB) -> bool (необязательно): у оставленных частей убрать треугольники, хотя бы
## одна вершина которых в этой области (обрывки, торчавшие на месте убранных рук); aabb — габариты всей части
static func strip(mi: MeshInstance3D, to_model: Transform3D, keep: Callable, keep_inside := Callable(), cut := Callable()) -> void:
	var src := mi.mesh
	if src == null:
		return
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx = PackedInt32Array(range(verts.size()))
		# 1) части: общие вершины треугольников + одинаковые позиция и нормаль (швы UV)
		var parent := PackedInt32Array(range(verts.size()))
		var by_pn := {}
		for i in verts.size():
			var key := [verts[i], norms[i]] if norms.size() == verts.size() else [verts[i]]
			if by_pn.has(key):
				_union(parent, i, by_pn[key])
			else:
				by_pn[key] = i
		for t in range(0, idx.size(), 3):
			_union(parent, idx[t], idx[t + 1])
			_union(parent, idx[t], idx[t + 2])
		var size := {}
		for i in verts.size():
			var r := _find(parent, i)
			size[r] = size.get(r, 0) + 1
		# 2) осколки — к крупной части, которой они касаются (по позиции вершины); несколько проходов — по цепочке
		var group := {}       # корень части -> корень крупной части, к которой она относится
		var at_pos := {}      # позиция -> крупная часть
		for i in verts.size():
			var r := _find(parent, i)
			if size[r] >= BIG_PART:
				group[r] = r
				at_pos[verts[i]] = r
		for _pass in 4:
			for i in verts.size():
				var r := _find(parent, i)
				if not group.has(r) and at_pos.has(verts[i]):
					group[r] = at_pos[verts[i]]
			for i in verts.size():
				var r := _find(parent, i)
				if group.has(r) and not at_pos.has(verts[i]):
					at_pos[verts[i]] = group[r]
		# 3) габариты каждой группы в координатах модели и решение — оставить ли
		var boxes := {}
		for i in verts.size():
			var r := _find(parent, i)
			var gid: int = group.get(r, r)
			var p := to_model * verts[i]
			if boxes.has(gid):
				boxes[gid] = (boxes[gid] as AABB).expand(p)
			else:
				boxes[gid] = AABB(p, Vector3.ZERO)
		var keep_group := {}
		var debug := OS.has_environment("STRIP_DEBUG")
		var gsize := {}
		if debug:
			for i in verts.size():
				var r := _find(parent, i)
				var gid: int = group.get(r, r)
				gsize[gid] = gsize.get(gid, 0) + 1
		for gid in boxes:
			var b: AABB = boxes[gid]
			keep_group[gid] = keep.call(b.get_center(), b)
			# для проверки: STRIP_TEST_DROP="0.15,1.62;-0.82,1.64" — убрать части, у которых угол габаритов (x,y) такой
			for pair in OS.get_environment("STRIP_TEST_DROP").split(";", false):
				var test := pair.split_floats(",")
				if test.size() == 2 and absf(b.position.x - test[0]) < 0.006 and absf(b.position.y - test[1]) < 0.006:
					keep_group[gid] = false
			# для проверки: STRIP_DEBUG=1 — какие части остаются/убираются
			if debug and gsize[gid] >= 20:
				print("STRIP %s %s n=%d x[%.2f %.2f] y[%.2f %.2f] z[%.2f %.2f]" % [mi.name, "keep" if keep_group[gid] else "DROP",
					gsize[gid], b.position.x, b.end.x, b.position.y, b.end.y, b.position.z, b.end.z])
		var new_idx := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var r := _find(parent, idx[t])
			var gid: int = group.get(r, r)
			var kept: bool = keep_group[gid]
			if not kept and keep_inside.is_valid():
				kept = keep_inside.call(to_model * verts[idx[t]]) and keep_inside.call(to_model * verts[idx[t + 1]]) \
					and keep_inside.call(to_model * verts[idx[t + 2]])
			elif kept and cut.is_valid():
				var b: AABB = boxes[gid]
				kept = not (cut.call(to_model * verts[idx[t]], b) or cut.call(to_model * verts[idx[t + 1]], b) \
					or cut.call(to_model * verts[idx[t + 2]], b))
			if kept:
				new_idx.append(idx[t]); new_idx.append(idx[t + 1]); new_idx.append(idx[t + 2])
		if new_idx.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = new_idx
		# для проверки: STRIP_COLOR=1 — раскрасить оставленные части в разные цвета (номер цвета печатается)
		var debug_mat: Material
		if OS.has_environment("STRIP_COLOR"):
			var palette := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color.ORANGE,
				Color.WHITE, Color.BLACK, Color.PURPLE, Color.LIME, Color.BROWN]
			var color_of := {}
			for gid in boxes:
				if keep_group[gid]:
					color_of[gid] = color_of.size() % palette.size()
					var b: AABB = boxes[gid]
					print("COLOR %s %d x[%.2f %.2f] y[%.2f %.2f] z[%.2f %.2f]" % [mi.name, color_of[gid],
						b.position.x, b.end.x, b.position.y, b.end.y, b.position.z, b.end.z])
			var cols := PackedColorArray()
			cols.resize(verts.size())
			for i in verts.size():
				var r := _find(parent, i)
				cols[i] = palette[color_of.get(group.get(r, r), 0)]
			arrays[Mesh.ARRAY_COLOR] = cols
			var dm := StandardMaterial3D.new()
			dm.vertex_color_use_as_albedo = true
			debug_mat = dm
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, debug_mat if debug_mat else src.surface_get_material(s))
	# материалы, назначенные на сам MeshInstance3D, остаются на нём
	mi.mesh = out

static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb
