extends "res://src/practice/v2/v2_stage.gd"
## Этап 6 новой версии. Призывание божества мудрости — Датта Става — и манасика-пуджа.
## Даттатрейя сияет величественно в мандале света, на него сыплется дождь из лепестков. Во время стотры —
## подношение пяти элементов, у каждого свой фон: земля — горы, пространство — голубое, воздух — благовония,
## огонь — пространство в искрах, вода — океан. Столы с подношениями стоят рядом (offering.gd).

const TITLE := "6. Призывание божества мудрости"
const AUDIO := "res://audio/teurgia1_v2/06_datta_stava.mp3"
const DURATION := 165.0
const PUJA := true

const INVOCATION := Vector2(0.0, 13.0)      # Шри Ганешая намах… — перед стотрой
const CLOSING := Vector2(137.0, 162.0)      # те же призывания после стотры
# Куплеты стотры по записи (первая версия: stage7_datta_stava.gd, тот же порядок)
const VERSE_AT := [13.0, 28.0, 41.0, 54.0, 67.0, 80.0, 94.0, 108.0, 122.0, 137.0]
const DattaStava := preload("res://src/practice/stage7_datta_stava.gd")

# Пять элементов: с какого куплета, фон, мантра, что делаем
const ELEMENTS := [
	[0, Backdrop.MOUNTAINS, "Земля", "Ом Лам притхиви атмане гандхам самарпаями",
		"Лепесток с ароматным маслом: к межбровью, к правой и левой руке, круговое движение, вдохнуть аромат."],
	[2, Backdrop.SPACE, "Пространство", "Ом Хам акаша атмане пушпани пуджаями",
		"Поднос с лепестками: круговое движение — всё пространство заполняется лепестками."],
	[4, Backdrop.SPACE, "Воздух", "Ом Йам вайю атмане дхупам агхрапаями",
		"Благовонные палочки: круговое движение — дым благовоний заполняет пространство."],
	[6, Backdrop.GOLDEN, "Огонь", "Ом Рам агни атмане дипам сандаршаями",
		"Лампа с огнём: круговое подношение — пространство наполняется светящимися искрами."],
	[7, Backdrop.OCEAN, "Вода", "Ом Вам амрита атмане амрита найведьям самарпаями",
		"Чаша с йогуртом и поднос с махапрасадом: подношение с круговыми движениями."],
]

const CUES := [0.0, 13.0, 41.0, 67.0, 94.0, 108.0, 137.0]

func _element(t: float) -> int:
	var current := -1
	for i in ELEMENTS.size():
		if t >= VERSE_AT[ELEMENTS[i][0]]:
			current = i
	return current if t < CLOSING.x else -1

func apply(t: float, fx) -> void:
	# Даттатрейя на лотосе в мандале света; практикующий — в теле божества медитации
	fx.datta_reveal = 1.0
	fx.merge = 1.0
	fx.radiance = 0.3
	fx.body_glow = 0.4
	var stotra := _win(t, INVOCATION.y, CLOSING.x + 4.0, 3.0, 4.0)
	fx.aura = 1.0 + 0.5 * stotra
	fx.center_beams = 0.12 * stotra
	fx.center_pulse = fmod(t, 6.0) / 6.0
	fx.petals = 1.0 if t > INVOCATION.y and t < CLOSING.x else 0.0

	# фон элемента
	var e := _element(t)
	var timeline := [[0.0, Backdrop.GOLDEN]]
	for i in ELEMENTS.size():
		timeline.append([VERSE_AT[ELEMENTS[i][0]], ELEMENTS[i][1]])
	timeline.append([CLOSING.x, Backdrop.GOLDEN])
	_sky(t, fx, timeline)
	fx.sky = 0.85 * stotra + 0.25
	fx.sparkle = 0.8 if e == 3 else 0.2

	# подписи: куплет на санскрите, перевод и подношение текущего элемента
	fx.title = ""
	fx.text = ""
	fx.text_alpha = 0.0
	if t < INVOCATION.y:
		fx.title = "Призывание"
		fx.text = "Шри Ганешая намах · Шри Сарасватьяй намах\nШри Шрипада Шри Валлабха Нарасимха Сарасватьяй намах · Шри Гуру Даттатреяя намах"
		fx.text_alpha = _win(t, 0.5, INVOCATION.y, 1.0, 1.0)
		return
	if t >= CLOSING.x:
		fx.title = "Призывание"
		fx.text = "Шри Ганешая намах · Шри Сарасватьяй намах\nШри Шрипада Шри Валлабха Нарасимха Сарасватьяй намах · Шри Гуру Даттатреяя намах"
		fx.text_alpha = _win(t, CLOSING.x, DURATION, 1.0, 2.0)
		return
	for i in VERSE_AT.size() - 1:
		if t >= VERSE_AT[i] and t < VERSE_AT[i + 1]:
			var verse: Array = DattaStava.VERSES[i]
			fx.title = verse[2]
			fx.text = verse[3]
			if e >= 0:
				var el: Array = ELEMENTS[e]
				fx.text += "\n\n%s · %s\n%s" % [el[2], el[3], el[4]]
			fx.text_alpha = _win(t, VERSE_AT[i], VERSE_AT[i + 1], 1.0, 1.0)
			return
