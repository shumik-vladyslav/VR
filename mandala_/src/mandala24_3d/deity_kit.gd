extends RefCounted
## 3D-фигуры мандалы 24 божеств.
## Готовые модели: Датта (как в «Теургии 1»), Шива и его пять форм-Брахм. Остальные делаются на основе божества медитации по своим картинкам
## (images/mandala24/parts/<id>.png) и лежать в models/gods/mandala24_3d/<id>.glb — сцена подхватит файл сама.
## Пока модели нет, сцена ставит на это место картинку (как в мандале с картинками).

const KIT_DIR := "res://models/gods/mandala24_3d/"

## Датта — как в «Теургии 1»: несколько моделей в одной точке (со своим лотосом)
const DATTA_PARTS := [
	"res://models/gods/teurgia1/Shkura.glb",
	"res://models/gods/teurgia1/rose/rose.tscn",
	"res://models/gods/teurgia1/mala/mala.tscn",
	"res://models/gods/teurgia1/main/datta.tscn",
	"res://models/gods/teurgia1/others/chetki.tscn",
	"res://models/gods/teurgia1/others/lotos.tscn",
	"res://models/gods/teurgia1/others/tilaki.tscn",
]
## Шива и его формы — готовые модели (Шива из «Теургии 1», пять Брахм из «Мандалы 5»)
const READY := {
	"shiva": "res://models/gods/teurgia1/shiva/Shiva.tscn",
	"sadyojata": "res://models/gods/round1/sadjodjata/Sadjodzata.glb",
	"vamadeva": "res://models/gods/round1/vamadeva/Vamadeva.glb",
	"aghora": "res://models/gods/round1/aghora/Aghora.glb",
	"tatpurusha": "res://models/gods/round1/tatpurusha/Tatpurusha.glb",
	"ishana_brahma": "res://models/gods/round1/ishana/Ishana.glb",
}
## Основа для остальных божеств — божество медитации из «Теургии 1» (этап 6, src/practice/transformation.gd):
## копия Датты с одной головой и двумя руками, без атрибутов, на лотосе Датты
const Transformation := preload("res://src/practice/transformation.gd")
## Брахма в зените и Вишну в надире — те же фигуры
const SAME_AS := {"brahma_zenith": "brahma", "vishnu_nadir": "vishnu"}

static func model_path(id: String) -> String:
	return KIT_DIR + SAME_AS.get(id, id) + ".glb"

## Есть ли у божества 3D-фигура
static func has_model(id: String) -> bool:
	return id in ["datta", "meditation"] or READY.has(id) or _generated(id)

## Модель из нейросети по картинке (models/gods/mandala24_3d/<id>.glb) — главнее готовой из READY
static func _generated(id: String) -> bool:
	return ResourceLoader.exists(model_path(id))

## Все сцены, из которых собираются фигуры (сцена мандалы грузит их в фоне)
static func scene_paths(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		if id == "datta":
			out.append_array(DATTA_PARTS)
		elif _generated(id):
			if not out.has(model_path(id)):
				out.append(model_path(id))
		elif READY.has(id):
			out.append(READY[id])
	return out

## 3D-фигура божества или null, если её ещё нет
static func build(id: String) -> Node3D:
	if not has_model(id):
		return null
	var root := Node3D.new()
	root.name = id
	if id == "datta":
		for p in DATTA_PARTS:
			root.add_child((load(p) as PackedScene).instantiate())
	elif id == "meditation":
		for p in DATTA_PARTS:
			var part := (load(p) as PackedScene).instantiate() as Node3D
			root.add_child(part)
			Transformation.make_meditation_body(part)
	elif _generated(id):
		root.add_child((load(model_path(id)) as PackedScene).instantiate())
	else:
		root.add_child((load(READY[id]) as PackedScene).instantiate())
	return root

## Габариты всех видимых мешей узла (в его координатах)
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.is_queued_for_deletion() or not _visible_in(root, mi):
			continue
		var b := _local_xf(root, mi) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

static func _visible_in(root: Node3D, n: Node3D) -> bool:
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D and not (cur as Node3D).visible:
			return false
		cur = cur.get_parent()
	return true

static func _local_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
