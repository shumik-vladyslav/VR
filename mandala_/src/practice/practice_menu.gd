extends CanvasLayer
## Меню практики (Esc): пауза и перемотка с пояснениями, список этапов, подсказки по управлению, настройки, выход.
## Громкость, чувствительность мыши, чёткость и подписи запоминаются между запусками.

signal close_pressed
signal pause_pressed
signal seek_by(seconds: float)
signal seek_to(t: float)
signal step_pressed(direction: int)
signal stage_step_pressed(direction: int)
signal stage_picked(index: int)
signal volume_changed(linear: float)
signal sensitivity_changed(value: float)
signal subtitles_changed(on: bool)

const CONFIG_PATH := "user://practice.cfg"
const MAIN_MENU_SCENE := "res://src/app/App.tscn"
const ESC_HINT_TIME := 12.0

const GOLD := Color(0.96, 0.8, 0.42)
const TEXT := Color(0.95, 0.93, 0.88)
const DIM := Color(0.72, 0.71, 0.8)

const KEYS := [
	["Мышь", "смотреть вокруг"],
	["W A S D", "ходить"],
	["Q / E", "ниже / выше"],
	["Shift", "идти быстрее"],
	["Левая кнопка мыши", "взять и поднести подношение"],
	["Пробел", "пауза"],
	["← / →", "предыдущий / следующий шаг"],
	["↓ / ↑", "на 15 секунд назад / вперёд"],
	["1 … 9", "перейти к этапу"],
	["Esc", "открыть и закрыть меню"],
]

var _titles: Array[String] = []
var _config := ConfigFile.new()
var _screen: Control
var _pause_note: Label
var _esc_hint: Label
var _stage_label: Label
var _state_label: Label
var _time_label: Label
var _total_label: Label
var _timeline: HSlider
var _scrubbing := false
var _pause_button: Button
var _transport_buttons: Array[Button] = []
var _stage_buttons: Array[Button] = []
var _current_stage := -1
var _volume: HSlider
var _sensitivity: HSlider
var _detail: HSlider
var _subtitles: CheckButton
var _fullscreen: CheckButton

func setup(titles: Array[String], sensitivity: float, show_text: bool) -> void:
	_titles = titles
	layer = 10
	_build()
	_config.load(CONFIG_PATH)
	_volume.value = _config.get_value("practice", "volume", 1.0)
	_sensitivity.value = _config.get_value("practice", "sensitivity", sensitivity)
	_detail.value = _config.get_value("practice", "detail", 1.0)
	_subtitles.button_pressed = _config.get_value("practice", "subtitles", show_text)
	_volume.value_changed.connect(volume_changed.emit)
	_sensitivity.value_changed.connect(sensitivity_changed.emit)
	_detail.value_changed.connect(_set_detail)
	_subtitles.toggled.connect(subtitles_changed.emit)
	volume_changed.emit(_volume.value)
	sensitivity_changed.emit(_sensitivity.value)
	_set_detail(_detail.value)
	subtitles_changed.emit(_subtitles.button_pressed)

func is_open() -> bool:
	return _screen.visible

func open() -> void:
	_fullscreen.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_esc_hint.visible = false
	_screen.visible = true

func close() -> void:
	_scrubbing = false
	_screen.visible = false
	_save()

## Показать текущее состояние практики; duration = 0 — этап сейчас не идёт
func refresh(stage_index: int, t: float, duration: float, paused: bool, finished: bool) -> void:
	var running := duration > 0.0
	_pause_note.visible = running and paused and not is_open()
	if not is_open():
		return
	_pause_button.text = "Играть" if paused else "Пауза"
	for b in _transport_buttons:
		b.disabled = not running
	_timeline.editable = running
	_state_label.text = ("На паузе" if paused else "Идёт") if running else ""
	if running:
		_stage_label.text = "Этап " + _titles[stage_index]
		_timeline.max_value = duration
		_total_label.text = _clock(duration)
		if not _scrubbing:
			_timeline.value = t
			_time_label.text = _clock(t)
	else:
		_stage_label.text = "Практика завершена. Можно выбрать этап и пройти его ещё раз." if finished else "Практика сейчас начнётся…"
		_timeline.value = 0.0
		_time_label.text = _clock(0.0)
		_total_label.text = _clock(0.0)
	var current := stage_index if running else -1
	if current != _current_stage:
		_current_stage = current
		for i in _stage_buttons.size():
			_stage_buttons[i].add_theme_color_override("font_color", GOLD if i == current else TEXT)

func _exit_tree() -> void:
	get_viewport().scaling_3d_scale = 1.0   # настройка практики: другим сценам она не нужна
	_save()

func _save() -> void:
	_config.set_value("practice", "volume", _volume.value)
	_config.set_value("practice", "sensitivity", _sensitivity.value)
	_config.set_value("practice", "detail", _detail.value)
	_config.set_value("practice", "subtitles", _subtitles.button_pressed)
	_config.save(CONFIG_PATH)

func _clock(t: float) -> String:
	return "%d:%02d" % [floori(t / 60.0), int(t) % 60]

func _build() -> void:
	var base := Control.new()
	base.theme = _make_theme()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Обе надписи — в правом углу: по центру сверху висит панель с текстом практики
	_pause_note = _note("Пауза.  Пробел — продолжить, Esc — меню")
	base.add_child(_pause_note)
	_pause_note.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 36)
	_pause_note.visible = false

	# Подсказка в начале: без неё не узнать, что меню вообще есть
	_esc_hint = _note("Esc — меню и подсказки")
	base.add_child(_esc_hint)
	_esc_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 36)
	_esc_hint.visible = OS.get_environment("PRACTICE_T").is_empty()
	get_tree().create_timer(ESC_HINT_TIME).timeout.connect(_esc_hint.hide)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.visible = false
	base.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen = dim

	var center := CenterContainer.new()
	_screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 1240.0
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)

	body.add_child(_label("Тантрическая теургия 1", 34, GOLD))
	var head := HBoxContainer.new()
	body.add_child(head)
	_stage_label = _label("", 24, TEXT)
	_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_stage_label)
	_state_label = _label("", 22, GOLD)
	head.add_child(_state_label)

	body.add_child(_build_timeline())
	body.add_child(_build_transport())
	var note := _label("Шаг — к началу следующей или предыдущей части этапа: мантры, визуализации, подношения. Этап — к началу другого этапа. " +
			"Ползунок — на любое место этапа. Пока меню открыто, практика на паузе; «Играть» включает её при открытом меню.", 18, DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	body.add_child(columns)
	columns.add_child(_build_stage_list())
	columns.add_child(_build_help())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	body.add_child(footer)
	var back := _button("Вернуться к практике (Esc)", close_pressed.emit)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(back)
	# В отдельной сборке «Теургия 1» других сцен нет — и главного меню тоже
	if not OS.has_feature("teurgia1"):
		footer.add_child(_button("Главное меню", _to_main_menu))
	footer.add_child(_button("Выйти из программы", get_tree().quit))

func _build_timeline() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_time_label = _label("0:00", 22, TEXT)
	row.add_child(_time_label)
	_timeline = _slider(0.0, 1.0, 0.1)
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timeline.scrollable = false
	_timeline.drag_started.connect(func() -> void: _scrubbing = true)
	_timeline.value_changed.connect(func(v: float) -> void:
		if _scrubbing:
			_time_label.text = _clock(v))
	_timeline.drag_ended.connect(func(_changed: bool) -> void:
		_scrubbing = false
		seek_to.emit(_timeline.value))
	row.add_child(_timeline)
	_total_label = _label("0:00", 22, TEXT)
	row.add_child(_total_label)
	return row

func _build_transport() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(_transport_button("« Этап", "предыдущий этап", stage_step_pressed.emit.bind(-1)))
	row.add_child(_transport_button("« Шаг", "клавиша ←", step_pressed.emit.bind(-1)))
	row.add_child(_transport_button("−15 с", "клавиша ↓", seek_by.emit.bind(-15.0)))
	row.add_child(_transport_button("Пауза", "Пробел", pause_pressed.emit))
	_pause_button = _transport_buttons.back()
	row.add_child(_transport_button("+15 с", "клавиша ↑", seek_by.emit.bind(15.0)))
	row.add_child(_transport_button("Шаг »", "клавиша →", step_pressed.emit.bind(1)))
	row.add_child(_transport_button("Этап »", "следующий этап", stage_step_pressed.emit.bind(1)))
	return row

func _transport_button(text: String, hint: String, on_press: Callable) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	var b := _button(text, on_press)
	b.custom_minimum_size = Vector2(156.0, 54.0)
	_transport_buttons.append(b)
	cell.add_child(b)
	var l := _label(hint, 17, DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(l)
	return cell

func _build_stage_list() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 500.0
	col.add_theme_constant_override("separation", 5)
	col.add_child(_label("Этапы", 24, GOLD))
	for i in _titles.size():
		var b := _button(_titles[i], stage_picked.emit.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_stage_buttons.append(b)
		col.add_child(b)
	return col

func _build_help() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	col.add_child(_label("Управление", 24, GOLD))
	var keys := GridContainer.new()
	keys.columns = 2
	keys.add_theme_constant_override("h_separation", 20)
	keys.add_theme_constant_override("v_separation", 1)
	for k in KEYS:
		keys.add_child(_label(k[0], 19, GOLD))
		keys.add_child(_label(k[1], 19, TEXT))
	col.add_child(keys)

	col.add_child(_label("Настройки", 24, GOLD))
	var settings := GridContainer.new()
	settings.columns = 2
	settings.add_theme_constant_override("h_separation", 20)
	settings.add_theme_constant_override("v_separation", 2)
	_volume = _slider(0.0, 1.0, 0.01)
	_sensitivity = _slider(0.05, 0.4, 0.01)
	_detail = _slider(0.5, 1.0, 0.05)
	_subtitles = CheckButton.new()
	_fullscreen = CheckButton.new()
	_fullscreen.toggled.connect(_set_fullscreen)
	for row in [["Громкость", _volume], ["Чувствительность мыши", _sensitivity], ["Чёткость картинки", _detail], ["Подписи на экране", _subtitles], ["Полный экран", _fullscreen]]:
		settings.add_child(_label(row[0], 19, TEXT))
		var control: Control = row[1]
		control.focus_mode = Control.FOCUS_NONE
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if control is HSlider else Control.SIZE_SHRINK_BEGIN
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		settings.add_child(control)
	col.add_child(settings)
	return col

## Чёткость ниже — видеокарте легче: на слабых компьютерах это главный способ поднять плавность
func _set_detail(scale: float) -> void:
	get_viewport().scaling_3d_scale = scale

func _set_fullscreen(on: bool) -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings:
		settings.call("SetFullscreen", on)

func _to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

## Надпись поверх практики, когда меню закрыто
func _note(text: String) -> Label:
	var l := _label(text, 24, TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Без фокуса клавиатуры: Пробел и стрелки и при открытом меню работают как в практике
func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b

func _slider(from: float, to: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = from
	s.max_value = to
	s.step = step
	s.focus_mode = Control.FOCUS_NONE
	return s

func _box(color: Color, border: Color, margin: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(8)
	b.set_content_margin_all(margin)
	return b

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 21
	var edge := Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	var panel := _box(Color(0.06, 0.05, 0.13, 0.95), GOLD, 26.0)
	panel.set_corner_radius_all(16)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("normal", "Button", _box(Color(1.0, 1.0, 1.0, 0.06), edge, 7.0))
	th.set_stylebox("hover", "Button", _box(Color(GOLD.r, GOLD.g, GOLD.b, 0.2), GOLD, 7.0))
	th.set_stylebox("pressed", "Button", _box(Color(GOLD.r, GOLD.g, GOLD.b, 0.35), GOLD, 7.0))
	th.set_stylebox("disabled", "Button", _box(Color(1.0, 1.0, 1.0, 0.02), Color(1.0, 1.0, 1.0, 0.08), 7.0))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		th.set_color(state, "Button", TEXT)
	th.set_color("font_disabled_color", "Button", Color(TEXT.r, TEXT.g, TEXT.b, 0.3))
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		th.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	var track := _box(Color(1.0, 1.0, 1.0, 0.15), Color(0, 0, 0, 0), 3.0)
	var filled := _box(GOLD, Color(0, 0, 0, 0), 3.0)
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", filled)
	th.set_stylebox("grabber_area_highlight", "HSlider", filled)
	return th
