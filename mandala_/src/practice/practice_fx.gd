extends Node3D
## Визуальные эффекты практики. Этап выставляет значения полей каждый кадр, затем вызывается commit().
## Свет в глазах и текст висят на камере (в VR — XR-камера). Знак Ом стоит перед практикующим
## на уровне груди и следует за ним (follow): поворачивается вместе с ним, но не наклоняется со взглядом.

const OM_EMBLEM_SHADER := preload("res://src/practice/om_emblem.gdshader")
const AURA_SHADER := preload("res://src/practice/aura.gdshader")
const VEIL_SHADER := preload("res://src/practice/light_veil.gdshader")
const BEAM_SHADER := preload("res://src/practice/light_beam.gdshader")
const PANEL_SHADER := preload("res://src/practice/text_panel.gdshader")
const OM_GLYPH := preload("res://images/om_glyph.png")

const BEAM_COUNT := 44          # лучей во все стороны
const BEAMS_TO_PLAYER := 5      # лучей к практикующему
const BEAM_LENGTH := 10.0

# Значения, которые задаёт этап
var om_intensity := 0.0
var om_halo := 0.0
var rays_out := 0.0
var rays_in := 0.0
var aura := 0.0
var veil_fill := 0.0
var veil_alpha := 0.0
var whiteout := 0.0
var title := ""
var text := ""
var text_alpha := 0.0
var tree_reveal := 0.0
var tree_shine := 0.0
## Большой Ом в центре, на месте древа: видимость, сияние, лучи
var center_om := 0.0
var center_halo := 0.0
var center_rays := 0.0
## Объёмные лучи из центра большого Ома: яркость и бегущая волна света (0 — у Ома, 1 — конец луча)
var center_beams := 0.0
var center_pulse := -1.0

## Древо Прибежища (refuge_tree.gd), если есть
var tree: Node3D

## Где знак Ом относительно практикующего: у груди, чуть впереди и ниже глаз (м) — лучи идут как из тела
var om_offset := Vector3(0.0, -0.3, -0.6)

var _om_pivot: Node3D
var _om: MeshInstance3D
var _center_om: MeshInstance3D
var _beams: Node3D
var _beam_mats: Array[ShaderMaterial] = []
var _player_beams: Array[MeshInstance3D] = []
var _player_beam_len := 1.0
var _center_light: OmniLight3D
var _camera: Camera3D
var _panel: MeshInstance3D
var _aura: MeshInstance3D
var _aura_light: OmniLight3D
var _veil: MeshInstance3D
var _title: Label3D
var _text: Label3D

func setup(camera: Camera3D, aura_position: Vector3) -> void:
	_camera = camera
	# Знак Ом — перед практикующим на уровне груди, следует за ним
	_om_pivot = Node3D.new()
	add_child(_om_pivot)
	_om = _quad(OM_EMBLEM_SHADER, Vector2(2.4, 2.4))
	_om.material_override.set_shader_parameter("glyph", OM_GLYPH)
	_om.material_override.set_shader_parameter("glyph_size", 0.07)
	_om.position = om_offset
	_om_pivot.add_child(_om)
	follow(camera.global_position, camera.global_rotation.y)

	# Сияние за Даттой
	_aura = _quad(AURA_SHADER, Vector2(6, 6))
	_aura.position = aura_position
	add_child(_aura)
	_aura_light = OmniLight3D.new()
	_aura_light.light_color = Color(1.0, 0.88, 0.7)
	_aura_light.omni_range = 7.0
	_aura_light.position = aura_position + Vector3(0, 0.8, 3.2)
	add_child(_aura_light)

	# Большой Ом в центре — перед сиянием, на месте Даттатрейи древа
	_center_om = _quad(OM_EMBLEM_SHADER, Vector2(9, 9))
	var cm := _center_om.material_override as ShaderMaterial
	cm.set_shader_parameter("glyph", OM_GLYPH)
	cm.set_shader_parameter("glyph_size", 0.27)
	cm.set_shader_parameter("billboard", true)
	_center_om.position = aura_position + Vector3(0, 0.75, 0.6)
	add_child(_center_om)

	# Объёмные лучи из самого центра большого Ома — во все стороны и к практикующему
	_beams = Node3D.new()
	_beams.position = _center_om.position
	add_child(_beams)
	var golden := PI * (3.0 - sqrt(5.0))
	for i in BEAM_COUNT:
		var y := 1.0 - (float(i) + 0.5) / float(BEAM_COUNT) * 2.0     # равномерно по сфере
		var r := sqrt(1.0 - y * y)
		var dir := Vector3(cos(golden * i) * r, y, sin(golden * i) * r)
		_add_beam(dir, BEAM_LENGTH, 0.22 + 0.12 * fmod(float(i) * 0.37, 1.0))
	for i in BEAMS_TO_PLAYER:
		_player_beams.append(_add_beam(Vector3.BACK, 1.0, 0.28))
	_center_light = OmniLight3D.new()
	_center_light.light_color = Color(1.0, 0.86, 0.6)
	_center_light.omni_range = 14.0
	_center_light.omni_attenuation = 1.2
	_beams.add_child(_center_light)

	# Свет, заполняющий взгляд, — прямо перед камерой, поверх всего
	_veil = _quad(VEIL_SHADER, Vector2(2, 2))
	_veil.position = Vector3(0, 0, -0.12)
	_veil.material_override.render_priority = 100
	camera.add_child(_veil)

	# Подложка под текст — чуть позади надписей
	_panel = _quad(PANEL_SHADER, Vector2(1, 1))
	_panel.material_override.render_priority = 40
	_panel.position = Vector3(0, 1.7, -2.42)
	camera.add_child(_panel)

	_title = _label(52)
	_title.position = Vector3(0, 1.6, -2.4)
	camera.add_child(_title)
	_text = _label(36)
	_text.position = Vector3(0, 1.5, -2.4)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	camera.add_child(_text)
	commit()

## Перенести знак Ом к практикующему: позиция глаз и поворот головы по горизонтали
func follow(eye_position: Vector3, yaw: float) -> void:
	if _om_pivot:
		_om_pivot.global_transform = Transform3D(Basis(Vector3.UP, yaw), eye_position)

## Всё погасить — перед началом этапа, чтобы эффекты прошлого этапа не оставались
func reset() -> void:
	om_intensity = 0.0; om_halo = 0.0; rays_out = 0.0; rays_in = 0.0
	aura = 0.0; veil_fill = 0.0; veil_alpha = 0.0; whiteout = 0.0
	title = ""; text = ""; text_alpha = 0.0
	tree_reveal = 0.0; tree_shine = 0.0
	center_om = 0.0; center_halo = 0.0; center_rays = 0.0
	center_beams = 0.0; center_pulse = -1.0

func commit() -> void:
	var om := _om.material_override as ShaderMaterial
	om.set_shader_parameter("intensity", om_intensity)
	om.set_shader_parameter("halo", om_halo)
	om.set_shader_parameter("rays_out", rays_out)
	om.set_shader_parameter("rays_in", rays_in)
	_om.visible = om_intensity + om_halo + rays_out + rays_in > 0.002

	var cm := _center_om.material_override as ShaderMaterial
	cm.set_shader_parameter("intensity", center_om)
	cm.set_shader_parameter("halo", center_halo)
	cm.set_shader_parameter("rays_out", center_rays)
	_center_om.visible = center_om + center_halo + center_rays > 0.002

	# Лучи к практикующему смотрят на его текущее место (на грудь) и заканчиваются у него
	var to_player := _camera.global_position + Vector3(0, -0.4, 0) - _beams.global_position
	_player_beam_len = to_player.length() + 0.2
	var spread := [Vector3.ZERO, Vector3(0.45, 0.15, 0), Vector3(-0.45, 0.15, 0), Vector3(0, 0.5, 0), Vector3(0, -0.4, 0)]
	for i in _player_beams.size():
		_orient_beam(_player_beams[i], (to_player + spread[i % spread.size()]).normalized(), _player_beam_len)
	_beams.visible = center_beams > 0.002
	for m in _beam_mats:
		m.set_shader_parameter("intensity", center_beams)
		m.set_shader_parameter("pulse", center_pulse)
	_center_light.light_energy = center_om * 0.25 + center_beams * 3.0
	_center_light.visible = center_om + center_beams > 0.002
	# Волна света дошла до практикующего — мягкая тёплая вспышка во взгляде
	var arrive := (to_player.length() / _player_beam_len) if _player_beam_len > 0.0 else 1.0
	var touch := exp(-pow((center_pulse - arrive) / 0.12, 2.0)) * center_beams

	(_aura.material_override as ShaderMaterial).set_shader_parameter("intensity", aura)
	_aura.visible = aura > 0.002
	_aura_light.light_energy = aura * 1.2
	_aura_light.visible = aura > 0.002

	var veil := _veil.material_override as ShaderMaterial
	veil.set_shader_parameter("fill", veil_fill)
	veil.set_shader_parameter("fill_alpha", veil_alpha)
	var white := maxf(whiteout, 0.3 * touch)
	veil.set_shader_parameter("whiteout", white)
	_veil.visible = veil_alpha * veil_fill > 0.002 or white > 0.002

	if tree:
		tree.reveal = tree_reveal
		tree.shine = tree_shine

	_title.text = title
	_text.text = text
	for l in [_title, _text]:
		l.modulate.a = text_alpha
		l.outline_modulate.a = text_alpha * 0.6
		l.visible = text_alpha > 0.002
	_update_panel()

## Плашка под текстом — по размеру заголовка и текста, с полями
func _update_panel() -> void:
	var box := AABB()
	var has := false
	for l in [_title, _text]:
		if l.text.is_empty():
			continue
		var a: AABB = l.get_aabb()
		a.position += l.position
		box = a if not has else box.merge(a)
		has = true
	_panel.visible = has and text_alpha > 0.002
	if not _panel.visible:
		return
	var pad := Vector2(0.09, 0.06)
	var size := Vector2(box.size.x, box.size.y) + pad * 2.0
	(_panel.mesh as QuadMesh).size = size
	_panel.position = Vector3(box.get_center().x, box.get_center().y, -2.42)
	var pm := _panel.material_override as ShaderMaterial
	pm.set_shader_parameter("size", size)
	pm.set_shader_parameter("alpha_mul", text_alpha)

## Луч-конус: вершина в центре Ома, расширяется наружу
func _add_beam(dir: Vector3, length: float, radius: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = 1.0
	c.radial_segments = 12
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	m.mesh = c
	var mat := ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam_mats.append(mat)
	_beams.add_child(m)
	_orient_beam(m, dir, length)
	return m

func _orient_beam(m: MeshInstance3D, dir: Vector3, length: float) -> void:
	# ось Y цилиндра — к вершине; вершину ставим в центр Ома, основание — на расстоянии length по dir
	var y := -dir.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	m.transform = Transform3D(Basis(x, y * length, z), dir.normalized() * length * 0.5)

func _quad(shader: Shader, size: Vector2) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = shader
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _label(font_size: int) -> Label3D:
	var l := Label3D.new()
	l.font_size = font_size
	l.pixel_size = 0.0011
	l.outline_size = 10
	l.modulate = Color(1.0, 0.95, 0.85)
	l.outline_modulate = Color(0.05, 0.03, 0.1, 0.6)
	l.no_depth_test = true
	l.render_priority = 50
	l.outline_render_priority = 49
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = 1500
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l
