extends Node3D
## Мандала 24 божеств Шри Даттатрейи — в 3D (копия сцены с картинками mandala24.tscn, вместо картинок — фигуры).
## Датта, Шива и пять Брахм — готовые модели; остальные — модели из нейросети по картинкам (deity_kit.gd),
## пока их нет — картинки.
## По мандале ходят от первого лица: вход — с юга, через ворота, в центре — Датта.
##
## Стороны света: север — −Z, восток — +X, юг — +Z.
## Управление: мышь — смотреть, WASD — идти, Shift — быстрее, E/Q — выше/ниже, стрелки — повернуться,
## Пробел — взлететь над мандалой / приземлиться (в полёте W/S несут туда, куда смотришь, и быстрее),
## 1 — у южных ворот, 2 — перед Даттой, 3 — над мандалой, L — подписи, R — проявить заново,
## F — фигуры поворачиваются к вам / стоят неподвижно, каждая смотрит в свою сторону света (так по умолчанию),
## Esc — меню (мышь освобождается; щелчок в окне — снова смотреть мышью).

const Kit := preload("res://src/mandala24_3d/deity_kit.gd")
const GLOW_SHADER := preload("res://src/practice/figure_glow.gdshader")
const FLASH_SHADER := preload("res://src/mandala24_3d/appear_flash.gdshader")
const SPLASH_SHADER := preload("res://src/mandala24_3d/splash_bg.gdshader")
const OM_TEX := preload("res://images/om_big.png")

## Пол-янтра нарисована в метрах для квадрата 13 м; в сцене она во столько раз больше
const FLOOR_SCALE := 2.2

## Круги мандалы: 0 — центр, 1 — пять Брахм, 2 — пары (вторичные божества), 3 — хранители сторон света, 4 — зенит и надир
const GROUP_COLOR := [
	Color(0.98, 0.93, 0.8), Color(0.55, 0.12, 0.08), Color(0.12, 0.42, 0.12), Color(0.1, 0.12, 0.4), Color(0.98, 0.93, 0.8),
]

## id (как в deity_kit.gd), подпись, точка низа фигуры (м), рост фигуры (м), круг — места те же, что в сцене с картинками
const DEITIES := [
	["datta", "Шри Даттатрейя", Vector3(0, 0, 0), 3.6, 0],

	["sadyojata", "Садьоджата", Vector3(-6.5, 0, 0), 2.6, 1],
	["vamadeva", "Вамадева", Vector3(0, 0, -6.5), 2.6, 1],
	["aghora", "Агхора", Vector3(0, 0, 6.5), 3.2, 1],
	["tatpurusha", "Татпуруша", Vector3(6.5, 0, 0), 3.2, 1],
	["ishana_brahma", "Ишана", Vector3(0, 6.0, 0), 2.6, 1],

	# пары — на круге 10 м, бок о бок
	["brahma", "Брахма", Vector3(-10.0, 0, -1.45), 2.2, 2],
	["sarasvati", "Сарасвати", Vector3(-10.0, 0, 1.45), 2.2, 2],
	["vishnu", "Вишну", Vector3(-1.45, 0, -10.0), 2.2, 2],
	["lakshmi", "Лакшми", Vector3(1.45, 0, -10.0), 2.2, 2],
	["shiva", "Шива", Vector3(-1.45, 0, 10.0), 2.2, 2],
	["parvati", "Парвати", Vector3(1.45, 0, 10.0), 2.2, 2],
	["maheshvara", "Махешвара", Vector3(10.0, 0, -1.45), 2.2, 2],
	["ganesha", "Ганеша", Vector3(10.0, 0, 1.45), 2.2, 2],

	# хранители — у ворот (по осям, за краем квадрата) и в углах
	["kubera", "Кубера", Vector3(0, 0, -16.5), 2.4, 3],
	["ishana", "Ишана", Vector3(11.7, 0, -11.7), 2.4, 3],
	["indra", "Индра", Vector3(16.5, 0, 0), 2.4, 3],
	["agni", "Агни", Vector3(11.7, 0, 11.7), 2.4, 3],
	["dharmaraja", "Дхармарадж", Vector3(0, 0, 16.5), 2.4, 3],
	["nirriti", "Ниррити", Vector3(-11.7, 0, 11.7), 2.4, 3],
	["varuna", "Варуна", Vector3(-16.5, 0, 0), 2.4, 3],
	["vayu", "Ваю", Vector3(-11.7, 0, -11.7), 2.4, 3],

	["brahma_zenith", "Брахма", Vector3(0, 13.0, 0), 3.2, 4],
	["vishnu_nadir", "Вишну", Vector3(0, -14.0, 0), 3.2, 4],
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
## Вспышка появления (с от начала появления фигуры): разгорается, в её силе фигура проступает, потом гаснет
const FLASH_UP := 0.55
const FIGURE_IN := Vector2(0.3, 0.9)
const FLASH_DOWN := Vector2(0.85, 2.0)
## Заставка: сколько кадров «прогревать» фигуры за ней (первый показ модели в Godot 4.3 тормозит — компиляция шейдеров)
const PREWARM_FRAMES := 4
## сколько кадров показывать за заставкой каждую только что собранную фигуру (через кадр прозрачную и нет)
const WARM_FRAMES := 4
const SPLASH_FADE := 1.0
## сколько времени кадра (мкс) можно тратить на сборку фигур за заставкой
const BUILD_BUDGET_US := 12000
## не больше стольких фигур за кадр: в следующем кадре Godot собирает их шейдеры — пусть понемногу
const BUILD_PER_FRAME := 2
## фоновую загрузку начинаем через несколько кадров — когда заставка уже на экране
const LOAD_AFTER_FRAMES := 3
## самый большой шаг времени анимаций за кадр: после подвисания лучи и проявление продолжаются плавно, а не прыгают вперёд
const MAX_STEP := 1.0 / 30.0
const PARTS_DIR := "res://images/mandala24/parts/"
## как быстро фигура поворачивается к идущему (доля за секунду)
const TURN_SPEED := 1.5

@onready var _camera: Camera3D = $Camera
@onready var _floor: MeshInstance3D = $Floor
@onready var _menu = $Menu
@onready var _loading: Label = $Loading/Label

var _figures: Array[Node3D] = []
var _meshes: Array = []          # у каждой фигуры — её меши (для проявления прозрачностью)
var _labels: Array[Label3D] = []
var _glows: Array[MeshInstance3D] = []
var _flashes: Array[MeshInstance3D] = []
var _base_pos: Array[Vector3] = []
var _own_yaw: Array[float] = []  # куда фигура смотрит сама — наружу, в свою сторону света
var _appear_at: Array[float] = []
var _faded: Array[bool] = []
var _is_picture: Array[bool] = []  # вместо фигуры плоская картинка — она всегда поворачивается к вам, иначе сбоку не видна
var _time := 0.0
var _labels_on := true
var _face_viewer := false  # фигуры стоят неподвижно, каждая смотрит в свою сторону света; F — поворачивать к вам
var _loaded := false
var _pending: Array[String] = []
var _keep: Array = []            # загруженные в фоне модели и картинки — держим, чтобы Godot их не выгрузил
var _prof_done := {}
var _build_next := 0             # какую фигуру собирать следующей
var _warm_left: Array[int] = []  # сколько кадров ещё показывать фигуру за заставкой
var _counter := {}               # сколько фигур каждого круга уже собрано (для очереди появления)
var _splash_mat: ShaderMaterial
var _prewarm := 0             # сколько кадров ещё показывать фигуры за заставкой
var _splash: Control = null   # заставка загрузки: фон и вращающийся Ом
var _splash_om: TextureRect
var _splash_fading := false
var _splash_t := 0.0

var _pos := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _frames := 0
## Полёт (пробел): взлёт на FLY_HEIGHT с наклоном взгляда вниз, посадка — на рост человека
const FLY_HEIGHT := 9.0
const WALK_HEIGHT := 1.6
const FLY_SPEED := 2.5          # во сколько раз быстрее, чем пешком
const FLY_PITCH := -28.0        # куда наклонить взгляд при взлёте (°), если смотрели выше
var _flying := false
var _alt_target := -1.0         # куда плавно подняться/опуститься (−1 — никуда)
var _pitch_target := 999.0      # куда плавно наклонить взгляд (999 — никуда)
## проверочный запуск (кадры в PNG): мышь не захватывается, фигуры грузятся сразу;
## M24_T=секунды — с какого времени появления начать, M24_LOADING=1 — показывать только заставку
var _test_run := OS.has_environment("M24_SHOWN")
var _hold_loading := OS.has_environment("M24_LOADING")
## M24_PROFILE=1 — обычный запуск (без захвата мыши), в консоль пишутся долгие кадры и этапы загрузки
var _profile := OS.has_environment("M24_PROFILE")
var _prof_last := 0


func _ready() -> void:
	_floor.scale = Vector3(FLOOR_SCALE, 1.0, FLOOR_SCALE)
	var pose := int(OS.get_environment("M24_VIEW")) if OS.has_environment("M24_VIEW") else 1
	_go_to(pose - 1)
	# M24_POSE="x,y,z,поворот°,наклон°" — любая точка для кадра
	var custom := OS.get_environment("M24_POSE").split_floats(",")
	if custom.size() == 5:
		_pos = Vector3(custom[0], custom[1], custom[2])
		_yaw = deg_to_rad(custom[3])
		_pitch = deg_to_rad(custom[4])
	if OS.has_environment("M24_FIXED"):
		_face_viewer = false
	if OS.has_environment("M24_FLY"):  # проверка взлёта: как будто сразу нажали пробел
		_toggle_flight()
	if not _test_run and not _profile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_camera()
	_loading.visible = false
	if not _test_run or _hold_loading:
		_make_splash()
	# модели тяжёлые (десятки МБ) и картинки — грузятся в фоне, пока видна заставка
	var ids: Array = DEITIES.map(func(d): return d[0])
	var paths: Array[String] = Kit.scene_paths(ids)
	for id in ids:
		if not Kit.has_model(id) and ResourceLoader.exists(PARTS_DIR + id + ".png"):
			paths.append(PARTS_DIR + id + ".png")
	# сами запросы — в _process, когда заставка уже нарисована (иначе первые кадры подвисают ещё до неё)
	for p in paths:
		_pending.append(p)
	if _test_run and not _hold_loading:
		_finish_loading(true)
		_prewarm = 0
		_time = float(OS.get_environment("M24_T")) if OS.has_environment("M24_T") else 1000.0
	_apply()

func _exit_tree() -> void:
	get_viewport().disable_3d = false  # окно общее для всех сцен
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Заставка загрузки: фиолетовый фон с сиянием и медленно вращающийся лотос с Ом
func _make_splash() -> void:
	var layer: CanvasLayer = _loading.get_parent()
	layer.layer = 10
	_splash = Control.new()
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_splash)
	_splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_mat = ShaderMaterial.new()
	_splash_mat.shader = SPLASH_SHADER
	bg.material = _splash_mat
	_splash.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash_om = TextureRect.new()
	_splash_om.texture = OM_TEX
	_splash_om.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash_om.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_splash_om.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_splash_om.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.add_child(_splash_om)
	_splash_om.set_anchors_preset(Control.PRESET_CENTER)
	var half := 140.0
	_splash_om.offset_left = -half
	_splash_om.offset_top = -half
	_splash_om.offset_right = half
	_splash_om.offset_bottom = half
	_splash_om.pivot_offset = Vector2(half, half)

func _update_splash(delta: float) -> void:
	if _splash == null:
		return
	_splash_t += minf(delta, MAX_STEP)
	_splash_mat.set_shader_parameter("t", _splash_t)
	# Ом — треть высоты экрана при любом разрешении
	var half := get_viewport().get_visible_rect().size.y * 0.17
	_splash_om.offset_left = -half
	_splash_om.offset_top = -half
	_splash_om.offset_right = half
	_splash_om.offset_bottom = half
	_splash_om.pivot_offset = Vector2(half, half)
	_splash_om.scale = Vector2.ONE
	if _splash_fading:
		var k := clampf(_time / SPLASH_FADE, 0.0, 1.0)
		_splash.modulate.a = 1.0 - smoothstep(0.0, 1.0, k)
		_splash_om.scale *= 1.0 + 0.25 * k  # Ом чуть раскрывается, пока заставка тает
		if k >= 1.0:
			_splash.queue_free()
			_splash = null

## Модели грузятся в фоне все разом (по одной выходит в разы дольше, а подвисания те же: их дают сами тяжёлые модели,
## когда Godot передаёт их текстуры и меши в видеокарту в главном потоке)
func _check_loading() -> void:
	var waiting := false
	for p in _pending:
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			waiting = true
		elif _profile and not _prof_done.has(p):
			_prof_done[p] = true
			_prof("готово: " + p.get_file())
	if waiting:
		return
	_prof("модели загружены в фоне")
	# держим загруженное у себя: кэш Godot хранит ресурс, только пока на него есть ссылка,
	# иначе он освободится и при сборке фигур загрузится с диска ещё раз — уже без фона
	for p in _pending:
		_keep.append(ResourceLoader.load_threaded_get(p))
	# дальше фигуры собираются и прогреваются за заставкой — для этого нужен 3D
	get_viewport().disable_3d = false
	_finish_loading()

## all_at_once — собрать все фигуры сразу (проверочный кадр); иначе по нескольку за кадр, чтобы заставка не замирала
func _finish_loading(all_at_once := false) -> void:
	_loaded = true
	if all_at_once:
		while _build_next < DEITIES.size():
			_build_figure(_build_next)
			_build_next += 1
	_prewarm = PREWARM_FRAMES

## Собрать следующие фигуры, пока не истекло время кадра (хотя бы одну)
func _build_some() -> void:
	var t0 := Time.get_ticks_usec()
	var built := 0
	while _build_next < DEITIES.size() and built < BUILD_PER_FRAME and (built == 0 or Time.get_ticks_usec() - t0 < BUILD_BUDGET_US):
		built += 1
		var t := Time.get_ticks_usec()
		_build_figure(_build_next)
		if Time.get_ticks_usec() - t > 20000:
			_prof("фигура %s собиралась %d мс" % [DEITIES[_build_next][0], (Time.get_ticks_usec() - t) / 1000])
		_build_next += 1
	if _build_next >= DEITIES.size():
		_prof("все фигуры собраны")

func _prof(msg: String) -> void:
	if _profile:
		print("[M24 %6d мс, кадр %d] %s" % [Time.get_ticks_msec(), _frames, msg])

func _build_figure(i: int) -> void:
	var d: Array = DEITIES[i]
	var id: String = d[0]
	var base: Vector3 = d[2]
	var h: float = d[3]
	var group: int = d[4]

	# фигура: рост h, низ — в точке base, середина по xz — над ней
	var model := Kit.build(id)
	_is_picture.append(model == null)
	if model == null:
		model = _picture(id, h)
	else:
		var b := Kit.bounds(model)
		var s := h / maxf(b.size.y, 0.001)
		model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s),
			Vector3(-b.get_center().x * s, -b.position.y * s, -b.get_center().z * s))
	var f := Node3D.new()
	f.name = id
	f.position = base
	f.add_child(model)
	add_child(f)
	var flat := Vector2(base.x, base.z)
	var own := atan2(base.x, base.z) if flat.length() > 0.1 else 0.0
	f.rotation.y = own
	_figures.append(f)
	_base_pos.append(base)
	_own_yaw.append(own)
	var ms: Array = []
	for c in model.find_children("*", "GeometryInstance3D", true, false):
		ms.append(c)
	_meshes.append(ms)
	_faded.append(true)
	_warm_left.append(WARM_FRAMES)

	# лучи сияния за фигурой — тот же шейдер, что у древа Прибежища
	var g := MeshInstance3D.new()
	var q := QuadMesh.new()
	var size := h * 1.9
	q.size = Vector2(size, size)
	g.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter("figure_seed", fmod(float(i) * 0.618034, 1.0))
	mat.set_shader_parameter("figure_radius", 0.42)
	g.material_override = mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	_glows.append(g)

	# вспышка появления — перед фигурой, со стороны зрителя
	var fl := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(h * 1.7, h * 1.7)
	fl.mesh = fq
	var fm := ShaderMaterial.new()
	fm.shader = FLASH_SHADER
	fm.set_shader_parameter("seed", fmod(float(i) * 0.371, 1.0))
	fl.material_override = fm
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fl)
	_flashes.append(fl)

	# подпись — над фигурой
	var l := Label3D.new()
	l.text = d[1]
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.font_size = 64
	l.outline_size = 14
	l.pixel_size = 0.0038 if group == 2 else 0.0045
	l.modulate = GROUP_COLOR[group]
	l.outline_modulate = Color(1, 1, 1, 0.85) if group in [1, 2, 3] else Color(0.25, 0.05, 0.45, 0.9)
	l.position = base + Vector3(0, h + 0.35, 0)
	add_child(l)
	_labels.append(l)

	var k: int = _counter.get(group, 0)
	_counter[group] = k + 1
	_appear_at.append(REVEAL_START + group * REVEAL_GROUP_STEP + k * REVEAL_ITEM_STEP)

func _go_to(i: int) -> void:
	var p: Array = POSES[clampi(i, 0, POSES.size() - 1)]
	_pos = p[0]
	_yaw = deg_to_rad(p[1])
	_pitch = deg_to_rad(p[2])
	# «над мандалой» — это полёт, остальные места — пешком
	_flying = p[0].y > WALK_HEIGHT + 1.0
	_alt_target = -1.0
	_pitch_target = 999.0
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
			KEY_F:
				_face_viewer = not _face_viewer
			KEY_SPACE:
				_toggle_flight()

func _toggle_flight() -> void:
	_flying = not _flying
	if _flying:
		_alt_target = maxf(_pos.y, FLY_HEIGHT)
		if rad_to_deg(_pitch) > FLY_PITCH:
			_pitch_target = deg_to_rad(FLY_PITCH)
	else:
		_alt_target = WALK_HEIGHT
		if _pitch < deg_to_rad(-5.0):
			_pitch_target = 0.0

func _process(delta: float) -> void:
	_frames += 1
	if _profile:
		var now := Time.get_ticks_usec()
		if _prof_last > 0 and now - _prof_last > 25000:
			var phase := "загрузка" if not _loaded else ("сборка" if _build_next < DEITIES.size() else ("прогрев" if _prewarm > 0 else ("заставка тает" if _splash != null else "сцена")))
			_prof("долгий кадр %d мс (%s)" % [(now - _prof_last) / 1000, phase])
		_prof_last = now
	if not _loaded and not _hold_loading and not _test_run:
		if _frames == LOAD_AFTER_FRAMES:
			# первые кадры 3D рисуется за заставкой (собираются шейдеры пола, неба и эффектов), а пока грузятся модели —
			# не рисуется: за непрозрачной заставкой он незачем, а без него кадры заставки лёгкие и ровные
			get_viewport().disable_3d = true
			for p in _pending:
				ResourceLoader.load_threaded_request(p)
		elif _frames > LOAD_AFTER_FRAMES:
			_check_loading()
	if _loaded and _build_next < DEITIES.size():
		_build_some()
	_time += minf(delta, MAX_STEP)
	# прогрев отсчитывается, когда собраны все фигуры
	if _prewarm > 0 and _build_next >= DEITIES.size():
		_prewarm -= 1
		if _prewarm == 0:
			# всё уже показано один раз — заставка тает, мандала проявляется с начала
			_splash_fading = true
			_time = 0.0
	_update_splash(delta)
	_move(delta)
	if _prewarm > 0:
		_show_for_prewarm()
	else:
		_apply(delta)

## За заставкой: все фигуры, сияния, вспышки и подписи — прямо перед камерой, через кадр то прозрачные, то нет,
## чтобы Godot заранее собрал все их шейдеры и потом при появлении ничего не дорисовывалось кусками
func _show_for_prewarm() -> void:
	var b := _camera.global_transform.basis
	var half := _frames % 2 == 0
	for i in _figures.size():
		var f := _figures[i]
		# каждую фигуру — только первые кадры после сборки (шейдеры уже собраны), дальше прячем: так кадры заставки лёгкие
		var show := _warm_left[i] > 0
		_warm_left[i] -= 1
		f.visible = show
		_glows[i].visible = show
		_flashes[i].visible = show
		_labels[i].visible = show
		_faded[i] = true
		if not show:
			continue
		var p := _pos - b.z * 14.0 + b.x * (float(i % 6) - 2.5) * 3.0 + b.y * (float(i / 6) - 2.0) * 2.5
		f.global_position = p
		for m in _meshes[i]:
			(m as GeometryInstance3D).transparency = 0.5 if half else 0.0
		_glows[i].global_position = p
		(_glows[i].material_override as ShaderMaterial).set_shader_parameter("glow_strength", 0.01)
		_flashes[i].global_position = p
		(_flashes[i].material_override as ShaderMaterial).set_shader_parameter("intensity", 0.01)
		_labels[i].global_position = p

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
	if _flying:
		speed *= FLY_SPEED
	if dir != Vector3.ZERO:
		# в полёте — туда, куда смотришь (и вверх/вниз), пешком — только по земле
		var b := Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) if _flying else Basis(Vector3.UP, _yaw)
		_pos += b * dir.normalized() * speed * delta
	# плавный взлёт / посадка; E/Q или стрелки вверх-вниз перехватывают управление
	if up != 0.0:
		_alt_target = -1.0
	if tilt != 0.0:
		_pitch_target = 999.0
	if _alt_target >= 0.0:
		var k := clampf(delta * 1.6, 0.0, 1.0)
		_pos.y = lerpf(_pos.y, _alt_target, k)
		_pos.y = move_toward(_pos.y, _alt_target, delta * 0.3)
		if absf(_pos.y - _alt_target) < 0.01:
			_alt_target = -1.0
	if _pitch_target < 900.0:
		_pitch = lerp_angle(_pitch, _pitch_target, clampf(delta * 1.8, 0.0, 1.0))
		if absf(_pitch - _pitch_target) < 0.003:
			_pitch_target = 999.0
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

func _apply(delta := 0.0) -> void:
	_floor.material_override.set_shader_parameter("reveal", smoothstep(0.0, 1.5, _time if _loaded else 0.0))
	for i in _figures.size():
		# фигура проступает внутри вспышки: пока она полупрозрачна, вспышка в полной силе и закрывает её
		var t := _time - _appear_at[i]
		var a := smoothstep(FIGURE_IN.x, FIGURE_IN.y, t)
		var flash := smoothstep(0.0, FLASH_UP, t) * (1.0 - smoothstep(FLASH_DOWN.x, FLASH_DOWN.y, t))
		var f := _figures[i]
		f.visible = a > 0.002
		# проявление: прозрачность мешей, пока фигура проступает; потом — обычная непрозрачная (дешевле и без ошибок сортировки)
		var fading := a < 0.999
		if fading or _faded[i]:
			for m in _meshes[i]:
				(m as GeometryInstance3D).transparency = 1.0 - a if fading else 0.0
			_faded[i] = fading
		# лёгкое «дыхание» — фигуры чуть парят
		f.position = _base_pos[i] + Vector3(0, 0.03 * sin(_time * 0.6 + float(i) * 1.7), 0)
		# поворот к идущему (только вокруг вертикали) или в свою сторону света
		var target := _own_yaw[i]
		if _face_viewer or _is_picture[i]:
			var to := _pos - f.position
			target = atan2(to.x, to.z)
		var k := 1.0 if delta == 0.0 else clampf(TURN_SPEED * delta, 0.0, 1.0)
		f.rotation.y = lerp_angle(f.rotation.y, target, k)

		var g := _glows[i]
		g.visible = f.visible
		var h: float = DEITIES[i][3]
		g.position = f.position + Vector3(0, h * 0.55, 0) - Vector3(sin(f.rotation.y), 0, cos(f.rotation.y)) * 0.6
		var breath := 0.85 + 0.15 * sin(_time * 0.18 + float(i) * 2.3)
		(g.material_override as ShaderMaterial).set_shader_parameter("glow_strength", a * 0.35 * breath)
		var fl := _flashes[i]
		fl.visible = flash > 0.002
		if fl.visible:
			# центр вспышки — середина фигуры, чуть ближе к зрителю, чтобы фигура её не загораживала
			var mid := f.position + Vector3(0, h * 0.5, 0)
			var to_cam := _pos - mid
			to_cam.y = 0.0
			fl.position = mid + (to_cam.normalized() * 0.8 if to_cam.length() > 0.01 else Vector3.ZERO)
			(fl.material_override as ShaderMaterial).set_shader_parameter("intensity", flash * 1.25)
		var l := _labels[i]
		l.position = _base_pos[i] + Vector3(0, h + 0.35, 0)
		l.visible = _labels_on and f.visible
		l.modulate.a = a
		l.outline_modulate.a = a * 0.85

## Пока у божества нет 3D-фигуры — его картинка (как в мандале с картинками), лицом туда же, куда повёрнута фигура
func _picture(id: String, h: float) -> Node3D:
	var root := Node3D.new()
	var tex: Texture2D = load(PARTS_DIR + id + ".png")
	if tex == null:
		return root
	var s := Sprite3D.new()
	s.texture = tex
	var ph := h * 1.15
	s.pixel_size = ph / float(tex.get_height())
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position = Vector3(0, ph * 0.5, 0)
	root.add_child(s)
	return root
