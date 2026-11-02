extends Node3D
## Практика «Тантрическая теургия 1»: ведёт этапы по записи, управляет камерой, звуком и эффектами.
## Управление: WASD — ходить, мышь — смотреть, Q / E — ниже / выше, Shift — быстрее, ЛКМ — взять / поднести лепестки,
## → / ← — к следующему / предыдущему шагу, 1…9 — перейти к этапу, Пробел — пауза, Esc — меню.

const STAGES := [
	preload("res://src/practice/stage1_guru_yoga.gd"),
	preload("res://src/practice/stage2_space_purification.gd"),
	preload("res://src/practice/stage3_om21.gd"),
	preload("res://src/practice/stage4_refuge.gd"),
	preload("res://src/practice/stage5_three_rays.gd"),
	preload("res://src/practice/stage6_transformation.gd"),
	preload("res://src/practice/stage7_datta_stava.gd"),
]
const PracticeFx := preload("res://src/practice/practice_fx.gd")
const RefugeTree := preload("res://src/practice/refuge_tree.gd")
const Offering := preload("res://src/practice/offering.gd")

@export var autostart := true
@export var start_delay := 2.0
@export var show_text := true
## 3D-Датта с лотосом скрыт, пока этап его не проявит (в центре древа — Датта с картинки)
@export var hide_datta := true
## Камера во время практики: по центру, смотрит на древо Прибежища целиком
@export var camera_position := Vector3(0.0, 2.9, 4.94)
@export var camera_target := Vector3(0.0, 2.77, -0.36)
## Низ древа (подставка коренного Гуру), по центру лотоса
@export var tree_position := Vector3(0.0, 0.35, -0.36)
## Все столы подношений стоят дугой справа, у края мандалы (радиус ~5.2 от центра): от ближнего к дальнему —
## лепестки, цветы, плоды, лампада, благовония, вода
@export var offering_table_position := Vector3(2.25, -0.165, 4.35)
@export var flower_stand_position := Vector3(3.53, -0.165, 3.5)
@export_group("Манасика-пуджа (этап Датта Става)")
@export var fruit_table_position := Vector3(4.51, -0.165, 2.32)
@export var water_table_position := Vector3(4.94, -0.165, -2.14)
@export var lamp_table_position := Vector3(5.1, -0.165, 0.9)
@export var incense_table_position := Vector3(5.24, -0.165, -0.63)
## Куда подносить — грудь объёмного Даттатрейи; вокруг этой точки обносятся лампада, благовония и вода
@export var puja_center := Vector3(0.0, 2.3, -0.25)
@export_group("")

@export_group("Перемещение")
@export var move_speed := 1.5
@export var mouse_sensitivity := 0.15
## Ходить можно в круге этого радиуса вокруг центра мандалы
@export var walk_radius := 9.0
@export var mandala_center := Vector2(0.05, -0.36)
@export var min_height := 0.6
@export var max_height := 6.0

var _fx
var _player: AudioStreamPlayer
var _stage
var _stage_index := -1
var _t := 0.0
var _delay := 0.0
var _paused := false
var _finished := false
var _frames := 0
## Свет, в котором закончился прошлый этап, — плавно гаснет в начале следующего (переход идёт через свет)
var _carry_white := 0.0
var _stage_time := 0.0
const CARRY_FADE := 4.0
var _menu: Node
var _offering
var _cam: Camera3D
var _pos := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0

func _ready() -> void:
	# Скрипт сцены крутит камеру вокруг Датты — во время практики камерой управляет практика
	var scene := get_parent()
	scene.set_process_input(false)
	scene.set_physics_process(false)
	_menu = scene.get_node_or_null("Menu")

	var datta: Node3D = scene.get_node("Gods/Datta")
	var origin: Node3D = datta.get_node("CameraOrigin")
	var datta_parts: Array[Node3D] = []
	if hide_datta:
		for child in datta.get_children():
			if child != origin and child is Node3D:
				child.visible = false
				datta_parts.append(child)
	_sharpen_chest_dram(datta)
	origin.transform = Transform3D.IDENTITY
	var cam: Camera3D = origin.get_node("MainCamera")
	# Блики прожекторов в зеркальном полу мигают как битый пиксель; 3D-Датты во время практики нет — блики не нужны
	for light in scene.find_children("*", "Light3D", true, false):
		if not (light is DirectionalLight3D):
			(light as Light3D).light_specular = 0.0
	_cam = cam
	cam.global_position = camera_position
	cam.look_at(camera_target, Vector3.UP)
	_pos = camera_position
	_yaw = cam.global_rotation.y
	_pitch = cam.global_rotation.x
	# Для проверки: PRACTICE_POSE="x,y,z,yaw°,pitch°" — начать с этой точки
	var pose := OS.get_environment("PRACTICE_POSE").split_floats(",")
	if pose.size() == 5:
		_pos = Vector3(pose[0], pose[1], pose[2])
		_yaw = deg_to_rad(pose[3])
		_pitch = deg_to_rad(pose[4])
	_apply_camera()

	var tree := RefugeTree.new()
	add_child(tree)
	tree.global_position = tree_position
	tree.build(camera_position)

	_fx = PracticeFx.new()
	add_child(_fx)
	_fx.tree = tree
	_fx.datta_parts = datta_parts
	# сияние святых — за Даттой в центре древа
	_fx.setup(cam, tree.figure_position("datta") + Vector3(0, 0.25, -0.5))
	_fx.setup_transformation()
	_apply_camera()

	_offering = Offering.new()
	add_child(_offering)
	_offering.setup(cam, offering_table_position, flower_stand_position, tree.figure_position("datta"))
	_offering.setup_puja({
		Offering.Kind.FRUIT: fruit_table_position, Offering.Kind.LAMP: lamp_table_position,
		Offering.Kind.INCENSE: incense_table_position, Offering.Kind.WATER: water_table_position,
	}, puja_center, Vector3(mandala_center.x, -0.165, mandala_center.y))

	_player = AudioStreamPlayer.new()
	add_child(_player)

	_delay = start_delay
	# Для проверки: PRACTICE_T=секунды (и PRACTICE_STAGE=номер этапа) — сразу перейти к этому месту
	var debug_t := OS.get_environment("PRACTICE_T")
	if not debug_t.is_empty():
		_delay = 0.0
		var debug_stage := OS.get_environment("PRACTICE_STAGE")
		_start_stage(clampi(int(debug_stage) - 1, 0, STAGES.size() - 1) if not debug_stage.is_empty() else 0, float(debug_t))

func _process(delta: float) -> void:
	_frames += 1
	if _frames < 10:
		_stop_background_music()   # сцена включает плейлист отложенно — гасим его
	# Для проверки: PRACTICE_OFFER="кадр взять,кадр поднести" — нажать «действие» на этих кадрах
	var offer_frames := OS.get_environment("PRACTICE_OFFER").split_floats(",")
	if offer_frames.has(float(_frames)):
		_offering.interact()
	_move(delta)
	if _stage == null:
		if autostart and not _finished:
			_delay -= delta
			if _delay <= 0.0:
				_start_stage(0, 0.0)
		return

	if not _paused:
		var pos := _player.get_playback_position() + AudioServer.get_time_since_last_mix()
		# по окончании записи плеер на кадр отдаёт позицию 0 — время практики назад само не идёт
		if _player.playing and pos >= _t - 0.25:
			_t = pos
		else:
			_t += delta
	if _t >= _stage.DURATION:
		_next_stage()
		return
	_stage.apply(_t, _fx)
	_stage_time += delta
	_fx.carry_white = _carry_white * (1.0 - smoothstep(0.0, CARRY_FADE, _stage_time))
	# подношения, которые идут прямо по записи (цветы на лучах Ом, пригоршня красных цветов)
	_offering.apply_rituals(_fx)
	# после подношения лепестков святые на время разгораются
	_fx.tree_shine = maxf(_fx.tree_shine, 0.8 * _offering.glow)
	# и сияние за объёмным Даттатрейей
	if _fx.aura > 0.0:
		_fx.aura += 0.6 * _offering.glow
	if OS.has_environment("PRACTICE_DEBUG"):
		print("PRACTICE frame=%d t=%.2f beams=%.2f white=%.2f" % [_frames, _t, _fx.center_beams, _fx.whiteout])
	if not show_text:
		_fx.text_alpha = 0.0
	_fx.commit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _menu:
			_menu.call("ToggleMenu")
			_set_paused(_menu.get("IsOpened"))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _looking():
		# при захвате мыши окно присылает рывок курсора — первые кадры и резкие скачки пропускаем
		if _frames < 15 or event.relative.length() > 300.0:
			return
		_yaw -= deg_to_rad(event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - deg_to_rad(event.relative.y * mouse_sensitivity), deg_to_rad(-80), deg_to_rad(80))
		_apply_camera()
		return
	# ЛКМ — взять лепестки со стола / поднести их
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _looking():
		_offering.interact()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# Цифры 1…9 (в том числе на цифровой клавиатуре) — перейти к началу этапа
	var digit := -1
	if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		digit = event.physical_keycode - KEY_1
	elif event.physical_keycode >= KEY_KP_1 and event.physical_keycode <= KEY_KP_9:
		digit = event.physical_keycode - KEY_KP_1
	if digit >= 0:
		if digit < STAGES.size():
			_start_stage(digit, 0.0)
		return
	if _stage == null:
		return
	match event.physical_keycode:
		KEY_RIGHT:
			_seek_cue(1)
		KEY_LEFT:
			_seek_cue(-1)
		KEY_SPACE:
			_set_paused(not _paused)

## Мышь захвачена и меню закрыто — можно ходить и смотреть (в тестовых запусках с PRACTICE_T — нет)
func _looking() -> bool:
	if not OS.get_environment("PRACTICE_T").is_empty():
		return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not (_menu and _menu.get("IsOpened"))

func _move(delta: float) -> void:
	if _looking():
		var dir := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): dir.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S): dir.z += 1.0
		if Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
		var up := 0.0
		if Input.is_physical_key_pressed(KEY_E): up += 1.0
		if Input.is_physical_key_pressed(KEY_Q): up -= 1.0
		var speed := move_speed * (2.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		if dir != Vector3.ZERO:
			_pos += Basis(Vector3.UP, _yaw) * dir.normalized() * speed * delta
		_pos.y = clampf(_pos.y + up * speed * delta, min_height, max_height)
		# не выходить за край мандалы
		var flat := Vector2(_pos.x, _pos.z) - mandala_center
		if flat.length() > walk_radius:
			flat = flat.normalized() * walk_radius
			_pos.x = mandala_center.x + flat.x
			_pos.z = mandala_center.y + flat.y
	_apply_camera()

func _apply_camera() -> void:
	if _cam == null:
		return
	_cam.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), _pos)
	if _fx:
		_fx.follow(_pos, _yaw)

func _start_stage(index: int, at: float) -> void:
	_stop_background_music()
	_stage_index = index
	_stage = STAGES[index].new()
	# сколько света было на экране в конце прошлого этапа — он не обрывается, а плавно гаснет
	_carry_white = maxf(_fx.whiteout, _fx.carry_white)
	_stage_time = 0.0
	_fx.reset()
	# столы манасика-пуджи — только на этапе, где она есть
	_offering.set_puja_visible(STAGES[index].get_script_constant_map().has("PUJA"))
	_finished = false
	_paused = false
	_t = at
	_player.stream = load(_stage.AUDIO)
	_player.play(at)

func _next_stage() -> void:
	if _stage_index + 1 < STAGES.size():
		_start_stage(_stage_index + 1, 0.0)
		return
	# Все готовые этапы пройдены
	_player.stop()
	_stage = null
	_finished = true
	_fx.om_intensity = 0.0; _fx.om_halo = 0.0; _fx.rays_out = 0.0; _fx.rays_in = 0.0
	_fx.veil_alpha = 0.0; _fx.whiteout = 0.0
	_fx.tree_shine = 0.0   # древо и сияние остаются
	_fx.title = ""
	_fx.text = ""
	_fx.text_alpha = 0.0
	_fx.commit()

func _seek_cue(direction: int) -> void:
	var cues: Array = _stage.CUES
	var target := _t
	if direction > 0:
		target = _stage.DURATION
		for c in cues:
			if c > _t + 0.5:
				target = c
				break
	else:
		target = 0.0
		for c in cues:
			if c < _t - 2.0:
				target = c
	if target >= _stage.DURATION:
		_next_stage()
		return
	_t = target
	_player.play(target)
	_player.stream_paused = _paused

func _set_paused(p: bool) -> void:
	_paused = p
	_player.stream_paused = p

## Слог «Драм» на груди Даттатрейи: в модели он светится ровным цветом на весь квадрат (яркость 3.2) —
## с сиянием практики это размытое пятно. Светится только сам знак и мягче — знак читается
func _sharpen_chest_dram(datta: Node) -> void:
	var dram := datta.find_child("Plane_003", true, false) as MeshInstance3D
	if dram == null:
		return
	var mat := dram.get_active_material(0) as StandardMaterial3D
	if mat == null:
		return
	var m := mat.duplicate() as StandardMaterial3D
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.9
	dram.material_override = m

func _stop_background_music() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.call("Stop")
