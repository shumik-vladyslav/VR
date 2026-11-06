extends Node3D
## Древо Прибежища из вырезанных фигур (images/refuge_tree/parts + parts.json).
## Ряды стоят на разной глубине: верх древа дальше, линия передачи ближе. Каждая фигура сдвигается
## вдоль луча от камеры, поэтому с места практикующего композиция совпадает с картинкой,
## а в VR при движении головы видна глубина.

const PARTS_DIR := "res://images/refuge_tree/parts/"
const PARTS_JSON := "res://images/refuge_tree/parts.json"
## Разметка вырезания: где центр и радиус круга каждого медальона
const LAYOUT_JSON := "res://images/refuge_tree/layout.json"
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
## Подсветка рядов, о которых говорит ведущий: номер ряда (0 — верх) -> 0..1
var focus := {}
## Центральный Даттатрейя растёт и выходит вперёд (0..1) к точке grow_target; остальные фигуры гаснут (others 1 → 0)
var grow := 0.0
var grow_target := Vector3.ZERO
var others := 1.0
const GROW_ID := "datta"
const GROW_SCALE := 2.6

var _sprites: Array[Sprite3D] = []
var _rows: Array[int] = []
var _base_pos: Array[Vector3] = []
var _base_pixel: Array[float] = []
var _glows: Array[MeshInstance3D] = []
var _glow_offset: Array[Vector3] = []
var _row_count := 1
var _time := 0.0
var _was_shown := true

func build(camera_position: Vector3) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARTS_JSON))
	var circles := {}
	for item in JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_JSON))["items"]:
		circles[item["id"]] = item
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
		_base_pixel.append(s.pixel_size)

		# лучи сияния чуть позади фигуры (дальше от камеры); фигура занимает ~57% радиуса квада (figure_radius в шейдере)
		var g := MeshInstance3D.new()
		var q := QuadMesh.new()
		var size := maxf(float(p["w"]), float(p["h"])) * s.pixel_size * 1.75
		q.size = Vector2(size, size)
		g.mesh = q
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		g.material_override = mat
		# у медальона сияние идёт от круга, а не от всей картинки: ниже круга в ней подставка или пустое поле
		var item: Dictionary = circles.get(p["id"], {})
		if item.get("mode", "") == "circle":
			mat.set_shader_parameter("center_offset", Vector2(item["cx"] - p["cx"], p["cy"] - item["cy"]) * s.pixel_size)
			mat.set_shader_parameter("figure_radius", 2.0 * (item["r"] + 1.0) * s.pixel_size / size)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mat.set_shader_parameter("figure_seed", fmod(float(_sprites.size()) * 0.618034, 1.0))
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

## Мировые позиции всех фигур — куда летят подношения
func figure_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for s in _sprites:
		out.append(s.global_position)
	return out

func _process(delta: float) -> void:
	_time += delta
	# пока древа нет, 100 с лишним узлов каждый кадр не трогаем (один проход — чтобы скрыть их)
	var shown := reveal > 0.0
	if shown or _was_shown:
		apply()
	_was_shown = shown

func apply() -> void:
	# пока о каком-то ряде говорят, остальные чуть приглушены — так видно, о ком речь
	var any_focus := 0.0
	for v in focus.values():
		any_focus = maxf(any_focus, v)
	for i in _sprites.size():
		var s := _sprites[i]
		# всё древо проявляется разом — так края вырезанных фигур меньше заметны
		var a := smoothstep(0.0, 1.0, reveal)
		var growing := s.name == GROW_ID and grow > 0.0
		if not growing:
			a *= others
		s.visible = a > 0.002
		if not s.visible:
			_glows[i].visible = false
			continue
		var f: float = focus.get(_rows[i], 0.0)
		var glow := 1.0 + 0.3 * shine * (0.75 + 0.25 * sin(_time * 1.3 + float(_rows[i]) * 0.7)) + 0.35 * f
		glow *= 1.0 - 0.4 * any_focus * (1.0 - f)
		s.modulate = Color(glow, glow, glow, a)
		# лёгкое «дыхание» — фигуры чуть парят; названный ряд чуть крупнее
		s.position = _base_pos[i] + Vector3(0, 0.012 * sin(_time * 0.6 + float(i) * 1.7), 0)
		s.pixel_size = _base_pixel[i] * (1.0 + 0.12 * f)
		if growing:
			var e := grow * grow * (3.0 - 2.0 * grow)
			s.global_position = s.global_position.lerp(grow_target, e)
			s.pixel_size = _base_pixel[i] * lerpf(1.0, GROW_SCALE, e)
		# все фигуры светятся, свет медленно дышит у каждой по-своему; названный ряд — ярко
		var g := _glows[i]
		g.visible = s.visible
		g.position = s.position + _glow_offset[i]
		g.scale = Vector3.ONE * (s.pixel_size / _base_pixel[i])
		var breath := 0.85 + 0.15 * sin(_time * 0.18 + float(i) * 2.3)
		var dim := 1.0 - 0.6 * any_focus * (1.0 - f)
		(g.material_override as ShaderMaterial).set_shader_parameter("glow_strength", a * (glow_base + glow_shine * shine + 1.4 * f) * breath * dim)
