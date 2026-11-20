extends "res://src/practice/v2/v2_stage.gd"
## Этап 4 новой версии. Прибежище: перед практикующим проявляется древо Прибежища, его центральная фигура —
## Даттатрейя — выходит вперёд и становится объёмным в мягком золотом свете. С мантрой Прибежища от него
## к практикующему исходят три луча: белый — в межбровье, красный — в горло, синий — в сердце.

const TITLE := "4. Прибежище"
const AUDIO := "res://audio/teurgia1_v2/04_refuge_mantra.mp3"
const DURATION := 54.0

const TREE := Vector2(0.5, 4.0)          # «Теперь представляем древо Прибежища»
const GROW := Vector2(4.5, 9.0)          # центральная фигура выходит вперёд
const DATTA_APPEARS := 9.5
# Строки мантры в записи — каждая зажигает свой луч
const WHITE := 9.9
const RED := 23.6
const BLUE := 36.8
const MANTRA_END := 49.4

const CUES := [0.0, WHITE, RED, BLUE]

const REFUGE_MANTRA := "Намо Гурудэва,\nнамо Сатья Дхарма,\nнамо Арья Сангха"

const CAPTIONS := [
	[0.5, WHITE - 0.5, "Прибежище", "Представляем древо Прибежища. Его центральная фигура — Даттатрейя — выходит вперёд в мягком золотом свете."],
	[WHITE - 0.5, DURATION, "Мантра Прибежища", REFUGE_MANTRA + "\n\nПочтение Гуру, почтение истинной Дхарме, почтение благородной Сангхе.\nБелый луч — в межбровье, красный — в горло, синий — в сердце."],
]

func apply(t: float, fx) -> void:
	var tree := smoothstep(TREE.x, TREE.y, t)
	fx.tree_reveal = tree if t < DATTA_APPEARS else 0.0
	fx.tree_others = 1.0 - smoothstep(GROW.x + 0.5, GROW.y, t)
	fx.tree_grow = smoothstep(GROW.x, GROW.y, t)
	fx.datta_light = _win(t, DATTA_APPEARS - 2.0, DATTA_APPEARS + 4.0, 2.0, 3.0)
	fx.datta_reveal = 1.0 if t >= DATTA_APPEARS else 0.0
	fx.whiteout = 0.1 * pow(fx.datta_light, 2.0)
	fx.aura = 0.5 * tree + 0.9 * smoothstep(DATTA_APPEARS, DATTA_APPEARS + 3.0, t)

	# лучи загораются по строкам мантры и остаются до конца
	var fade := 1.0 - smoothstep(MANTRA_END + 1.0, DURATION, t)
	fx.ray_white = smoothstep(WHITE, WHITE + 2.0, t) * fade
	fx.ray_red = smoothstep(RED, RED + 2.0, t) * fade
	fx.ray_blue = smoothstep(BLUE, BLUE + 2.0, t) * fade
	fx.ray_phase = 0.5 * t
	_captions(t, fx, CAPTIONS)
