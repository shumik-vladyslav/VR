extends Node3D
## Древо Прибежища из вырезанных фигур (images/refuge_tree/parts + parts.json).
## Ряды стоят на разной глубине: верх древа дальше, линия передачи ближе. Каждая фигура сдвигается
## вдоль луча от камеры, поэтому с места практикующего композиция совпадает с картинкой,
## а в VR при движении головы видна глубина.

const PARTS_DIR := "res://images/refuge_tree/parts/"
const PARTS_JSON := "res://images/refuge_tree/parts.json"

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
