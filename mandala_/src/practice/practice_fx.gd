extends Node3D
## Визуальные эффекты практики. Этап выставляет значения полей каждый кадр, затем вызывается commit().
## Свет в глазах и текст висят на камере (в VR — XR-камера). Знак Ом стоит перед практикующим
## на уровне груди и следует за ним (follow): поворачивается вместе с ним, но не наклоняется со взглядом.

const OM_EMBLEM_SHADER := preload("res://src/practice/om_emblem.gdshader")
const AURA_SHADER := preload("res://src/practice/aura.gdshader")
const VEIL_SHADER := preload("res://src/practice/light_veil.gdshader")
const OM_GLYPH := preload("res://images/om_glyph.png")

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

## Древо Прибежища (refuge_tree.gd), если есть
var tree: Node3D

## Где знак Ом относительно практикующего: у груди, чуть впереди и ниже глаз (м) — лучи идут как из тела
var om_offset := Vector3(0.0, -0.3, -0.6)

var _om_pivot: Node3D
var _om: MeshInstance3D
var _aura: MeshInstance3D
var _aura_light: OmniLight3D
var _veil: MeshInstance3D
var _title: Label3D
var _text: Label3D

func setup(camera: Camera3D, aura_position: Vector3) -> void:
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

	# Свет, заполняющий взгляд, — прямо перед камерой, поверх всего
	_veil = _quad(VEIL_SHADER, Vector2(2, 2))
	_veil.position = Vector3(0, 0, -0.12)
	_veil.material_override.render_priority = 100
	camera.add_child(_veil)

	_title = _label(52)
	_title.position = Vector3(0, 1.74, -2.4)
	camera.add_child(_title)
	_text = _label(36)
	_text.position = Vector3(0, 1.64, -2.4)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	camera.add_child(_text)
	commit()

## Перенести знак Ом к практикующему: позиция глаз и поворот головы по горизонтали
func follow(eye_position: Vector3, yaw: float) -> void:
	if _om_pivot:
		_om_pivot.global_transform = Transform3D(Basis(Vector3.UP, yaw), eye_position)

func commit() -> void:
	var om := _om.material_override as ShaderMaterial
	om.set_shader_parameter("intensity", om_intensity)
	om.set_shader_parameter("halo", om_halo)
	om.set_shader_parameter("rays_out", rays_out)
	om.set_shader_parameter("rays_in", rays_in)
	_om.visible = om_intensity + om_halo + rays_out + rays_in > 0.002

	(_aura.material_override as ShaderMaterial).set_shader_parameter("intensity", aura)
	_aura.visible = aura > 0.002
	_aura_light.light_energy = aura * 1.2
	_aura_light.visible = aura > 0.002

	var veil := _veil.material_override as ShaderMaterial
	veil.set_shader_parameter("fill", veil_fill)
	veil.set_shader_parameter("fill_alpha", veil_alpha)
	veil.set_shader_parameter("whiteout", whiteout)
	_veil.visible = veil_alpha * veil_fill > 0.002 or whiteout > 0.002

	if tree:
		tree.reveal = tree_reveal
		tree.shine = tree_shine

	_title.text = title
	_text.text = text
	for l in [_title, _text]:
		l.modulate.a = text_alpha
		l.outline_modulate.a = text_alpha * 0.6
		l.visible = text_alpha > 0.002

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
