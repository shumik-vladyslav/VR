extends RefCounted
## Предметы манасика-пуджи (offering.gd): плоды, горы плодов на золотых подносах, большая многоярусная лампада,
## пучок благовонных палочек с дымом, кувшин с водой. Всё строится из простых форм в коде.
## Размеры — в метрах «человеческого» масштаба; столы и Даттатрейя в сцене крупнее (масштаб задаёт offering.gd).

const FLAME_SHADER := preload("res://src/practice/flame.gdshader")

enum Fruit { ORANGE, APPLE, GREEN_APPLE, MANGO, POMEGRANATE, BANANAS, GRAPES, COCONUT }

static var _meshes := {}
static var _mats := {}

static func _mat(key: String, color: Color, roughness := 0.5, emission := Color.BLACK) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic_specular = 0.35
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
	_mats[key] = m
	return m

static func _sphere(key: String, radius: float, segments := 16) -> SphereMesh:
	if _meshes.has(key):
		return _meshes[key]
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = segments / 2
	_meshes[key] = s
	return s

static func _mi(mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.scale = scl
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

## Один плод (или гроздь/связка), основание — в начале координат узла, размер ~0.07–0.1 м
static func make_fruit(kind: int, rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	match kind:
		Fruit.ORANGE:
			n.add_child(_mi(_sphere("orange", 0.04), _mat("orange", Color(1.0, 0.45, 0.04), 0.6), Vector3(0, 0.04, 0)))
			n.add_child(_mi(_sphere("dot", 0.006, 6), _mat("leaf", Color(0.2, 0.4, 0.08), 0.7), Vector3(0, 0.08, 0)))
		Fruit.APPLE, Fruit.GREEN_APPLE:
			var col := Color(0.72, 0.04, 0.05) if kind == Fruit.APPLE else Color(0.6, 0.8, 0.2)
			n.add_child(_mi(_sphere("apple", 0.04), _mat("apple%d" % kind, col, 0.3), Vector3(0, 0.035, 0), Vector3(1.0, 0.88, 1.0)))
			n.add_child(_mi(_cylinder("stem", 0.002, 0.018), _mat("stem", Color(0.3, 0.18, 0.08), 0.8), Vector3(0, 0.073, 0)))
		Fruit.MANGO:
			n.add_child(_mi(_sphere("mango", 0.04), _mat("mango", Color(1.0, 0.62, 0.08), 0.45), Vector3(0, 0.035, 0), Vector3(0.85, 0.85, 1.3)))
		Fruit.POMEGRANATE:
			n.add_child(_mi(_sphere("pomegranate", 0.043), _mat("pomegranate", Color(0.55, 0.03, 0.07), 0.4), Vector3(0, 0.042, 0)))
			n.add_child(_mi(_cylinder("crown", 0.009, 0.014), _mat("pomegranate", Color(0.55, 0.03, 0.07), 0.4), Vector3(0, 0.088, 0)))
		Fruit.COCONUT:
			n.add_child(_mi(_sphere("coconut", 0.055), _mat("coconut", Color(0.38, 0.22, 0.1), 0.95), Vector3(0, 0.05, 0), Vector3(1.0, 0.92, 1.0)))
		Fruit.GRAPES:
			var col := Color(0.32, 0.08, 0.32) if rng.randf() < 0.6 else Color(0.6, 0.78, 0.25)
			var gm := _mat("grape%d" % int(col.g * 10), col, 0.25)
			for i in 16:
				var layer := i / 5
				var r := 0.022 * (1.0 - layer * 0.25)
				var a := TAU * float(i % 5) / 5.0 + layer * 0.6
				n.add_child(_mi(_sphere("grape", 0.012, 8), gm, Vector3(cos(a) * r, 0.06 - layer * 0.016, sin(a) * r)))
		Fruit.BANANAS:
			var bm := _banana_mesh()
			for i in 4:
				var b := _mi(bm, _mat("banana", Color(0.98, 0.82, 0.18), 0.5))
				b.position = Vector3((i - 1.5) * 0.017, 0.012, 0.0)
				b.rotation = Vector3(0.0, (i - 1.5) * 0.12, 0.0)
				n.add_child(b)
	return n

static func _cylinder(key: String, radius: float, height: float) -> CylinderMesh:
	if _meshes.has(key):
		return _meshes[key]
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 8
	c.rings = 1
	_meshes[key] = c
	return c

## Банан: изогнутая трубка, сужается к концам
static func _banana_mesh() -> ArrayMesh:
	if _meshes.has("banana"):
		return _meshes["banana"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 14
	var nv := 8
	var pts: Array = []
	for i in nu + 1:
		var u := float(i) / nu
		var ang := lerpf(-0.6, 0.6, u)
		var c := Vector3(0.0, 0.12 - cos(ang) * 0.12, sin(ang) * 0.12)       # дуга
		var tangent := Vector3(0.0, sin(ang), cos(ang))
		var r := 0.013 * pow(sin(PI * clampf(u * 0.92 + 0.04, 0.0, 1.0)), 0.6)
		var ring: Array = []
		for j in nv:
			var a := TAU * float(j) / nv
			var side := Vector3.RIGHT * cos(a) + tangent.cross(Vector3.RIGHT).normalized() * sin(a)
			ring.append(c + side * r)
		pts.append(ring)
	for i in nu:
		for j in nv:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % nv]
			var c2: Vector3 = pts[i + 1][j]
			var d: Vector3 = pts[i + 1][(j + 1) % nv]
			for v in [a, c2, b, b, c2, d]:
				st.add_vertex(v)
	st.generate_normals()
	var m := st.commit()
	_meshes["banana"] = m
	return m

## Горка плодов: radius — радиус основания, height — высота, scale — размер плодов
static func make_fruit_mound(rng: RandomNumberGenerator, radius: float, height: float, count: int, scale: float) -> Node3D:
	var n := Node3D.new()
	var kinds := [Fruit.ORANGE, Fruit.APPLE, Fruit.MANGO, Fruit.POMEGRANATE, Fruit.GREEN_APPLE, Fruit.GRAPES, Fruit.ORANGE, Fruit.APPLE]
	# снизу вверх: по слоям, к вершине слои уже
	var placed := 0
	var layer := 0
	var step := 0.075 * scale
	while placed < count:
		var y := layer * step * 0.8
		if y > height:
			break
		var r_layer := radius * (1.0 - y / (height + step))
		for ring_r in [r_layer, r_layer * 0.55, 0.0]:
			var nr := maxi(1, int(TAU * ring_r / step)) if ring_r > 0.0 else 1
			for i in nr:
				if placed >= count:
					break
				var a := TAU * float(i) / nr + rng.randf() * 0.5 + layer
				var f := make_fruit(kinds[rng.randi() % kinds.size()], rng)
				f.position = Vector3(cos(a) * ring_r, y, sin(a) * ring_r) + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * step * 0.15
				f.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
				f.scale = Vector3.ONE * scale * rng.randf_range(0.9, 1.1)
				n.add_child(f)
				placed += 1
			if ring_r == 0.0:
				break
		layer += 1
	return n

## Золотой поднос на низкой ножке с горой плодов (вокруг Даттатрейи), radius — радиус подноса
static func make_fruit_tray(rng: RandomNumberGenerator, gold: Material, radius: float, fruit_scale: float, count: int) -> Node3D:
	var n := Node3D.new()
	var r := radius
	lathe(n, [
		Vector2(0.0, 0.0), Vector2(r * 0.42, 0.0), Vector2(r * 0.45, 0.02 * r), Vector2(r * 0.3, 0.08 * r), Vector2(r * 0.16, 0.14 * r),
		Vector2(r * 0.14, 0.3 * r), Vector2(r * 0.22, 0.36 * r), Vector2(r * 0.6, 0.4 * r), Vector2(r * 0.95, 0.46 * r),
		Vector2(r, 0.5 * r), Vector2(r * 0.96, 0.52 * r), Vector2(r * 0.8, 0.47 * r), Vector2(0.0, 0.45 * r),
	], gold, 48)
	var mound := make_fruit_mound(rng, r * 0.85, r * 1.15, count, fruit_scale)
	mound.position.y = 0.46 * r
	n.add_child(mound)
	return n

## Большая многоярусная лампада (как на аарти): ножка, три яруса чашечек-светильников с огоньками
static func make_lamp(gold: Material) -> Node3D:
	var n := Node3D.new()
	lathe(n, [
		Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.1, 0.01), Vector2(0.06, 0.03), Vector2(0.025, 0.05), Vector2(0.02, 0.12),
		Vector2(0.035, 0.14), Vector2(0.02, 0.16), Vector2(0.018, 0.3), Vector2(0.03, 0.32), Vector2(0.018, 0.34),
		Vector2(0.016, 0.42), Vector2(0.0, 0.44),
	], gold, 32)
	var cup := _cup_mesh()
	var tiers := [[0.16, 0.2, 12], [0.11, 0.3, 8], [0.06, 0.38, 5]]
	var k := 0
	for tier in tiers:
		var tr: float = tier[0]
		var ty: float = tier[1]
		# кольцо-ярус
		var ring := TorusMesh.new()
		ring.inner_radius = tr - 0.006
		ring.outer_radius = tr + 0.006
		ring.rings = 32
		ring.ring_segments = 8
		n.add_child(_mi(ring, gold, Vector3(0, ty, 0)))
		for i in tier[2]:
			var a: float = TAU * float(i) / float(tier[2])
			var p := Vector3(cos(a) * tr, ty, sin(a) * tr)
			n.add_child(_mi(cup, gold, p))
			n.add_child(_flame(p + Vector3(0, 0.03, 0), 0.05, k))
			k += 1
	n.add_child(_mi(cup, gold, Vector3(0, 0.44, 0)))
	n.add_child(_flame(Vector3(0, 0.47, 0), 0.06, k))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 1.8
	light.omni_range = 1.5
	light.light_specular = 0.0
	light.position = Vector3(0, 0.36, 0)
	n.add_child(light)
	return n

static func _cup_mesh() -> ArrayMesh:
	if _meshes.has("cup"):
		return _meshes["cup"]
	var holder := Node3D.new()
	lathe(holder, [Vector2(0.008, -0.004), Vector2(0.018, 0.0), Vector2(0.022, 0.012), Vector2(0.019, 0.014), Vector2(0.0, 0.008)], null, 16)
	var m: ArrayMesh = (holder.get_child(0) as MeshInstance3D).mesh
	holder.free()
	_meshes["cup"] = m
	return m

static func _flame(at: Vector3, size: float, seed: int) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size * 1.7)
	q.center_offset = Vector3(0, size * 0.7, 0)
	var mat := ShaderMaterial.new()
	mat.shader = FLAME_SHADER
	var m := _mi(q, mat, at)
	mat.set_shader_parameter("seed", fmod(float(seed) * 0.618, 1.0))
	return m

## Пучок благовонных палочек в золотой чашечке; тлеющие кончики и дым (частицы остаются в мире — тянутся шлейфом)
static func make_incense(gold: Material, rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	lathe(n, [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.055, 0.01), Vector2(0.045, 0.02), Vector2(0.03, 0.03), Vector2(0.045, 0.07),
		Vector2(0.06, 0.09), Vector2(0.056, 0.095), Vector2(0.0, 0.085)], gold, 32)
	var stick := _cylinder("stick", 0.0025, 0.3)
	var stick_mat := _mat("stick", Color(0.35, 0.12, 0.08), 0.9)
	var tip := _sphere("tip", 0.004, 6)
	var tip_mat := _mat("tip", Color(1.0, 0.35, 0.05), 0.5, Color(1.0, 0.3, 0.02))
	var tips: Array[Vector3] = []
	for i in 21:
		var a := rng.randf() * TAU
		var tilt := rng.randf_range(0.05, 0.35)
		var dir := Vector3(sin(tilt) * cos(a), cos(tilt), sin(tilt) * sin(a))
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.02) + Vector3(0, 0.08, 0)
		var s := _mi(stick, stick_mat)
		s.transform = Transform3D(_basis_y(dir), base + dir * 0.15)
		n.add_child(s)
		var t := base + dir * 0.3
		n.add_child(_mi(tip, tip_mat, t))
		tips.append(t)
	var smoke := _smoke()
	smoke.position = Vector3(0, 0.36, 0)
	n.add_child(smoke)
	return n

static func _basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

static func _soft_dot() -> GradientTexture2D:
	if _meshes.has("soft_dot"):
		return _meshes["soft_dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_meshes["soft_dot"] = t
	return t

## Дым благовоний: мягкие светлые клубы поднимаются и растворяются
static func _smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 4.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3(0, 0.04, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var cr := Gradient.new()
	cr.set_color(0, Color(0.95, 0.92, 0.88, 0.0))
	cr.add_point(0.15, Color(0.95, 0.92, 0.88, 0.22))
	cr.set_color(cr.get_point_count() - 1, Color(0.9, 0.9, 0.92, 0.0))
	var crt := GradientTexture1D.new()
	crt.gradient = cr
	pm.color_ramp = crt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	m.disable_receive_shadows = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Золотой кувшин (калаш) с водой
static func make_water_jug(gold: Material) -> Node3D:
	var n := Node3D.new()
	lathe(n, [
		Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.055, 0.008), Vector2(0.045, 0.02), Vector2(0.08, 0.05), Vector2(0.105, 0.09),
		Vector2(0.11, 0.12), Vector2(0.1, 0.16), Vector2(0.07, 0.19), Vector2(0.04, 0.215), Vector2(0.036, 0.235),
		Vector2(0.05, 0.26), Vector2(0.06, 0.27), Vector2(0.056, 0.275), Vector2(0.042, 0.255), Vector2(0.0, 0.25),
	], gold, 40)
	# вода в горлышке
	var water := CylinderMesh.new()
	water.top_radius = 0.04
	water.bottom_radius = 0.04
	water.height = 0.004
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.45, 0.7, 0.95)
	wm.roughness = 0.05
	wm.emission_enabled = true
	wm.emission = Color(0.1, 0.25, 0.4)
	n.add_child(_mi(water, wm, Vector3(0, 0.258, 0)))
	return n

## Струйка воды из носика: светлые капли падают и гаснут; включается, когда кувшин летит
static func _water_drops() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 1.2
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.3, 1)
	pm.spread = 8.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, -2.5, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var cr := Gradient.new()
	cr.set_color(0, Color(0.75, 0.9, 1.0, 0.9))
	cr.set_color(1, Color(0.6, 0.85, 1.0, 0.0))
	var crt := GradientTexture1D.new()
	crt.gradient = cr
	pm.color_ramp = crt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Тело вращения по профилю (x — радиус, y — высота)
static func lathe(parent: Node3D, profile: Array, mat: Material, segments: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for s in segments:
		var a0 := TAU * float(s) / float(segments)
		var a1 := TAU * float(s + 1) / float(segments)
		for j in profile.size() - 1:
			var p0: Vector2 = profile[j]
			var p1: Vector2 = profile[j + 1]
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			for tri in [[v00, v10, v11], [v00, v11, v01]]:
				if (tri[1] - tri[0]).cross(tri[2] - tri[0]).length_squared() < 1e-14:
					continue
				for v in tri:
					st.add_vertex(v)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	if mat:
		m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
