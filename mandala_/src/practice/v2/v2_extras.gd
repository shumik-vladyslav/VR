extends Node3D
## Образы новой версии практики (practice_fx.gd задаёт значения, commit() применяет): фон — голубое пространство,
## горы, океан, золотая чистая земля; поток света сверху; дождь из лепестков; Даттатрейя вырастает; кольцо мантры
## вокруг слога Драм; шар золотого света из груди Даттатрейи в грудь практикующего; пол мандалы исчезает в пространстве.

const SKY_SHADER := preload("res://src/practice/v2/sky_dome.gdshader")
const COLUMN_SHADER := preload("res://src/practice/v2/light_column.gdshader")
const RING_SHADER := preload("res://src/practice/v2/mantra_ring.gdshader")
const RING_TEXTURE := preload("res://images/teurgia1_v2/mantra_ring.png")
const AURA_SHADER := preload("res://src/practice/aura.gdshader")
const DRAM_TEXTURE := preload("res://images/dram.png")
const DRAM_SIZE := 2.2

## Виды фона (sky_dome.gdshader)
enum Backdrop { SPACE, MOUNTAINS, OCEAN, GOLDEN }
const SKY_RADIUS := 60.0
## Точка у основания лотоса, вокруг которой Даттатрейя растёт (координаты сцены)
const GROW_PIVOT := Vector3(0.05, -0.165, -0.36)
## Где у Даттатрейи центр груди со слогом Драм (при росте 1)
const CHEST := Vector3(0.0, 2.25, -0.12)
const RING_SIZE := 1.5
const PETAL_COLORS := [Color(1.0, 0.45, 0.6), Color(1.0, 0.85, 0.9), Color(0.95, 0.2, 0.25), Color(1.0, 0.7, 0.2), Color(1.0, 1.0, 0.95)]

var _camera: Camera3D
var _sky: MeshInstance3D
var _column: MeshInstance3D
var _petals: GPUParticles3D
var _ring: MeshInstance3D
var _ball: MeshInstance3D
var _ball_light: OmniLight3D
var _dram: Sprite3D
var _floor: Node3D
var _parts: Array[Node3D] = []
## Слог Драм на груди модели Даттатрейи (Plane_003 в тилаках) — вокруг него вращается мантра
var _chest_dram: VisualInstance3D
var _part_base: Array[Transform3D] = []

func setup(camera: Camera3D, floor_node: Node3D, datta_parts: Array[Node3D]) -> void:
	_camera = camera
	_floor = floor_node
	_parts = datta_parts
	for p in _parts:
		_part_base.append(p.transform)
		if _chest_dram == null:
			_chest_dram = p.find_child("Plane_003", true, false) as VisualInstance3D

	_sky = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = SKY_RADIUS
	sphere.height = SKY_RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_sky.mesh = sphere
	_sky.material_override = _material(SKY_SHADER)
	_sky.material_override.render_priority = -100
	_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky.extra_cull_margin = 16384.0
	add_child(_sky)

	_column = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 5.5
	cyl.height = 16.0
	cyl.radial_segments = 48
	cyl.cap_top = false
	cyl.cap_bottom = false
	_column.mesh = cyl
	_column.material_override = _material(COLUMN_SHADER)
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.position = Vector3(GROW_PIVOT.x, 7.8, GROW_PIVOT.z)
	add_child(_column)

	_add_petals()

	_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * RING_SIZE
	_ring.mesh = q
	_ring.material_override = _material(RING_SHADER)
	_ring.material_override.set_shader_parameter("ring", RING_TEXTURE)
	_ring.material_override.render_priority = 30
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_ball = MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(1.3, 1.3)
	_ball.mesh = bq
	_ball.material_override = _material(AURA_SHADER)
	_ball.material_override.set_shader_parameter("color", Color(1.0, 0.82, 0.4))
	_ball.material_override.set_shader_parameter("rays", 0.4)
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	_ball_light = OmniLight3D.new()
	_ball_light.light_color = Color(1.0, 0.85, 0.55)
	_ball_light.omni_range = 3.0
	_ball_light.light_specular = 0.0
	_ball.add_child(_ball_light)

	# слог Драм, из которого снова проявляется Даттатрейя: золотой, на высоте его груди
	_dram = Sprite3D.new()
	_dram.texture = DRAM_TEXTURE
	_dram.pixel_size = DRAM_SIZE / float(DRAM_TEXTURE.get_width())
	_dram.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dram.shaded = false
	_dram.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_dram.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dram.position = CHEST + Vector3(0.0, 0.2, 0.4)
	add_child(_dram)
	commit({})

## Дождь из лепестков над Даттатрейей и вокруг
func _add_petals() -> void:
	_petals = GPUParticles3D.new()
	_petals.amount = 360
	_petals.lifetime = 9.0
	_petals.preprocess = 9.0
	_petals.position = Vector3(GROW_PIVOT.x, 6.5, GROW_PIVOT.z - 0.2)
	_petals.visibility_aabb = AABB(Vector3(-8, -9, -8), Vector3(16, 12, 16))
	_petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(4.5, 0.3, 2.4)   # ближе 2 м к практикующему лепестки не падают
	pm.direction = Vector3.DOWN
	pm.spread = 25.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.0, -0.35, 0.0)
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	var colors := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in PETAL_COLORS.size():
		offs.append(float(i) / float(PETAL_COLORS.size() - 1))
		cols.append(PETAL_COLORS[i])
	colors.offsets = offs
	colors.colors = cols
	var tex := GradientTexture1D.new()
	tex.gradient = colors
	pm.color_initial_ramp = tex
	_petals.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _petal_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.075, 0.1)
	quad.material = mat
	_petals.draw_pass_1 = quad
	_petals.emitting = false
	_petals.visible = false
	add_child(_petals)

## Лепесток: овал, сужающийся к основанию, с мягкой серединой
func _petal_texture() -> ImageTexture:
	var img := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 48:
			var u := (float(x) - 23.5) / 24.0
			var v := float(y) / 63.0
			var half := sin(PI * pow(v, 0.8)) * 0.95
			var inside := absf(u) < half
			var shade := 0.82 + 0.18 * (1.0 - absf(u) / maxf(half, 0.01))
			img.set_pixel(x, y, Color(shade, shade, shade, 1.0 if inside else 0.0))
	return ImageTexture.create_from_image(img)

## v — значения этапа: sky_from, sky_to, sky_blend, sky (0..1), column, petals, datta_grow, ring, ring_turn,
## ball_phase (−1 — нет), floor (0..1 — пол мандалы виден)
func commit(v: Dictionary) -> void:
	var sky: float = v.get("sky", 0.0)
	_sky.visible = sky > 0.002
	if _sky.visible:
		_sky.global_position = _camera.global_position
		var sm := _sky.material_override as ShaderMaterial
		sm.set_shader_parameter("from_mode", int(v.get("sky_from", Backdrop.SPACE)))
		sm.set_shader_parameter("to_mode", int(v.get("sky_to", Backdrop.SPACE)))
		sm.set_shader_parameter("blend", float(v.get("sky_blend", 0.0)))
		sm.set_shader_parameter("alpha", clampf(sky, 0.0, 1.0))

	var column: float = v.get("column", 0.0)
	_column.visible = column > 0.002
	(_column.material_override as ShaderMaterial).set_shader_parameter("intensity", column)

	# дождь кончается мягко: новые лепестки не появляются, уже летящие долетают
	var petals: bool = v.get("petals", 0.0) > 0.5
	if petals != _petals.emitting:
		_petals.emitting = petals
		if petals and not _petals.visible:
			_petals.visible = true
			_petals.restart()

	var grow: float = v.get("datta_grow", 1.0)
	for i in _parts.size():
		_parts[i].transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * grow), GROW_PIVOT * (1.0 - grow)) * _part_base[i]
	var chest := GROW_PIVOT + (CHEST - GROW_PIVOT) * grow
	if _chest_dram:
		chest = _chest_dram.global_transform * _chest_dram.get_aabb().get_center()

	var ring: float = v.get("ring", 0.0)
	_ring.visible = ring > 0.002
	if _ring.visible:
		# кольцо чуть впереди груди, к практикующему
		var toward := (_camera.global_position - chest).normalized()
		_ring.global_position = chest + toward * 0.15
		_ring.scale = Vector3.ONE * grow
		var rm := _ring.material_override as ShaderMaterial
		rm.set_shader_parameter("alpha", ring)
		rm.set_shader_parameter("angle", float(v.get("ring_turn", 0.0)))
		rm.set_shader_parameter("glow", 1.5 + 0.3 * ring)

	var ball: float = v.get("ball_phase", -1.0)
	_ball.visible = ball >= 0.0 and ball <= 1.0
	if _ball.visible:
		var target := _camera.global_position + _camera.global_basis * Vector3(0.0, -0.45, -0.5)
		var e := ball * ball * (3.0 - 2.0 * ball)
		_ball.global_position = chest.lerp(target, e) + Vector3.UP * 0.25 * sin(PI * e)
		var bright := sin(PI * minf(ball * 1.3, 1.0))
		(_ball.material_override as ShaderMaterial).set_shader_parameter("intensity", 2.4 * maxf(bright, 0.4))
		_ball_light.light_energy = 2.0 * bright

	var dram: float = v.get("dram", 0.0)
	_dram.visible = dram > 0.002
	_dram.modulate = Color(1.0, 0.82, 0.4, clampf(dram, 0.0, 1.0)) * Color(1.4, 1.4, 1.4, 1.0)

	if _floor:
		_floor.visible = float(v.get("floor", 1.0)) > 0.5

func _material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m

## Новый этап: лепестки прошлого этапа не досыпаются в пустом пространстве
func clear() -> void:
	_petals.emitting = false
	_petals.visible = false
