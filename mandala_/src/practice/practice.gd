extends Node3D
## Практика «Тантрическая теургия 1»: ведёт этапы по записи, управляет камерой, звуком и эффектами.
## Управление: → / ← — к следующему / предыдущему шагу, Пробел — пауза, Esc — меню.

const STAGES := [preload("res://src/practice/stage1_guru_yoga.gd")]
const PracticeFx := preload("res://src/practice/practice_fx.gd")

@export var autostart := true
@export var start_delay := 2.0
@export var show_text := true
## Камера во время практики: по центру напротив Датты
@export var camera_position := Vector3(0.0, 2.05, 4.4)
@export var camera_target := Vector3(0.0, 1.8, -0.36)
@export var aura_position := Vector3(0.0, 2.3, -1.4)

var _fx
var _player: AudioStreamPlayer
var _stage
var _stage_index := -1
var _t := 0.0
var _delay := 0.0
var _paused := false
var _finished := false
var _frames := 0
var _menu: Node

func _ready() -> void:
	# Скрипт сцены крутит камеру мышью — во время практики камера неподвижна
	var scene := get_parent()
	scene.set_process_input(false)
	scene.set_physics_process(false)
	_menu = scene.get_node_or_null("Menu")

	var origin: Node3D = scene.get_node("Gods/Datta/CameraOrigin")
	origin.transform = Transform3D.IDENTITY
	var cam: Camera3D = origin.get_node("MainCamera")
	cam.global_position = camera_position
	cam.look_at(camera_target, Vector3.UP)

	_fx = PracticeFx.new()
	add_child(_fx)
	_fx.setup(cam, aura_position)

	_player = AudioStreamPlayer.new()
	add_child(_player)

	_delay = start_delay
	# Для проверки: PRACTICE_T=секунды — сразу перейти к этому месту этапа 1
	var debug_t := OS.get_environment("PRACTICE_T")
	if not debug_t.is_empty():
		_delay = 0.0
		_start_stage(0, float(debug_t))

func _process(delta: float) -> void:
	_frames += 1
	if _frames < 10:
		_stop_background_music()   # сцена включает плейлист отложенно — гасим его
	if _stage == null:
		if autostart and not _finished:
			_delay -= delta
			if _delay <= 0.0:
				_start_stage(0, 0.0)
		return

	if not _paused:
		if _player.playing:
			_t = _player.get_playback_position() + AudioServer.get_time_since_last_mix()
		else:
			_t += delta
	if _t >= _stage.DURATION:
		_next_stage()
		return
	_stage.apply(_t, _fx)
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
	if _stage == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_RIGHT:
			_seek_cue(1)
		KEY_LEFT:
			_seek_cue(-1)
		KEY_SPACE:
			_set_paused(not _paused)

func _start_stage(index: int, at: float) -> void:
	_stop_background_music()
	_stage_index = index
	_stage = STAGES[index].new()
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
	_fx.aura = 0.0; _fx.veil_alpha = 0.0; _fx.whiteout = 0.0
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

func _stop_background_music() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.call("Stop")
