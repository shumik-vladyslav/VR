extends RefCounted
## Этап 9. Посвящение заслуг. Из слога Ом в центре груди золотые волны света несут заслугу практики
## всем существам; Даттатрейя отвечает — его свет расходится во все стороны; мир и поклон.
## Записи пока нет: время условное, ведут подписи. Когда появится запись — задать AUDIO и сверить моменты.

const TITLE := "9. Посвящение заслуг"
const AUDIO := ""
const DURATION := 75.0

const DEDICATE := Vector2(1.0, 42.0)     # волны заслуги от груди ко всем существам
const BLESSING := Vector2(20.0, 50.0)    # свет Даттатрейи расходится во все стороны
const SHANTI := Vector2(42.0, 58.0)      # «Ом шанти», намасте и поклон
const RING_PERIOD := 5.0
const PULSE_PERIOD := 6.0
const GOLD := Color(1.0, 0.84, 0.5)

const CUES := [0.0, BLESSING.x, SHANTI.x, SHANTI.y]

# [начало, конец, заголовок, текст]
const CAPTIONS := [
	[1.0, 19.5, "Посвящение заслуг", "Всю заслугу, накопленную в этой практике, мы посвящаем благу всех живых существ.\nПусть она станет причиной их пробуждения и освобождения."],
	[20.0, 41.5, "Лока самаста сукхино бхаванту", "Пусть все существа во всех мирах будут счастливы."],
	[42.0, 57.5, "Ом шанти, шанти, шанти", "Мир — в теле, мир — в речи, мир — в уме.\nСложите руки в намасте и поклонитесь."],
	[59.0, 74.0, "Практика завершена", "Тантрическая теургия 1"],
]

func _win(t: float, a: float, b: float, fade_in: float, fade_out: float) -> float:
	return smoothstep(a, a + fade_in, t) * (1.0 - smoothstep(b - fade_out, b, t))

func apply(t: float, fx) -> void:
	fx.datta_reveal = 1.0
	fx.merge = 1.0

	# Заслуга: золотой Ом в груди, лучи и волны света ко всем существам
	var dedicate := _win(t, DEDICATE.x, DEDICATE.y, 3.0, 5.0)
	fx.om_intensity = _win(t, 0.0, SHANTI.y, 2.0, 8.0) * (0.6 + 0.3 * dedicate)
	fx.om_halo = fx.om_intensity * 0.8
	fx.rays_out = 1.2 * dedicate
	fx.rays_tint = Color(GOLD.r, GOLD.g, GOLD.b, 0.85)
	if t < DEDICATE.y:
		fx.ring_phase = fmod(t, RING_PERIOD) / RING_PERIOD
		fx.ring_strength = 1.2 * dedicate
		fx.ring_color = GOLD

	# Даттатрейя отвечает: его свет расходится волнами во все стороны и к практикующему
	var blessing := _win(t, BLESSING.x, BLESSING.y, 4.0, 6.0)
	fx.center_beams = 0.25 * blessing
	fx.center_pulse = fmod(t - BLESSING.x, PULSE_PERIOD) / PULSE_PERIOD if t > BLESSING.x else -1.0

	# Искры чистого видения понемногу гаснут, всё затихает в ровном сиянии
	fx.sparkle = 0.6 * (1.0 - smoothstep(SHANTI.x, SHANTI.y + 6.0, t))
	var shanti := _win(t, SHANTI.x, SHANTI.y + 6.0, 4.0, 8.0)
	fx.aura = 1.0 + 0.4 * blessing + 0.3 * shanti
	fx.radiance = 0.3 + 0.2 * dedicate
	fx.body_glow = 0.5 + 0.3 * dedicate + 0.2 * shanti

	fx.title = ""
	fx.text = ""
	fx.text_alpha = 0.0
	for c in CAPTIONS:
		if t >= c[0] and t <= c[1]:
			fx.title = c[2]
			fx.text = c[3]
			fx.text_alpha = _win(t, c[0], c[1], 1.0, 1.0)
			break
