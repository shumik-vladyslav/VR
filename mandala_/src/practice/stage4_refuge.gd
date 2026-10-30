extends RefCounted
## Этап 4. Прибежище: снова древо Прибежища; во время пения мантры Прибежища святые мягко сияют.

const TITLE := "4. Прибежище"
const AUDIO := "res://audio/teurgia1/refuge.ogg"
const DURATION := 237.0

# Где в записи поётся мантра «Намо Гурудэва…» — по огибающей громкости
const SUNG := Vector2(159.0, 196.0)

const CUES := [0.0, 80.0, 159.0, 197.0]

const REFUGE_MANTRA := "НАМО  ГУРУДЭВА\nНАМО  САТЬЯ  ДХАРМА\nНАМО  АРЬЯ  САНГХА"

# [начало, конец, заголовок, текст]
const CAPTIONS := [
	[1.0, 79.0, "Древо Прибежища", "Канал связи с божественными существами и святыми высших измерений — опора, защита и источник духовной силы."],
	[80.0, 157.5, "Древо Прибежища", "В центре — Бхагаван Даттатрейя, изначальный Учитель человечества. Настройтесь на энергию святых и божеств, почувствуйте их мудрость и сострадание, зародите веру и преданность."],
	[159.0, 197.0, "Мантра Прибежища", REFUGE_MANTRA],
	[198.0, 236.0, "", "Я принимаю Прибежище в Гуру.\nЯ принимаю Прибежище в Дхарме.\nЯ принимаю Прибежище в Сангхе."],
]

func _win(t: float, a: float, b: float, fade_in: float, fade_out: float) -> float:
	return smoothstep(a, a + fade_in, t) * (1.0 - smoothstep(b - fade_out, b, t))

func apply(t: float, fx) -> void:
	# Древо снова проявляется (после большого Ома этапа 3) и остаётся
	var tree := smoothstep(0.0, 4.0, t)
	fx.tree_reveal = tree

	# Лёгкое сияние, пока поётся мантра Прибежища
	var sing := _win(t, SUNG.x, SUNG.y + 1.5, 3.0, 4.0)
	fx.tree_shine = 0.5 * sing
	fx.aura = tree * (0.6 + 0.3 * sing)

	fx.title = ""
	fx.text = ""
	fx.text_alpha = 0.0
	for c in CAPTIONS:
		if t >= c[0] and t <= c[1]:
			fx.title = c[2]
			fx.text = c[3]
			fx.text_alpha = _win(t, c[0], c[1], 1.0, 1.0)
			break
