extends Node3D
## Подношение: два золотых стола — с блюдом лепестков и с целыми цветочными головками (роза, бархатец, лотос).
## Подойти к столу и нажать ЛКМ — в руке появляется золотой сосуд, в нём горсть лепестков
## или 20 цветков; ещё раз ЛКМ — поднести: они по очереди летят по дуге к Даттатрейе и растворяются искрами света.
## В VR то же самое будет через контроллер: взять со стола, бросить.

const PETAL_SHADER := preload("res://src/practice/petal.gdshader")
const AURA_SHADER := preload("res://src/practice/aura.gdshader")

## Цвета лепестков на блюде: розы разных оттенков, белые, бархатцы
const PETAL_COLORS := [
	Color(0.78, 0.06, 0.13), Color(0.92, 0.14, 0.22), Color(1.0, 0.42, 0.58), Color(1.0, 0.72, 0.8),
	Color(1.0, 0.97, 0.9), Color(1.0, 0.52, 0.06), Color(1.0, 0.8, 0.12),
]
const WARM_BASE := Color(1.0, 0.92, 0.72)
## Масштаб столов: практикующий в сцене примерно в 1.8 раза крупнее человека (глаза на высоте ~2.9 м)
const SCALE := 1.6
const PLATE_PETALS := 140
const HANDFUL := 40
const FLOWERS_TAKEN := 20
const REACH := 2.8          # с какого расстояния (по горизонтали) можно взять

enum Kind { PETALS, FLOWER }

## Сияние святых после подношения (0..1, затухает) — практика добавляет его к сиянию древа
var glow := 0.0

var _camera: Camera3D
var _target := Vector3.ZERO
var _petal_mat: ShaderMaterial
var _gold: StandardMaterial3D
var _plate_gold: StandardMaterial3D
var _vessel_gold: StandardMaterial3D
## Сетки лепестков: розовые (с выемкой), заострённые (лотос), узкие кружевные (бархатец), чашелистики
var _rose_petals: Array[ArrayMesh] = []
var _lotus_petal: ArrayMesh
var _marigold_petal: ArrayMesh
var _sepal: ArrayMesh
var _stations: Array[Dictionary] = []
var _hand: Node3D
var _vessel: Node3D
var _vessel_petals: Node3D
var _hand_petals: Array[MeshInstance3D] = []
var _hand_flowers: Array[Node3D] = []
var _holding := -1           # что в руке: -1 ничего, иначе Kind
var _flying: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _hand_hint: Label3D
var _rng := RandomNumberGenerator.new()

func setup(camera: Camera3D, petal_table_position: Vector3, flower_stand_position: Vector3, target: Vector3) -> void:
	_camera = camera
	_target = target
	_rng.seed = 108
	_make_materials()

	# Стол с блюдом лепестков — аккуратная горка, лепестки лежат почти плашмя внахлёст
	var petals := _add_station(petal_table_position, Kind.PETALS, "ЛКМ — взять лепестки")
	for i in PLATE_PETALS:
		var r := 0.175 * sqrt(_rng.randf())
		var a := _rng.randf() * TAU
		var h := 0.838 + 0.075 * (1.0 - pow(r / 0.175, 2.0)) * _rng.randf_range(0.55, 1.0)
		var p := _petal(Vector3(cos(a) * r, h, sin(a) * r))
		p.rotation = Vector3(-PI / 2 + _rng.randf_range(-0.28, 0.28), _rng.randf() * TAU, _rng.randf_range(-0.2, 0.2))
		petals.add_child(p)

	# Стойка с цветочными головками: лотос в центре, вокруг два кольца роз, бархатцев и лотосов
	var flowers := _add_station(flower_stand_position, Kind.FLOWER, "ЛКМ — взять 20 цветков")
	var center := _make_lotus()
	center.position = Vector3(0, 0.84, 0)
	flowers.add_child(center)
	for ring in [[7, 0.09, 0.82, 0.86, 0.2], [12, 0.168, 0.8, 0.85, 0.0]]:
		for i in ring[0]:
			var a: float = TAU * float(i) / ring[0] + ring[4]
			var head := _random_flower(i)
			head.position = Vector3(cos(a) * ring[1], ring[3], sin(a) * ring[1])
			head.scale = Vector3.ONE * ring[2] * _rng.randf_range(0.92, 1.05)
			head.rotation = Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf() * TAU, _rng.randf_range(-0.12, 0.12))
			flowers.add_child(head)

	# Рука (в VR — контроллер): золотой сосуд на ножке появляется в ней, только когда что-то взяли
	_hand = Node3D.new()
	_hand.position = Vector3(0.3, -0.36, -0.62)
	camera.add_child(_hand)
	_vessel = Node3D.new()
	_vessel.rotation.x = 0.5             # сосуд наклонён к глазам — видно, что внутри
	_vessel.visible = false              # появляется, только когда что-то взяли
	_hand.add_child(_vessel)
	_lathe(_vessel, [
		Vector2(0.032, -0.05), Vector2(0.036, -0.046), Vector2(0.03, -0.04), Vector2(0.013, -0.032),  # подставка
		Vector2(0.01, -0.02), Vector2(0.014, -0.012), Vector2(0.01, -0.006), Vector2(0.02, 0.0),          # ножка с пояском
		Vector2(0.05, 0.006), Vector2(0.074, 0.02), Vector2(0.086, 0.034), Vector2(0.09, 0.04),          # чаша снаружи
		Vector2(0.087, 0.043), Vector2(0.078, 0.034), Vector2(0.055, 0.018), Vector2(0.0, 0.012),         # и внутри
	], _vessel_gold, 48)
	var rim_bead := SphereMesh.new()
	rim_bead.radius = 0.0035
	rim_bead.height = 0.007
	rim_bead.material = _vessel_gold
	for i in 28:
		var b := MeshInstance3D.new()
		b.mesh = rim_bead
		b.position = Vector3(cos(TAU * i / 28.0) * 0.089, 0.042, sin(TAU * i / 28.0) * 0.089)
		_vessel.add_child(b)
	# горка лепестков в сосуде — показывается, когда взяли лепестки
	_vessel_petals = Node3D.new()
	_vessel_petals.visible = false
	_vessel.add_child(_vessel_petals)
	for i in HANDFUL:
		var r := 0.068 * sqrt(_rng.randf())
		var a := _rng.randf() * TAU
		var h := 0.018 + 0.04 * (1.0 - pow(r / 0.068, 2.0)) * _rng.randf_range(0.5, 1.0)
		var p := _petal(Vector3(cos(a) * r, h, sin(a) * r), 0.6)
		p.rotation = Vector3(-PI / 2 + _rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.2, 0.2))
		_vessel_petals.add_child(p)
		_hand_petals.append(p)

	_hand_hint = _label("", 30)
	_hand_hint.position = Vector3(0, -0.55, -1.2)
	camera.add_child(_hand_hint)

## Нажатие «действие» (ЛКМ / курок контроллера): взять со стола рядом или поднести то, что в руке
func interact() -> void:
	if _holding == Kind.PETALS:
		_offer_petals()
		return
	if _holding == Kind.FLOWER:
		_offer_flower()
		return
	var st := _nearest_station()
	if st.is_empty():
		return
	_holding = st.kind
	_vessel.visible = true
	if st.kind == Kind.PETALS:
		_vessel_petals.visible = true
		_hand_hint.text = "ЛКМ — поднести лепестки"
	else:
		# 20 цветков в сосуде букетом: один в центре, 6 вокруг повыше, 13 по краю наклонены наружу
		for i in FLOWERS_TAKEN:
			var f := _random_flower(i + _rng.randi() % 3)
			var ring := 0 if i == 0 else (1 if i < 7 else 2)
			var a: float = [0.0, TAU * float(i - 1) / 6.0 + 0.3, TAU * float(i - 7) / 13.0][ring]
			var r: float = [0.0, 0.03, 0.064][ring]
			var tilt: float = [0.0, _rng.randf_range(0.15, 0.25), _rng.randf_range(0.4, 0.55)][ring]
			var s: float = [0.32, 0.29, 0.26][ring]
			f.position = Vector3(cos(a) * r, [0.04, 0.03, 0.016][ring], sin(a) * r)
			f.basis = Basis(Vector3(sin(a), 0.0, -cos(a)), tilt) * Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
			_vessel.add_child(f)
			_hand_flowers.append(f)
		_hand_hint.text = "ЛКМ — поднести цветы"

func _nearest_station() -> Dictionary:
	var best := {}
	var best_d := REACH
	for st in _stations:
		var d: Vector3 = _camera.global_position - (st.node as Node3D).global_position
		var dist := Vector2(d.x, d.z).length()
		if dist < best_d:
			best_d = dist
			best = st
	return best

func _random_flower(i: int) -> Node3D:
	match i % 4:
		0, 2:
			return _make_rose(PETAL_COLORS[_rng.randi() % 5])
		1:
			return _make_marigold()
	return _make_lotus()

func _offer_petals() -> void:
	_holding = -1
	_vessel_petals.visible = false
	_vessel.visible = false
	for src in _hand_petals:
		var p := MeshInstance3D.new()
		p.mesh = src.mesh
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for param in ["petal_color", "petal_seed", "base_color"]:
			p.set_instance_shader_parameter(param, src.get_instance_shader_parameter(param))
		get_parent().add_child(p)
		p.global_transform = src.global_transform
		var size: float = SCALE * 0.95 * src.scale.x / 0.6
		_fly(p, size, Vector3(_rng.randf_range(-1.1, 1.1), _rng.randf_range(-0.7, 1.1), _rng.randf_range(-0.4, 0.4)),
			-_rng.randf_range(0.0, 0.7), _rng.randf_range(1.8, 2.7), 5.0, _rng.randf_range(0.08, 0.2), 0.03)

func _offer_flower() -> void:
	_holding = -1
	# цветы по очереди поднимаются из сосуда и летят к Даттатрейе, сосуд исчезает
	_vessel.visible = false
	for i in _hand_flowers.size():
		var f := _hand_flowers[i]
		# в полёте цветы крупнее, чем в сосуде
		var size: float = SCALE * f.scale.x / 0.27
		f.reparent(get_parent(), true)
		_fly(f, size, Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.5, 0.7), 0.3),
			-0.1 * i, _rng.randf_range(2.3, 2.8), 1.2, 0.05, 0.04)
	_hand_flowers.clear()

func _fly(node: Node3D, size: float, spread: Vector3, delay: float, dur: float, spin: float, flutter: float, glow_add: float) -> void:
	node.scale = Vector3.ONE * size
	_flying.append({
		"node": node, "size": size, "from": node.global_position, "to": _target + spread,
		"t": delay, "dur": dur, "arc": _rng.randf_range(0.8, 1.8),
		"spin": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * spin,
		"flutter": flutter, "phase": _rng.randf() * TAU, "glow": glow_add,
	})

func _process(delta: float) -> void:
	glow = maxf(0.0, glow - delta * 0.35)
	if _camera:
		var near := _nearest_station() if _holding < 0 else {}
		for st in _stations:
			var hint: Label3D = st.hint
			hint.modulate.a = move_toward(hint.modulate.a, 1.0 if st == near else 0.0, delta * 3.0)
			hint.outline_modulate.a = hint.modulate.a * 0.6
			hint.visible = hint.modulate.a > 0.01
		_hand_hint.visible = _holding >= 0

	for i in range(_flying.size() - 1, -1, -1):
		var f := _flying[i]
		f.t += delta
		var n: Node3D = f.node
		if f.t < 0.0:
			continue
		var k: float = minf(f.t / f.dur, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var pos: Vector3 = (f.from as Vector3).lerp(f.to, e)
		pos.y += f.arc * 4.0 * k * (1.0 - k)
		# покачивается в воздухе, как настоящий лепесток
		var sway: float = f.flutter * sin(PI * k)
		pos += Vector3(sin(f.t * 5.0 + f.phase), 0.4 * sin(f.t * 7.0 + f.phase), cos(f.t * 4.0 + f.phase)) * sway
		n.global_position = pos
		n.rotation += (f.spin as Vector3) * delta
		# в конце пути растворяется в свете
		var fade := 1.0 - smoothstep(0.82, 1.0, k)
		_set_fade(n, fade)
		n.scale = Vector3.ONE * f.size * (0.4 + 0.6 * fade)
		if k >= 1.0:
			_flash(n.global_position, 0.6 if f.glow < 0.1 else 1.6)
			n.queue_free()
			_flying.remove_at(i)
			glow = minf(1.0, glow + f.glow)

	for i in range(_flashes.size() - 1, -1, -1):
		var fl := _flashes[i]
		fl.t += delta
		var m: MeshInstance3D = fl.node
		var k: float = fl.t / 0.9
		(m.material_override as ShaderMaterial).set_shader_parameter("intensity", 1.6 * (1.0 - k) * smoothstep(0.0, 0.1, k))
		if k >= 1.0:
			m.queue_free()
			_flashes.remove_at(i)

func _set_fade(n: Node, fade: float) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
		(n as MeshInstance3D).set_instance_shader_parameter("petal_fade", fade)
	for c in n.get_children():
		_set_fade(c, fade)

func _flash(at: Vector3, size: float) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = AURA_SHADER
	mat.set_shader_parameter("rays", 1.2)
	mat.set_shader_parameter("color", Color(1.0, 0.85, 0.6))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(m)
	m.global_position = at
	_flashes.append({"node": m, "t": 0.0})

# ---------- лепестки и цветы ----------

func _make_materials() -> void:
	_petal_mat = ShaderMaterial.new()
	_petal_mat.shader = PETAL_SHADER
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(1.0, 0.77, 0.34)
	_gold.metallic = 0.9
	_gold.roughness = 0.36
	_gold.emission_enabled = true
	_gold.emission = Color(0.35, 0.22, 0.05)
	_plate_gold = StandardMaterial3D.new()
	_plate_gold.albedo_color = Color(1.0, 0.84, 0.5)
	_plate_gold.metallic = 0.9
	_plate_gold.roughness = 0.22
	_plate_gold.emission_enabled = true
	_plate_gold.emission = Color(0.4, 0.28, 0.08)
	# сосуд в руке у самых глаз: зеркальное золото отражает небо и «плывёт» цветом — делаем матовым, без отражений
	_vessel_gold = StandardMaterial3D.new()
	_vessel_gold.albedo_color = Color(0.95, 0.72, 0.32)
	_vessel_gold.metallic = 0.0
	_vessel_gold.metallic_specular = 0.0
	_vessel_gold.roughness = 1.0
	_vessel_gold.emission_enabled = true
	_vessel_gold.emission = Color(0.3, 0.19, 0.05)
	_vessel_gold.rim_enabled = true
	_vessel_gold.rim = 0.4
	_vessel_gold.rim_tint = 0.8
	for i in 6:
		_rose_petals.append(_make_petal_mesh(_rng.randf_range(0.075, 0.095), _rng.randf_range(0.07, 0.088),
			_rng.randf_range(0.4, 0.75), _rng.randf_range(0.1, 0.3), _rng.randf_range(0.1, 0.5), 0))
	_lotus_petal = _make_petal_mesh(0.07, 0.034, 0.9, 0.25, 0.0, 1)
	_marigold_petal = _make_petal_mesh(0.026, 0.02, 0.5, 0.2, 0.3, 2)
	_sepal = _make_petal_mesh(0.04, 0.014, 0.6, 0.3, 0.6, 1)

func _petal(at: Vector3, scale_mul := 1.0) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.mesh = _rose_petals[_rng.randi() % _rose_petals.size()]
	p.position = at
	p.scale = Vector3.ONE * _rng.randf_range(0.82, 1.15) * scale_mul
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c: Color = PETAL_COLORS[_rng.randi() % PETAL_COLORS.size()]
	_paint(p, c.lerp(Color.WHITE, _rng.randf_range(0.0, 0.08)) * _rng.randf_range(0.92, 1.0), WARM_BASE)
	return p

func _paint(p: MeshInstance3D, color: Color, base: Color) -> void:
	p.set_instance_shader_parameter("petal_color", color)
	p.set_instance_shader_parameter("base_color", base)
	p.set_instance_shader_parameter("petal_seed", _rng.randf() * 100.0)

## Один лепесток цветка: основание в центре, наклон наружу на tilt (0 — вертикально, PI/2 — плашмя),
## вогнутой стороной к середине цветка
func _flower_petal(parent: Node3D, mesh: ArrayMesh, length: float, angle: float, tilt: float, radius: float,
		height: float, s: float, color: Color, base: Color) -> void:
	var d := Vector3(cos(angle), 0.0, sin(angle))
	var y := Vector3.UP * cos(tilt) + d * sin(tilt)
	var z := -(d * cos(tilt) - Vector3.UP * sin(tilt))
	var x := y.cross(z)
	var p := MeshInstance3D.new()
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.transform = Transform3D(Basis(x * s, y * s, z * s), d * radius + Vector3(0, height, 0) + y * (length * 0.5 * s))
	_paint(p, color, base)
	parent.add_child(p)

func _make_rose(color: Color) -> Node3D:
	var f := Node3D.new()
	var golden := PI * (3.0 - sqrt(5.0))
	var k := 0
	# от тугого бутона в центре к раскрытым внешним лепесткам
	for ring in [[3, 0.08, 0.002, 0.42], [4, 0.22, 0.004, 0.52], [5, 0.42, 0.007, 0.62], [6, 0.7, 0.01, 0.72], [7, 1.0, 0.012, 0.78]]:
		for i in ring[0]:
			var mesh := _rose_petals[k % _rose_petals.size()]
			var shade := 0.82 + 0.18 * float(ring[3]) / 0.78
			_flower_petal(f, mesh, 0.085, k * golden, ring[1] + _rng.randf_range(-0.06, 0.06), ring[2], 0.004,
				ring[3] * _rng.randf_range(0.92, 1.05), color * shade, WARM_BASE.lerp(color, 0.3))
			k += 1
	for i in 5:
		_flower_petal(f, _sepal, 0.04, TAU * i / 5.0, 1.85, 0.008, 0.0, 1.0, Color(0.22, 0.45, 0.14), Color(0.35, 0.55, 0.2))
	return f

func _make_marigold() -> Node3D:
	var f := Node3D.new()
	var golden := PI * (3.0 - sqrt(5.0))
	const N := 110
	for i in N:
		var k := float(i) / N
		var c := Color(1.0, 0.45, 0.02).lerp(Color(1.0, 0.72, 0.05), _rng.randf()) * _rng.randf_range(0.9, 1.0)
		_flower_petal(f, _marigold_petal, 0.026, i * golden, lerpf(0.1, 1.75, pow(k, 0.75)), 0.003 + 0.012 * sqrt(k),
			0.016 * (1.0 - k), _rng.randf_range(0.8, 1.15), c, Color(1.0, 0.85, 0.35))
	return f

func _make_lotus() -> Node3D:
	var f := Node3D.new()
	var pink := Color(1.0, 0.45, 0.65)
	var r := 0
	for ring in [[8, 0.38, 0.008, 0.72, 0.0], [8, 0.78, 0.012, 0.9, PI / 8.0], [8, 1.18, 0.016, 1.0, 0.0]]:
		for i in ring[0]:
			_flower_petal(f, _lotus_petal, 0.07, TAU * i / ring[0] + ring[4], ring[1] + _rng.randf_range(-0.05, 0.05), ring[2], 0.003,
				ring[3] * _rng.randf_range(0.94, 1.04), pink * (0.9 + 0.05 * r), Color(1.0, 0.98, 0.95))
		r += 1
	# семенная коробочка и тычинки в середине
	var pod := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.009
	cyl.height = 0.014
	var pod_mat := StandardMaterial3D.new()
	pod_mat.albedo_color = Color(0.95, 0.8, 0.25)
	pod_mat.roughness = 0.6
	pod_mat.emission_enabled = true
	pod_mat.emission = Color(0.25, 0.18, 0.02)
	cyl.material = pod_mat
	pod.mesh = cyl
	pod.position = Vector3(0, 0.012, 0)
	f.add_child(pod)
	return f

## Изогнутый лепесток: основание у -Y, край у +Y. Поперёк — чашечка, по длине — изгиб, край отогнут наружу.
## shape: 0 — лепесток розы (широкий скруглённый край с выемкой), 1 — заострённый (лотос, чашелистик), 2 — кружевной (бархатец)
func _make_petal_mesh(length: float, width: float, cup: float, bend: float, flare: float, shape: int) -> ArrayMesh:
	const NU := 12
	const NV := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_petal_mat)
	var half := width * 0.5
	for j in NV + 1:
		var v := float(j) / NV
		var w: float
		if shape == 1:
			w = half * (0.05 + 0.95 * pow(sin(PI * pow(v, 0.8)), 0.75))
		else:
			w = half * (0.1 + 0.9 * pow(v, 0.5) * sqrt(maxf(1.0 - pow(v, 3.2), 0.0)))
		for i in NU + 1:
			var u := float(i) / NU * 2.0 - 1.0
			var x := u * w
			var y := v
			if shape == 0:
				y *= 1.0 - 0.07 * exp(-u * u / 0.06) * smoothstep(0.75, 1.0, v)     # выемка посередине края
			var z := cup * x * x / half                                              # чашечка поперёк
			z += bend * length * (v - 0.25) * (v - 0.25)                             # изгиб по длине
			z -= flare * length * pow(maxf(v - 0.7, 0.0) / 0.3, 2.0) * 0.25          # край отогнут наружу
			var wave := 0.12 if shape == 2 else 0.035
			z += wave * width * sin(u * (10.0 if shape == 2 else 6.0) + v * 4.0) * pow(absf(u), 2.5) * v
			st.set_uv(Vector2((u + 1.0) * 0.5, v))
			st.add_vertex(Vector3(x, (y - 0.5) * length, z))
	for j in NV:
		for i in NU:
			var a := j * (NU + 1) + i
			var b := a + NU + 1
			for idx in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(idx)
	st.generate_normals()
	return st.commit()

# ---------- столы ----------

func _add_station(at: Vector3, kind: Kind, hint_text: String) -> Node3D:
	var node := Node3D.new()
	node.position = at
	node.scale = Vector3.ONE * SCALE
	add_child(node)
	_build_table(node)
	# Тёплый свет над столом — чтобы золото и лепестки сияли (без блика на зеркальном полу — он мигал как битый пиксель)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.6
	lamp.light_specular = 0.0
	lamp.omni_range = 2.2
	lamp.position = Vector3(0.0, 1.5, 0.35)
	node.add_child(lamp)
	var hint := _label(hint_text, 36)
	hint.position = Vector3(0, 1.2, 0)
	hint.scale = Vector3.ONE / SCALE     # подсказка не масштабируется вместе со столом
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.modulate.a = 0.0
	node.add_child(hint)
	_stations.append({"node": node, "kind": kind, "hint": hint})
	return node

## Резной круглый столик: профиль вращается вокруг оси (основание, колонна с бусинами, столешница, блюдо)
func _build_table(parent: Node3D) -> void:
	var table := [
		Vector2(0.29, 0.0), Vector2(0.32, 0.015), Vector2(0.31, 0.035), Vector2(0.26, 0.05),
		Vector2(0.24, 0.065), Vector2(0.18, 0.08), Vector2(0.11, 0.12), Vector2(0.075, 0.19), Vector2(0.06, 0.26),
		Vector2(0.085, 0.29), Vector2(0.095, 0.31), Vector2(0.085, 0.33), Vector2(0.06, 0.35), Vector2(0.05, 0.45),
		Vector2(0.048, 0.52), Vector2(0.07, 0.55), Vector2(0.08, 0.57), Vector2(0.07, 0.59), Vector2(0.06, 0.62),
		Vector2(0.09, 0.66), Vector2(0.15, 0.70), Vector2(0.25, 0.735), Vector2(0.40, 0.755), Vector2(0.43, 0.765),
		Vector2(0.44, 0.78), Vector2(0.435, 0.795), Vector2(0.41, 0.805), Vector2(0.0, 0.805),
	]
	var plate := [
		Vector2(0.0, 0.806), Vector2(0.15, 0.806), Vector2(0.19, 0.82), Vector2(0.215, 0.845),
		Vector2(0.225, 0.855), Vector2(0.215, 0.858), Vector2(0.20, 0.848), Vector2(0.17, 0.83), Vector2(0.0, 0.828),
	]
	_lathe(parent, table, _gold, 64)
	_lathe(parent, plate, _plate_gold, 64)
	# бусины по краю столешницы
	var bead := SphereMesh.new()
	bead.radius = 0.014
	bead.height = 0.028
	bead.material = _gold
	for i in 36:
		var a := TAU * float(i) / 36.0
		var b := MeshInstance3D.new()
		b.mesh = bead
		b.position = Vector3(cos(a) * 0.445, 0.765, sin(a) * 0.445)
		parent.add_child(b)

func _lathe(parent: Node3D, profile: Array, mat: Material, segments: int) -> void:
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
			# у оси вращения половина треугольников вырождается в линию — их нормали «битые» и мерцают, пропускаем
			for tri in [[v00, v10, v11], [v00, v11, v01]]:
				if (tri[1] - tri[0]).cross(tri[2] - tri[0]).length_squared() < 1e-12:
					continue
				for v in tri:
					st.add_vertex(v)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)

func _label(text: String, font_size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.0011
	l.outline_size = 10
	l.modulate = Color(1.0, 0.92, 0.75)
	l.outline_modulate = Color(0.05, 0.03, 0.1, 0.6)
	l.no_depth_test = true
	l.render_priority = 50
	l.outline_render_priority = 49
	return l
