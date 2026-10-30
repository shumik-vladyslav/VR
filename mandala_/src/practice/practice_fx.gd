extends Node3D
## Визуальные эффекты практики. Этап выставляет значения полей каждый кадр, затем вызывается commit().
## Всё, что «в теле» практикующего (знак Ом, свет в глазах, текст), висит на камере —
## при переходе на VR это будет XR-камера.

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

var _om: MeshInstance3D
var _aura: MeshInstance3D
var _aura_light: OmniLight3D
var _veil: MeshInstance3D
var _title: Label3D
var _text: Label3D

func setup(camera: Camera3D, aura_position: Vector3) -> void:
	# Знак Ом — в нижней части поля зрения, «в груди»
	_om = _quad(OM_EMBLEM_SHADER, Vector2(2.4, 2.4))
	_om.material_override.set_shader_parameter("glyph", OM_GLYPH)
	_om.material_override.set_shader_parameter("glyph_size", 0.17)
	_om.position = Vector3(0, -0.6, -1.5)
	camera.add_child(_om)

	# Сияние за Даттой
	_aura = _quad(AURA_SHADER, Vector2(8, 8))
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

	_title = _label(64)
	_title.position = Vector3(0, 1.62, -2.4)
	camera.add_child(_title)
	_text = _label(40)
	_text.position = Vector3(0, 1.45, -2.4)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	camera.add_child(_text)
	commit()

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
