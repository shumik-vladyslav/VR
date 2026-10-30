# Снимок сцены Godot в PNG для проверки результата глазами.
# Запуск (окно откроется на пару секунд, рендер нужен настоящий, не --headless):
#   godot_console.exe --path <проект> --windowed -s <этот файл>
# Переменные окружения:
#   SCENE  — res://путь к сцене (обязательно)
#   OUT    — путь к PNG (обязательно)
#   CAM    — "x,y,z" позиция камеры в мире Godot (обязательно)
#   LOOK   — "x,y,z" куда смотреть (по умолчанию лицо Датты: 0,3.0,0)
#   ORTHO  — размер ортокамеры; если задан, камера ортографическая (вид сверху и т.п.)
#   STRIP  — имена узлов через запятую, которые удалить (по умолчанию "Menu,SelectableMenu")
#   FRAMES — сколько кадров ждать перед снимком (по умолчанию 40)
extends SceneTree

var frames := 0
var wait := 40

func _vec(name: String, fallback: Vector3) -> Vector3:
	var s := OS.get_environment(name)
	if s.is_empty():
		return fallback
	var p := s.split_floats(",")
	return Vector3(p[0], p[1], p[2])

func _init():
	var scene_path := OS.get_environment("SCENE")
	var scene: Node = load(scene_path).instantiate()
	# Скрипт корня (управление мышью, аудио) в снимке не нужен и требует автозагрузок
	scene.set_script(null)
	var strip := OS.get_environment("STRIP")
	if strip.is_empty():
		strip = "Menu,SelectableMenu"
	for n in strip.split(","):
		var node := scene.find_child(n, true, false)
		if node:
			node.free()
	get_root().add_child(scene)
	_scene = scene
	if not OS.get_environment("FRAMES").is_empty():
		wait = int(OS.get_environment("FRAMES"))

var _scene: Node

# Камера ставится на первом кадре: в _init сцена ещё не в дереве, и global_position/look_at не работают
func _setup_camera():
	var scene := _scene
	# Берём игровую камеру (на ней могут висеть прожекторы), иначе создаём свою
	var cam: Camera3D = scene.get_node_or_null("Gods/Datta/CameraOrigin/MainCamera")
	if cam == null:
		var found := scene.find_children("*", "Camera3D", true, false)
		cam = found[0] if found.size() > 0 else null
	if cam == null:
		cam = Camera3D.new()
		scene.add_child(cam)
	if not OS.get_environment("ORTHO").is_empty():
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(OS.get_environment("ORTHO"))
	var look := _vec("LOOK", Vector3(0, 3.0, 0))
	cam.global_position = _vec("CAM", Vector3(0, 3.05, 1.0))
	var up := Vector3.UP if absf(cam.global_position.direction_to(look).y) < 0.99 else Vector3.FORWARD
	cam.look_at(look, up)
	cam.current = true

func _process(_d):
	frames += 1
	if frames == 1:
		_setup_camera()
	if frames == wait:
		get_root().get_texture().get_image().save_png(OS.get_environment("OUT"))
		print("SHOT_SAVED ", OS.get_environment("OUT"))
		quit()
	return false
