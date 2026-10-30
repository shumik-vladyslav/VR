extends Node3D
## Древо Прибежища из вырезанных фигур (images/refuge_tree/parts + parts.json).
## Ряды стоят на разной глубине: верх древа дальше, линия передачи ближе. Каждая фигура сдвигается
## вдоль луча от камеры, поэтому с места практикующего композиция совпадает с картинкой,
## а в VR при движении головы видна глубина.

const PARTS_DIR := "res://images/refuge_tree/parts/"
const PARTS_JSON := "res://images/refuge_tree/parts.json"
const GLOW_SHADER := preload("res://src/practice/figure_glow.gdshader")

## Свечение за фигурами: всегда чуть-чуть, с shine — сильнее
@export var glow_base := 0.35
@export var glow_shine := 0.9

## Метров на пиксель исходной картинки (в плоскости древа)
@export var meters_per_pixel := 0.0034
## Пиксель картинки, который ставится в начало узла древа (низ подставки коренного Гуру по центру)
@export var anchor_pixel := Vector2(645, 1925)
## Глубина рядов сверху вниз (м, минус — дальше от практикующего)
@export var row_depth := PackedFloat32Array([-1.6, -1.3, -1.05, -0.85, -0.6, -0.4, 0.0, 0.35, 0.5, 0.65, 0.85])

## 0..1 — проявление древа (все фигуры сразу)
var reveal := 0.0
## 0..1 — дополнительное сияние фигур
var shine := 0.0

var _sprites: Array[Sprite3D] = []
var _rows: Array[int] = []
var _base_pos: Array[Vector3] = []
var _glows: Array[MeshInstance3D] = []
var _glow_offset: Array[Vector3] = []
var _row_count := 1
var _time := 0.0

func build(camera_position: Vector3) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARTS_JSON))
	for p in data["parts"]:
		_row_count = maxi(_row_count, int(p["row"]) + 1)
	for p in data["parts"]:
		var row := int(p["row"])
		# точка в плоскости древа (мировые координаты)
		var local := Vector3((p["cx"] - anchor_pixel.x) * meters_per_pixel, (anchor_pixel.y - p["cy"]) * meters_per_pixel, 0.0)
		var plane := global_transform * local
		# сдвиг вдоль луча от камеры до нужной глубины с сохранением видимого размера
		var depth := row_depth[mini(row, row_depth.size() - 1)]
		if row == 4:
			depth += 0.25 * pow(absf(local.x) / 1.4, 2.0)   # дуга из девяти — края ближе
		var k := (plane.z + depth - camera_position.z) / (plane.z - camera_position.z)
		var world := camera_position + (plane - camera_position) * k

		var s := Sprite3D.new()
		s.texture = load(PARTS_DIR + p["id"] + ".png")
		s.pixel_size = meters_per_pixel * k
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.double_sided = true
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.name = p["id"]
		add_child(s)
		s.global_position = world
		_sprites.append(s)
		_rows.append(row)
		_base_pos.append(s.position)

		# лучи сияния чуть позади фигуры (дальше от камеры); фигура занимает ~57% радиуса квада (figure_radius в шейдере)
		var g := MeshInstance3D.new()
		var q := QuadMesh.new()
		var size := maxf(float(p["w"]), float(p["h"])) * s.pixel_size * 1.75
		q.size = Vector2(size, size)
		g.mesh = q
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.set_instance_shader_parameter("figure_seed", fmod(float(_sprites.size()) * 0.618034, 1.0))
		add_child(g)
		var back := (world - camera_position).normalized() * 0.04
		g.global_position = world + back
		_glows.append(g)
		_glow_offset.append(g.position - s.position)
	apply()

## Мировая позиция фигуры по id (например, "datta")
func figure_position(id: String) -> Vector3:
	for s in _sprites:
		if s.name == id:
			return s.global_position
	return global_position

func _process(delta: float) -> void:
	_time += delta
	apply()

func apply() -> void:
	for i in _sprites.size():
		var s := _sprites[i]
		# всё древо проявляется разом — так края вырезанных фигур меньше заметны
		var a := smoothstep(0.0, 1.0, reveal)
		s.visible = a > 0.002
		var glow := 1.0 + 0.3 * shine * (0.75 + 0.25 * sin(_time * 1.3 + float(_rows[i]) * 0.7))
		s.modulate = Color(glow, glow, glow, a)
		# лёгкое «дыхание» — фигуры чуть парят
		s.position = _base_pos[i] + Vector3(0, 0.012 * sin(_time * 0.6 + float(i) * 1.7), 0)
		# все фигуры светятся, свет медленно дышит у каждой по-своему
		var g := _glows[i]
		g.visible = s.visible
		g.position = s.position + _glow_offset[i]
		var breath := 0.85 + 0.15 * sin(_time * 0.18 + float(i) * 2.3)
		g.set_instance_shader_parameter("glow_strength", a * (glow_base + glow_shine * shine) * breath)
