extends Node3D
## Образы этапов, которые описывает ведущий (practice_fx.gd задаёт значения, commit() применяет):
## солнце Сурьи над древом (Гаятри), Шива слева от древа (Махамритьюнджая) — появляется и уходит во вспышке,
## волна благословения от Даттатрейи (три луча).

const SUN_SHADER := preload("res://src/practice/sun_disc.gdshader")
const WAVE_SHADER := preload("res://src/practice/blessing_wave.gdshader")
const AURA_SHADER := preload("res://src/practice/aura.gdshader")
const SHIVA_SCENE := "res://models/gods/round1/ishana/Ishana.tscn"

## Солнце справа над древом (над вершиной его закрывала бы плашка с текстом); в его диске — Сурья
## (литография Ravi Varma Press «Сурья-Нараяна», общественное достояние, Wikimedia Commons)
const SUN_POSITION := Vector3(3.3, 5.4, -1.8)
const SUN_SIZE := 4.2
const SURYA_TEXTURE := preload("res://images/surya.png")
const SURYA_SIZE := 1.45      # медальон чуть больше диска солнца (диск — 0.32 от половины квада)
## Шива (модель Ишаны, сидит в медитации) — слева от древа, на полу мандалы, лицом к практикующему
const SHIVA_POSITION := Vector3(-3.4, -0.165, -2.4)
const SHIVA_HEIGHT := 3.3
const SHIVA_MODEL_BOTTOM := -0.555
const SHIVA_MODEL_HEIGHT := 5.84
## Откуда исходит волна благословения — грудь объёмного Даттатрейи
const WAVE_CENTER := Vector3(0.0, 2.35, -0.2)
const WAVE_MAX_RADIUS := 9.0
## Волна света от груди практикующего (Четыре Безмерных, посвящение заслуг) — кольцо-стена света вокруг него
const RING_SHADER := preload("res://src/practice/light_ring.gdshader")
const RING_HEIGHT := 1.4
const RING_MAX_RADIUS := 14.0
## Чистое видение: всё пространство мандалы наполнено мерцающими искрами света
const SPARKLE_CENTER := Vector3(0.0, 2.6, -0.5)
const SPARKLE_EXTENTS := Vector3(7.0, 2.6, 7.0)

var _sun: MeshInstance3D
var _surya: Sprite3D
var _shiva: Node3D
var _shiva_flash: MeshInstance3D
var _shiva_light: OmniLight3D
var _wave: MeshInstance3D
var _ring: MeshInstance3D
var _sparkles: GPUParticles3D
var _sparkle_mat: StandardMaterial3D

func setup(look_from: Vector3) -> void:
	_sun = _quad(SUN_SHADER, SUN_SIZE)
	_sun.position = SUN_POSITION
	add_child(_sun)
	# Сурья в диске солнца — как фигуры древа, 2.5D: картинка всегда лицом к практикующему
	_surya = Sprite3D.new()
	_surya.texture = SURYA_TEXTURE
	_surya.pixel_size = SURYA_SIZE / float(SURYA_TEXTURE.get_width())
	_surya.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_surya.shaded = false
	_surya.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_surya.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surya.position = SUN_POSITION + (look_from - SUN_POSITION).normalized() * 0.05
	add_child(_surya)

	_shiva = (load(SHIVA_SCENE) as PackedScene).instantiate()
	var s := SHIVA_HEIGHT / SHIVA_MODEL_HEIGHT
	var yaw := atan2(look_from.x - SHIVA_POSITION.x, look_from.z - SHIVA_POSITION.z)
	_shiva.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s),
		SHIVA_POSITION - Vector3(0.0, SHIVA_MODEL_BOTTOM * s, 0.0))
	_shiva.visible = false
	add_child(_shiva)
	for g in _shiva.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# вспышка, в которой Шива появляется и уходит, и мягкий свет на нём
	_shiva_flash = _quad(AURA_SHADER, 5.0)
	_shiva_flash.material_override.set_shader_parameter("color", Color(0.85, 0.92, 1.0))
	_shiva_flash.material_override.set_shader_parameter("rays", 0.8)
	_shiva_flash.position = SHIVA_POSITION + Vector3(0.0, SHIVA_HEIGHT * 0.5, 0.6)
	add_child(_shiva_flash)
	_shiva_light = OmniLight3D.new()
	_shiva_light.light_color = Color(0.9, 0.93, 1.0)
	_shiva_light.omni_range = 5.0
	_shiva_light.light_specular = 0.0
	_shiva_light.position = SHIVA_POSITION + Vector3(0.6, SHIVA_HEIGHT * 0.6, 1.8)
	add_child(_shiva_light)

	_wave = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_wave.mesh = sphere
	var wm := ShaderMaterial.new()
	wm.shader = WAVE_SHADER
	_wave.material_override = wm
	_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wave.position = WAVE_CENTER
	add_child(_wave)

	_ring = MeshInstance3D.new()
	var wall := CylinderMesh.new()
	wall.top_radius = 1.0
	wall.bottom_radius = 1.0
	wall.height = RING_HEIGHT
	wall.radial_segments = 96
	wall.rings = 1
	wall.cap_top = false
	wall.cap_bottom = false
	_ring.mesh = wall
	var rm := ShaderMaterial.new()
	rm.shader = RING_SHADER
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_add_sparkles()
	commit(0.0, 0.0, 0.0, -1.0, 0.0)
	commit_vision(0.0, Vector3.ZERO, -1.0, 0.0, Color.WHITE)

## Искры света во всём пространстве: медленно всплывают, загораются и гаснут
func _add_sparkles() -> void:
	_sparkles = GPUParticles3D.new()
	_sparkles.amount = 700
	_sparkles.lifetime = 7.0
	_sparkles.preprocess = 7.0   # поле искр уже заполнено, когда появляется
	_sparkles.position = SPARKLE_CENTER
	_sparkles.visibility_aabb = AABB(-SPARKLE_EXTENTS * 1.5, SPARKLE_EXTENTS * 3.0)
	_sparkles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = SPARKLE_EXTENTS
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.1
	pm.gravity = Vector3(0.0, 0.04, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	var life := Gradient.new()
	life.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	life.colors = PackedColorArray([Color(1.0, 0.95, 0.8, 0.0), Color(1.0, 0.9, 0.65, 1.0),
		Color(1.0, 0.95, 0.85, 1.0), Color(1.0, 0.95, 0.8, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = life
	pm.color_ramp = ramp
	_sparkles.process_material = pm

	var dot := GradientTexture2D.new()
	dot.width = 64
	dot.height = 64
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	var soft := Gradient.new()
	soft.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	dot.gradient = soft
	_sparkle_mat = StandardMaterial3D.new()
	_sparkle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sparkle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sparkle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_sparkle_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_sparkle_mat.vertex_color_use_as_albedo = true
	_sparkle_mat.albedo_texture = dot
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	quad.material = _sparkle_mat
	_sparkles.draw_pass_1 = quad
	add_child(_sparkles)

## sparkle — искры чистого видения 0..1; волна света от груди: центр, фаза 0..1 (−1 — нет), яркость, цвет
func commit_vision(sparkle: float, ring_center: Vector3, ring_phase: float, ring_strength: float, ring_color: Color) -> void:
	_sparkles.visible = sparkle > 0.002
	_sparkles.emitting = _sparkles.visible
	_sparkle_mat.albedo_color = Color(1.0, 1.0, 1.0, clampf(sparkle, 0.0, 1.0))

	var on := ring_phase >= 0.0 and ring_strength > 0.002
	_ring.visible = on
	if on:
		var r := lerpf(0.4, RING_MAX_RADIUS, ring_phase)
		_ring.scale = Vector3(r, 1.0, r)
		_ring.global_position = ring_center
		var fade := smoothstep(0.0, 0.06, ring_phase) * (1.0 - smoothstep(0.45, 1.0, ring_phase))
		var rm := _ring.material_override as ShaderMaterial
		rm.set_shader_parameter("intensity", ring_strength * fade)
		rm.set_shader_parameter("color", ring_color)

## sun — солнце 0..1; shiva — > 0.5 Шива виден; shiva_flash — вспышка 0..1;
## wave_phase — волна 0..1 (−1 — нет), wave_strength — её яркость
func commit(sun: float, shiva: float, shiva_flash: float, wave_phase: float, wave_strength: float) -> void:
	(_sun.material_override as ShaderMaterial).set_shader_parameter("intensity", 1.6 * sun)
	_sun.visible = sun > 0.002
	_surya.modulate = Color(1.15, 1.1, 1.0, smoothstep(0.0, 1.0, sun))
	_surya.visible = _sun.visible

	_shiva.visible = shiva > 0.5
	_shiva_light.visible = _shiva.visible
	_shiva_light.light_energy = 1.2
	(_shiva_flash.material_override as ShaderMaterial).set_shader_parameter("intensity", 5.0 * shiva_flash)
	_shiva_flash.visible = shiva_flash > 0.002

	var on := wave_phase >= 0.0 and wave_strength > 0.002
	_wave.visible = on
	if on:
		var r := lerpf(0.6, WAVE_MAX_RADIUS, wave_phase)
		_wave.scale = Vector3.ONE * r
		var fade := smoothstep(0.0, 0.08, wave_phase) * (1.0 - smoothstep(0.55, 1.0, wave_phase))
		(_wave.material_override as ShaderMaterial).set_shader_parameter("intensity", wave_strength * fade)

func _quad(shader: Shader, size: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = shader
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m
