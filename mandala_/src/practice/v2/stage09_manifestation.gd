extends "res://src/practice/v2/v2_stage.gd"
## Этап 9 новой версии. Повторная манифестация в облике чистого иллюзорного тела.
## Из пространства снова возникает слог Драм, из него — Даттатрейя на лотосном троне, вокруг проявляется мандала
## и чистая земля в золотом свете. Записи нет — тихий гул поющей чаши.

const TITLE := "9. Повторная манифестация"
const AUDIO := "res://audio/teurgia1_v2/bowl_drone.ogg"
const DURATION := 125.0

const BIJA := Vector2(4.0, 22.0)         # из пространства возникает слог Драм
const DATTA_APPEARS := 22.0
const WORLD := Vector2(40.0, 58.0)       # пол мандалы и чистая земля
const PRIDE := 60.0
const MANDALA := 82.0

const CUES := [0.0, BIJA.x, DATTA_APPEARS, WORLD.x, PRIDE, MANDALA]

const CAPTIONS := [
	[1.0, DATTA_APPEARS - 0.5, "Зарождение биджа-слога", "В пространстве голубого света возникает слог Драм."],
	[DATTA_APPEARS, WORLD.x - 0.5, "Проявление в чистом иллюзорном теле", "Из слога проявляется Даттатрейя на лотосном троне. Вы выходите из пространства\nв чистом иллюзорном теле божества."],
	[WORLD.x, PRIDE - 0.5, "Соединение пространства и иллюзорного тела", "Иллюзорное тело соединяется с физическим пространством — сансара и нирвана едины."],
	[PRIDE, MANDALA - 0.5, "Гордость божества и чистое видение", "Твёрдая уверенность: «Я — божество». Всё вокруг — чистая земля."],
	[MANDALA, DURATION - 2.0, "Санкальпа чистого видения", "Медитация на внешний мир как на мандалу: дворец божества, чистая земля,\nвсе существа — божества, все звуки — мантра."],
]

func apply(t: float, fx) -> void:
	fx.merge = 1.0
	fx.body_glow = 0.5
	fx.radiance = 0.3
	# слог Драм на месте Даттатрейи, затем вспышка — и Даттатрейя
	fx.dram = _win(t, BIJA.x, DATTA_APPEARS + 1.0, 4.0, 3.0)
	fx.datta_light = _win(t, DATTA_APPEARS - 3.0, DATTA_APPEARS + 6.0, 3.0, 5.0)
	fx.datta_reveal = 1.0 if t >= DATTA_APPEARS else 0.0
	fx.whiteout = 0.15 * pow(fx.datta_light, 2.0)
	fx.aura = smoothstep(DATTA_APPEARS, DATTA_APPEARS + 6.0, t) * (0.9 + 0.4 * smoothstep(MANDALA, MANDALA + 8.0, t))
	# из голубого пространства — к золотой чистой земле; пол мандалы возвращается во вспышке
	fx.sky = 1.0 - 0.5 * smoothstep(WORLD.y, WORLD.y + 10.0, t)
	_sky(t, fx, [[0.0, Backdrop.SPACE], [WORLD.x, Backdrop.GOLDEN]])
	fx.floor_visible = 1.0 if t > WORLD.x + 2.0 else 0.0
	fx.mirror = _win(t, PRIDE, MANDALA + 6.0, 4.0, 5.0)
	fx.sparkle = 0.7 * smoothstep(MANDALA, MANDALA + 8.0, t)
	_captions(t, fx, CAPTIONS)
