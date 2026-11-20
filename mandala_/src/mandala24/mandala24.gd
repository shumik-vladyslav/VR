extends Node3D
## Мандала 24 божеств Шри Даттатрейи — пока картинками (как древо Прибежища в «Теургии 1»).
## По мандале ходят от первого лица, как в «Теургии 1»: вход — с юга, через ворота, в центре — Датта.
## Картинки: images/mandala24/parts/<id>.png (вырезаются из images/mandala24/_source/gen/ скриптом cut_generated.py);
## свою картинку достаточно положить под тем же именем — сцена подхватит её сама (размер берётся из высоты фигуры).
##
## Стороны света: север — −Z, восток — +X, юг — +Z.
## Управление: мышь — смотреть, WASD — идти, Shift — быстрее, E/Q — выше/ниже, стрелки — повернуться,
## 1 — у южных ворот, 2 — перед Даттой, 3 — над мандалой, L — подписи, R — проявить заново,
## Esc — меню (мышь освобождается; щелчок в окне — снова смотреть мышью).

const PARTS_DIR := "res://images/mandala24/parts/"
const GLOW_SHADER := preload("res://src/practice/figure_glow.gdshader")

## Пол-янтра нарисована в метрах для квадрата 13 м; в сцене она во столько раз больше
const FLOOR_SCALE := 2.2

## Круги мандалы: 0 — центр, 1 — пять Брахм, 2 — пары (вторичные божества), 3 — хранители сторон света, 4 — зенит и надир
const GROUP_COLOR := [
	Color(0.98, 0.93, 0.8), Color(0.55, 0.12, 0.08), Color(0.12, 0.42, 0.12), Color(0.1, 0.12, 0.4), Color(0.98, 0.93, 0.8),
]

## id картинки, подпись, точка низа фигуры (м), высота картинки (м), круг
const DEITIES := [
	["datta", "Шри Даттатрейя", Vector3(0, 0, 0), 4.2, 0],

	["sadyojata", "Садьоджата", Vector3(-6.5, 0, 0), 2.9, 1],
	["vamadeva", "Вамадева", Vector3(0, 0, -6.5), 2.9, 1],
	["aghora", "Агхора", Vector3(0, 0, 6.5), 2.9, 1],
	["tatpurusha", "Татпуруша", Vector3(6.5, 0, 0), 2.9, 1],
	["ishana_brahma", "Ишана", Vector3(0, 6.0, 0), 2.9, 1],

	# пары — на круге 10 м, бок о бок
	["brahma", "Брахма", Vector3(-10.0, 0, -1.45), 2.4, 2],
	["sarasvati", "Сарасвати", Vector3(-10.0, 0, 1.45), 2.4, 2],
	["vishnu", "Вишну", Vector3(-1.45, 0, -10.0), 2.4, 2],
	["lakshmi", "Лакшми", Vector3(1.45, 0, -10.0), 2.4, 2],
	["shiva", "Шива", Vector3(-1.45, 0, 10.0), 2.4, 2],
	["parvati", "Парвати", Vector3(1.45, 0, 10.0), 2.4, 2],
	["maheshvara", "Махешвара", Vector3(10.0, 0, -1.45), 2.4, 2],
	["ganesha", "Ганеша", Vector3(10.0, 0, 1.45), 2.4, 2],

	# хранители — у ворот (по осям, за краем квадрата) и в углах
	["kubera", "Кубера", Vector3(0, 0, -16.5), 2.8, 3],
	["ishana", "Ишана", Vector3(11.7, 0, -11.7), 2.8, 3],
	["indra", "Индра", Vector3(16.5, 0, 0), 2.8, 3],
	["agni", "Агни", Vector3(11.7, 0, 11.7), 2.8, 3],
	["dharmaraja", "Дхармарадж", Vector3(0, 0, 16.5), 2.8, 3],
	["nirriti", "Ниррити", Vector3(-11.7, 0, 11.7), 2.8, 3],
	["varuna", "Варуна", Vector3(-16.5, 0, 0), 2.8, 3],
	["vayu", "Ваю", Vector3(-11.7, 0, -11.7), 2.8, 3],

	["brahma_zenith", "Брахма", Vector3(0, 13.0, 0), 3.6, 4],
	["vishnu_nadir", "Вишну", Vector3(0, -14.0, 0), 3.6, 4],
]

## Места для клавиш 1/2/3: положение глаз (м), поворот (° от взгляда на север, + — влево), наклон (° вверх)
const POSES := [
	[Vector3(0, 1.6, 24.0), 0.0, 2.0],      # 1 — у южных ворот, лицом к центру
	[Vector3(0, 1.6, 4.2), 0.0, 14.0],      # 2 — перед Даттой
	[Vector3(0, 26.0, 26.0), 0.0, -42.0],   # 3 — над мандалой
]

@export var move_speed := 2.2
@export var mouse_sensitivity := 0.15
@export var walk_radius := 26.0
@export var min_height := 0.5
@export var max_height := 32.0

## Появление: круги по очереди (с), внутри круга — с небольшим сдвигом
const REVEAL_START := 0.8
const REVEAL_GROUP_STEP := 2.2
const REVEAL_ITEM_STEP := 0.25
const REVEAL_FADE := 1.6

@onready var _camera: Camera3D = $Camera
@onready var _floor: MeshInstance3D = $Floor
@onready var _menu = $Menu

var _sprites: Array[Sprite3D] = []
var _labels: Array[Label3D] = []
var _glows: Array[MeshInstance3D] = []
var _base_pos: Array[Vector3] = []
var _appear_at: Array[float] = []
var _time := 0.0
var _labels_on := true

var _pos := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _frames := 0
## проверочный запуск (кадры в PNG): мышь не захватывается
var _test_run := OS.has_environment("M24_SHOWN")

func _ready() -> void:
	_floor.scale = Vector3(FLOOR_SCALE, 1.0, FLOOR_SCALE)
	_build_figures()
	var pose := int(OS.get_environment("M24_VIEW")) if OS.has_environment("M24_VIEW") else 1
	_go_to(pose - 1)
	# M24_POSE="x,y,z,поворот°,наклон°" — любая точка для кадра
	var custom := OS.get_environment("M24_POSE").split_floats(",")
	if custom.size() == 5:
		_pos = Vector3(custom[0], custom[1], custom[2])
		_yaw = deg_to_rad(custom[3])
		_pitch = deg_to_rad(custom[4])
	# для кадров проверки: сразу всё проявлено
	if _test_run:
		_time = 1000.0
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_camera()
	_apply()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_figures() -> void:
	var counter := {}
	for i in DEITIES.size():
		var d: Array = DEITIES[i]
		var id: String = d[0]
		var base: Vector3 = d[2]
		var h: float = d[3]
		var group: int = d[4]
		var tex: Texture2D = load(PARTS_DIR + id + ".png")
		if tex == null:
			push_warning("Mandala24: нет картинки " + id)
			continue

		var s := Sprite3D.new()
		s.name = id
		s.texture = tex
		s.pixel_size = h / float(tex.get_height())
		# поворачивается к идущему только вокруг вертикали — фигура не заваливается, когда смотришь снизу или сверху
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.shaded = false
		s.double_sided = true
		# непрозрачная часть пишет глубину — полупрозрачный пол не ложится поверх фигур за ним
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.position = base + Vector3(0, h * 0.5, 0)
		add_child(s)
		_sprites.append(s)
		_base_pos.append(s.position)

		# лучи сияния за фигурой — тот же шейдер, что у древа Прибежища
		var g := MeshInstance3D.new()
		var q := QuadMesh.new()
		var size := maxf(tex.get_width(), tex.get_height()) * s.pixel_size * 1.75
		q.size = Vector2(size, size)
		g.mesh = q
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		mat.set_shader_parameter("figure_seed", fmod(float(i) * 0.618034, 1.0))
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		_glows.append(g)

		# подпись — над фигурой
		var l := Label3D.new()
		l.text = d[1]
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		l.font_size = 64
		l.outline_size = 14
		l.pixel_size = 0.0038 if group == 2 else 0.0045
		l.modulate = GROUP_COLOR[group]
		l.outline_modulate = Color(1, 1, 1, 0.85) if group in [1, 2, 3] else Color(0.25, 0.05, 0.45, 0.9)
		l.position = base + Vector3(0, h + 0.3, 0)
		add_child(l)
		_labels.append(l)

		var k: int = counter.get(group, 0)
		counter[group] = k + 1
		_appear_at.append(REVEAL_START + group * REVEAL_GROUP_STEP + k * REVEAL_ITEM_STEP)

func _go_to(i: int) -> void:
	var p: Array = POSES[clampi(i, 0, POSES.size() - 1)]
	_pos = p[0]
	_yaw = deg_to_rad(p[1])
	_pitch = deg_to_rad(p[2])
	_apply_camera()

func _looking() -> bool:
	return not _test_run and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _menu.IsOpened

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_menu.ToggleMenu()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _menu.IsOpened or _test_run else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if _menu.IsOpened:
		return
	# меню закрыли его кнопкой — щелчок в окне снова захватывает мышь
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _test_run:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and _looking():
		# при захвате мыши окно присылает рывок курсора — первые кадры и резкие скачки пропускаем
		if _frames < 15 or event.relative.length() > 300.0:
			return
		_yaw -= deg_to_rad(event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - deg_to_rad(event.relative.y * mouse_sensitivity), deg_to_rad(-85), deg_to_rad(85))
		_apply_camera()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_1, KEY_KP_1: _go_to(0)
			KEY_2, KEY_KP_2: _go_to(1)
			KEY_3, KEY_KP_3: _go_to(2)
			KEY_L:
				_labels_on = not _labels_on
			KEY_R:
				_time = 0.0

func _process(delta: float) -> void:
	_frames += 1
	_time += delta
	_move(delta)
	_apply()

func _move(delta: float) -> void:
	if _menu.IsOpened:
		return
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT): turn += 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT): turn -= 1.0
	var tilt := 0.0
	if Input.is_physical_key_pressed(KEY_UP): tilt += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN): tilt -= 1.0
	_yaw += deg_to_rad(turn * 70.0 * delta)
	_pitch = clampf(_pitch + deg_to_rad(tilt * 50.0 * delta), deg_to_rad(-85), deg_to_rad(85))
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
	var up := 0.0
	if Input.is_physical_key_pressed(KEY_E): up += 1.0
	if Input.is_physical_key_pressed(KEY_Q): up -= 1.0
	var speed := move_speed * (3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	if dir != Vector3.ZERO:
		_pos += Basis(Vector3.UP, _yaw) * dir.normalized() * speed * delta
	_pos.y = clampf(_pos.y + up * speed * delta, min_height, max_height)
	# не уходить далеко от мандалы
	var flat := Vector2(_pos.x, _pos.z)
	if flat.length() > walk_radius:
		flat = flat.normalized() * walk_radius
		_pos.x = flat.x
		_pos.z = flat.y
	_apply_camera()

func _apply_camera() -> void:
	_camera.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), _pos)

func _apply() -> void:
	_floor.material_override.set_shader_parameter("reveal", smoothstep(0.0, 1.5, _time))
	for i in _sprites.size():
		var a := smoothstep(0.0, 1.0, clampf((_time - _appear_at[i]) / REVEAL_FADE, 0.0, 1.0))
		var s := _sprites[i]
		s.visible = a > 0.002
		s.modulate = Color(1, 1, 1, a)
		# лёгкое «дыхание» — фигуры чуть парят
		s.position = _base_pos[i] + Vector3(0, 0.03 * sin(_time * 0.6 + float(i) * 1.7), 0)
		var g := _glows[i]
		g.visible = s.visible
		g.position = s.position
		var breath := 0.85 + 0.15 * sin(_time * 0.18 + float(i) * 2.3)
		# у фигур свой золотой ореол на картинке — лучей немного, иначе засвечивают соседей
		breath *= 0.3 if s.name == "datta" else 0.45
		(g.material_override as ShaderMaterial).set_shader_parameter("glow_strength", a * 0.55 * breath)
		var l := _labels[i]
		l.visible = _labels_on and s.visible
		l.modulate.a = a
		l.outline_modulate.a = a * 0.85
