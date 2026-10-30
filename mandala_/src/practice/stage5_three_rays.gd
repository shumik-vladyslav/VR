extends RefCounted
## Этап 5. Три луча благословения: древо Прибежища растворяется в свете, проявляется объёмный Даттатрейя,
## и из него к практикующему идут три луча — белый в межбровье, красный в горло, синий в центр груди.

const TITLE := "5. Три луча благословения"
const AUDIO := "res://audio/teurgia1/three_rays.ogg"
const DURATION := 91.0

# Свет на месте древа: Даттатрейя появляется, когда свет в полную силу, к LIGHT_GONE свет гаснет
const DATTA_APPEARS := 5.0
const LIGHT_GONE := 11.5

# Где в записи говорится о каждом луче — текст этапа, озвученный синтезатором, выровнен с записью (DTW)
# и сверен с паузами в речи
const WHITE := 21.1
const RED := 31.9
const BLUE := 40.8
const TRANSMISSION := Vector2(58.0, 77.0)   # «процесс передачи духовной силы… нисхождение Ануграхи»
const NAMASTE := 80.0

const CUES := [0.0, WHITE, RED, BLUE, TRANSMISSION.x, NAMASTE]

# [начало, конец, заголовок, текст]
const CAPTIONS := [
	[1.0, 20.0, "Три луча благословения", "Из фигуры центрального божества — Бхагавана Даттатрейи — исходят три луча, насыщая наше духовное тело своим светом и силой."],
	[21.1, 31.0, "Белый луч", "Входит в межбровье и очищает карму тела."],
	[31.9, 40.0, "Красный луч", "Входит в горло и очищает карму речи."],
	[40.8, 56.5, "Синий луч", "Входит в центр груди, очищает карму ума, очищает сознание."],
	[58.0, 78.0, "Нисхождение Ануграхи", "Передача духовной силы от божеств Древа Прибежища — нисхождение просветляющей силы (шактипата)."],
	[80.0, 88.0, "", "Делаем намасте и поклон."],
]

func _win(t: float, a: float, b: float, fade_in: float, fade_out: float) -> float:
	return smoothstep(a, a + fade_in, t) * (1.0 - smoothstep(b - fade_out, b, t))

## Луч горит по очереди — только пока о нём говорится (до начала следующего), потом гаснет;
## в передаче силы загораются все три вместе и гаснут к намасте
func _ray(t: float, start: float, stop: float) -> float:
	var own := _win(t, start, stop, 2.0, 2.0)
	var together := _win(t, TRANSMISSION.x, NAMASTE + 3.0, 3.0, 4.0)
	return maxf(own, together)

func apply(t: float, fx) -> void:
	# Древо растворяется в ярком свете; в самом ярком месте появляется Даттатрейя (сразу целиком, его не видно),
	# потом свет гаснет и открывает его
	var dissolve := _win(t, 0.0, 9.0, 3.0, 4.0)
	fx.tree_reveal = 1.0 - smoothstep(1.5, 5.0, t)
	fx.tree_shine = 0.9 * dissolve
	fx.datta_light = _win(t, 0.5, LIGHT_GONE, 4.0, 5.5)
	fx.datta_reveal = 1.0 if t >= DATTA_APPEARS else 0.0
	fx.whiteout = 0.12 * pow(fx.datta_light, 2.0)
	# Сияние за Даттатрейей: ровное, сильнее в передаче силы, а в конце, когда лучи гаснут, — во всю силу
	var transmission := _win(t, TRANSMISSION.x, TRANSMISSION.y + 2.0, 3.0, 3.0)
	var finale := smoothstep(NAMASTE - 2.0, NAMASTE + 4.0, t)
	fx.aura = maxf(0.6 + 0.7 * dissolve, 0.9 + 0.4 * transmission + 1.3 * finale)

	fx.ray_white = _ray(t, WHITE, RED)
	fx.ray_red = _ray(t, RED, BLUE)
	fx.ray_blue = _ray(t, BLUE, TRANSMISSION.x + 2.0)   # синий не гаснет — к нему сразу добавляются белый и красный
	# заряды медленно плывут по лучам к практикующему (~0.6 м/с), в передаче силы — чуть быстрее
	fx.ray_phase = 0.5 * t + 0.25 * clampf(t - TRANSMISSION.x, 0.0, TRANSMISSION.y - TRANSMISSION.x)

	fx.title = ""
	fx.text = ""
	fx.text_alpha = 0.0
	for c in CAPTIONS:
		if t >= c[0] and t <= c[1]:
			fx.title = c[2]
			fx.text = c[3]
			fx.text_alpha = _win(t, c[0], c[1], 1.0, 1.0)
			break
