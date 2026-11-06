extends Node3D
## Преображение практикующего в божество медитации без атрибутов (этап 6).
## Даттатрейя остаётся на лотосе; практикующий преображается сам: когда merge доходит до 1 (момент этап прячет
## во вспышке света), у него тело «маленького Даттатрейи» — одна голова, две руки, без атрибутов: копия модели
## Даттатрейи, из которой убраны боковые головы, верхние руки и предметы в руках. Глаза модели совпадают
## с глазами практикующего, голова видна только в зеркале (свою голову изнутри не видно).
## Тело сияет по стихиям: кожа (radiance), глаза (eyes_glow), свет из тела (body_light), аура (body_glow).
## Зеркало из света висит перед практикующим и следует за ним; отражение рисует отдельная камера в SubViewport.

const AURA_SHADER := preload("res://src/practice/aura.gdshader")
const MIRROR_SHADER := preload("res://src/practice/mirror.gdshader")
const RADIANCE_SHADER := preload("res://src/practice/body_radiance.gdshader")
const BodyStrip := preload("res://src/practice/body_strip.gd")

## Предметы в руках — у божества медитации без атрибутов их нет
const ATTRIBUTES := ["Bulava_low", "Disk_low", "Rakovina_low", "Trezubec_low", "Baraban_low", "Kuvshin_low", "Shariki_low", "четки на париках", "Luna_low", "Sumka_low"]
## Меши, из которых убираются лишние руки (тело, браслеты) и лишние головы (лица, глаза, серьги)
const ARM_MESHES := ["Body_low", "Sphere"]
const FACE_MESHES := ["Golova_low", "Glasa_low", "Sergi_low", "Volosi_low"]

## Слой только для зеркала: головы тела и сияние за спиной (основная камера его не рисует)
const MIRROR_ONLY_LAYER := 2
## Слой того, что висит у глаз (текст, свет во взгляде, само зеркало) — в отражении этого быть не должно
const OVERLAY_LAYER := 4
## Части модели на голове — от первого лица скрыты
const HEAD_MESHES := ["Golova_low", "Glasa_low", "Volosi_low", "Luna_low", "Sergi_low", "четки на париках"]
## Тилаки на лбах (на груди — Plane_003 — остаётся)
const HEAD_TILAKS := ["Plane", "Plane_001", "Plane_002"]
## Масштаб тела: модель Даттатрейи крупнее практикующего (~1.8 человека) — подгоняем
const BODY_SCALE := 0.75
## Глаза модели (центральная голова, у поверхности лица), в координатах модели
const MODEL_EYE := Vector3(0.0, 3.03, 0.0)
const MIRROR_SIZE := Vector2(1.7, 2.3)
## Где зеркало относительно практикующего: впереди слева, чуть ниже глаз, повёрнуто к нему —
## по центру остаётся виден Даттатрейя на лотосе
const MIRROR_OFFSET := Vector3(-1.5, -0.35, -2.1)
const MIRROR_TURN_DEG := 35.0
## Откуда зеркало «видит» тело и куда смотрит — в координатах модели Даттатрейи (она смотрит в +Z)
const MIRROR_CAM_FROM := Vector3(0.0, 2.6, 4.9)
const MIRROR_CAM_AT := Vector3(0.0, 2.05, 0.0)
const MIRROR_FOV := 46.0
## Сила сияния тела: сильнее — в зеркале за светом не видно самого тела
const AURA_STRENGTH := 0.4
const AURA_RAYS := 1.4
const SKIN_GLOW := 0.4
const BODY_LIGHT := 1.2
## На экране зеркало меньше 1000 точек по высоте: при 1100×1488 запас остаётся, а памяти и времени вдвое меньше, чем при 1500
const MIRROR_WIDTH := 1100.0

## 0..1 — преображение практикующего; 1 — преобразился, дальше тело от первого лица
var merge := 0.0
## 0..1 — аура за спиной (воздух; видно в зеркале)
var body_glow := 0.0
## 0..1 — сияние кожи (земля), глаз (вода), свет из тела (огонь)
var radiance := 0.0
var eyes_glow := 0.0
var body_light := 0.0
## 0..1 — зеркало
var mirror := 0.0

var _camera: Camera3D
var _pivot: Node3D
var _parts: Array[Node3D] = []
var _body: Node3D
var _body_aura: MeshInstance3D
var _viewport: SubViewport
var _mirror_cam: Camera3D
var _mirror: MeshInstance3D
var _mirror_frame := false
var _body_local: Transform3D
var _radiance_mat: ShaderMaterial
var _eyes_mat: ShaderMaterial
var _light: OmniLight3D

## parts — части объёмного Даттатрейи в сцене (лотос не летит — остаётся пустым троном)
func setup(camera: Camera3D, pivot: Node3D, parts: Array[Node3D]) -> void:
	_camera = camera
	_pivot = pivot
	# своих голов основная камера не видит
	_camera.cull_mask &= ~MIRROR_ONLY_LAYER

	# тело практикующего: глаза модели — в глазах практикующего, лицом туда же, куда он смотрит
	var turn := Basis(Vector3.UP, PI).scaled(Vector3.ONE * BODY_SCALE)
	_body_local = Transform3D(turn, -(turn * MODEL_EYE))
	_body = Node3D.new()
	_body.visible = false
	add_child(_body)
	_radiance_mat = ShaderMaterial.new()
	_radiance_mat.shader = RADIANCE_SHADER
	_eyes_mat = ShaderMaterial.new()
	_eyes_mat.shader = RADIANCE_SHADER
	_eyes_mat.set_shader_parameter("color", Color(0.85, 0.95, 1.0))
	for p in parts:
		# лотос основного божества остаётся на месте; его копия — лотос под практикующим
		if p.name != "lotos":
			_parts.append(p)
		var copy := p.duplicate() as Node3D
		copy.visible = true
		copy.transform = Transform3D.IDENTITY
		_body.add_child(copy)
		make_meditation_body(copy)
		for m in copy.find_children("*", "GeometryInstance3D", true, false):
			var g := m as GeometryInstance3D
			if g.is_queued_for_deletion():
				continue
			var mesh_name := String(g.name)
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var head: bool = HEAD_MESHES.has(mesh_name) or (p.name == "tilaki" and HEAD_TILAKS.has(mesh_name)) \
				or mesh_name == HEAD_BACK
			if head:
				g.layers = MIRROR_ONLY_LAYER
			# достроенные затылок, шея и плечи — без светящегося контура (иначе видны как отдельные белёсые формы)
			if not mesh_name.begins_with(HEAD_BACK) and p.name != "lotos":
				# глаза без наложения — того же цвета, что у основной фигуры (голубой отсвет менял цвет радужки)
				if mesh_name != "Glasa_low":
					g.material_overlay = _radiance_mat
		for a in copy.find_children("*", "Area3D", true, false):
			a.queue_free()
	# свет из тела (огонь) — у груди
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.6)
	_light.omni_range = 4.0
	_light.light_specular = 0.0
	_light.position = Vector3(0.0, 2.2, 0.8)
	_body.add_child(_light)
	# сияние за спиной — за головами
	_body_aura = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.4, 3.4)
	_body_aura.mesh = q
	var am := ShaderMaterial.new()
	am.shader = AURA_SHADER
	am.set_shader_parameter("rays", AURA_RAYS)
	_body_aura.material_override = am
	_body_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body_aura.layers = MIRROR_ONLY_LAYER
	_body_aura.position = Vector3(0.0, 2.6, -0.9)
	_body.add_child(_body_aura)

	# зеркало: отражение рисует камера за плоскостью зеркала в отдельный SubViewport
	_viewport = SubViewport.new()
	# зеркало крупное и близко — отражению нужно высокое разрешение и сглаживание, иначе руки и плечи «лесенкой»
	_viewport.size = Vector2i(MIRROR_WIDTH, int(MIRROR_WIDTH * MIRROR_SIZE.y / MIRROR_SIZE.x))
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_mirror_cam = Camera3D.new()
	_mirror_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_mirror_cam.fov = MIRROR_FOV
	_mirror_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_mirror_cam.cull_mask = 1 | MIRROR_ONLY_LAYER
	# экранные эффекты в отражении не видны, а стоили половины кадра и 600 МБ видеопамяти
	var world_env := _camera.get_world_3d().environment
	if world_env:
		var env := world_env.duplicate() as Environment
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.ssr_enabled = false
		env.adjustment_enabled = false   # кривая OpenGL применится к зеркалу в общем кадре, второй раз не нужна
		_mirror_cam.environment = env
	_viewport.add_child(_mirror_cam)
	_mirror = MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = MIRROR_SIZE
	_mirror.mesh = mq
	var mm := ShaderMaterial.new()
	mm.shader = MIRROR_SHADER
	mm.set_shader_parameter("reflection", _viewport.get_texture())
	_mirror.material_override = mm
	_mirror.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mirror.layers = OVERLAY_LAYER
	_mirror.position = MIRROR_OFFSET
	_mirror.rotation.y = deg_to_rad(MIRROR_TURN_DEG)
	_mirror.visible = false
	_pivot.add_child(_mirror)

## Две нижние руки и торс остаются; средние руки — далеко в стороны, верхние и их обрывки у плеч — сбоку
## и целиком позади груди (нижние руки идут вперёд, к коленям, торс — посередине)
static func _is_lower_arm_or_torso(center: Vector3, box: AABB) -> bool:
	var reach := maxf(absf(box.position.x), absf(box.end.x))
	if reach > 1.0:
		return false
	return not (box.end.z < 0.0 and absf(center.x) > 0.2)

## У убранных средних рук их кусок захватывает бок торса под мышкой — его оставляем, иначе в боку дыра
static func _is_torso_skin(p: Vector3) -> bool:
	return absf(p.x) < 0.36 and p.z > -0.3 and p.y < 2.6

## Рудракша-браслеты на плечах оставшихся рук (бусины лежат позади середины плеча и иначе убираются)
static func _is_armlet(p: Vector3) -> bool:
	return absf(p.x) > 0.28 and absf(p.x) < 0.55 and p.y > 1.95 and p.y < 2.3 and p.z > -0.55

## Обрывки спинной панели, к которой крепились верхние руки: торчали крыльями за плечами
## (в зеркале торчали лоскутом и линиями над плечом): у спинной панели убираем края за плечами и весь верх —
## спину сзади в зеркале не видно
static func _is_arm_stub(p: Vector3, box: AABB) -> bool:
	if box.end.z >= -0.25:
		return false
	return absf(p.x) > SHOULDER_HALF_WIDTH

const SHOULDER_HALF_WIDTH := 0.3
## Какая половина тела (x > 0: +1, x < 0: −1) отражается на другую; ниже MIRROR_Y_MIN (ноги, пояс) — как есть
const GOOD_SIDE := -1.0
const MIRROR_Y_MIN := -INF
## Имя затылка, который достраивается к центральной голове (у модели затылок общий для трёх голов)
const HEAD_BACK := "HeadBack"

## Из части Даттатрейи (узел модели, mala, tilaki…) сделать часть божества медитации без атрибутов:
## убрать предметы в руках, боковые головы, верхние руки; к голове достроить затылок с волосами.
## Координаты частей считаются относительно part (его родитель — место модели, Даттатрейя стоит в начале координат).
static func make_meditation_body(part: Node3D) -> void:
	var is_head := false
	for m in part.find_children("*", "GeometryInstance3D", true, false):
		var g := m as GeometryInstance3D
		var mesh_name := String(g.name)
		if ATTRIBUTES.has(mesh_name) or (part.name == "tilaki" and mesh_name in ["Plane_001", "Plane_002"]):
			g.queue_free()
			continue
		if not (g is MeshInstance3D):
			continue
		var mi := g as MeshInstance3D
		if mesh_name == "Golova_low":
			is_head = true
		var to_model := Transform3D.IDENTITY
		var n: Node = g
		while n != part and n is Node3D:
			to_model = (n as Node3D).transform * to_model
			n = n.get_parent()
		if ARM_MESHES.has(mesh_name):
			BodyStrip.strip(mi, to_model, _is_lower_arm_or_torso, _is_armlet if mesh_name == "Sphere" else _is_torso_skin, _is_arm_stub)
			# одна сторона (рука, плечо) собирается чисто — отражаем её на другую, тело становится симметричным
			var side := float(OS.get_environment("MIRROR_SIDE")) if OS.has_environment("MIRROR_SIDE") else GOOD_SIDE
			if side != 0.0:
				BodyStrip.mirror_half(mi, to_model, side, MIRROR_Y_MIN)
		elif FACE_MESHES.has(mesh_name):
			BodyStrip.strip(mi, to_model, _is_central_head)
	if is_head:
		_add_neck_back(part)

## Задняя сторона шеи: у модели она общая для трёх голов и убрана вместе с боковыми — без неё шея с прямыми
## срезами. Затылок не нужен: его закрывают волосы центральной головы (достроенный купол торчал тёмным пятном).
static func _add_neck_back(parent: Node3D) -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.86, 0.66, 0.56)
	skin.roughness = 0.6
	var neck := MeshInstance3D.new()
	neck.name = HEAD_BACK
	var c := CylinderMesh.new()
	c.top_radius = 0.1
	c.bottom_radius = 0.12
	c.height = 0.34
	c.radial_segments = 24
	neck.mesh = c
	neck.material_override = skin
	neck.position = Vector3(0.0, 2.67, -0.35)
	parent.add_child(neck)

## Только центральная голова: боковые лица, глаза и серьги — в стороне от середины; пучки и волосы боковых
## голов — позади центральной (у неё затылок не дальше z ≈ -0.4), без них за головой торчал тёмный ком
static func _is_central_head(center: Vector3, box: AABB) -> bool:
	return absf(center.x) < 0.12 and box.end.z > -0.25

## Где сейчас должно быть тело Даттатрейи-практикующего (мировые координаты)
func body_transform() -> Transform3D:
	return _pivot.global_transform * _body_local

## shown — объёмный Даттатрейя проявлен (datta_reveal этапа)
func commit(shown: bool) -> void:
	var target := body_transform()
	var merged := merge >= 1.0
	# Даттатрейя остаётся на своём месте — преображается только практикующий
	for p in _parts:
		p.visible = shown
	# тело от первого лица
	_body.visible = shown and merged
	_body.global_transform = target
	(_body_aura.material_override as ShaderMaterial).set_shader_parameter("intensity", AURA_STRENGTH * body_glow)
	_body_aura.visible = body_glow > 0.002
	_radiance_mat.set_shader_parameter("radiance", SKIN_GLOW * (radiance + 0.6 * body_light))
	_eyes_mat.set_shader_parameter("radiance", radiance + 2.5 * eyes_glow)
	_light.light_energy = BODY_LIGHT * body_light
	_light.visible = body_light > 0.002
	_update_mirror()

func _update_mirror() -> void:
	var m := smoothstep(0.0, 1.0, mirror)
	_mirror.visible = m > 0.002
	if not _mirror.visible:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# портрет в зеркале почти неподвижен — хватает отрисовки через кадр
	_mirror_frame = not _mirror_frame
	if _mirror_frame:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	(_mirror.material_override as ShaderMaterial).set_shader_parameter("alpha", m)
	# «Зеркало света» показывает практикующего всегда спереди, как портрет (картинка отражена, как в зеркале):
	# настоящее отражение показывало тело сбоку, а сбоку и сзади у двурукой формы пусто — спина модели общая
	# для шести рук. Камера стоит перед телом в его координатах и смотрит на грудь.
	var body := body_transform()
	var eye: Vector3 = body * MIRROR_CAM_FROM
	var target: Vector3 = body * MIRROR_CAM_AT
	_mirror_cam.global_transform = Transform3D.IDENTITY.translated(eye).looking_at(target, Vector3.UP)
