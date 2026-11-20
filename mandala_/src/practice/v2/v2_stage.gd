extends RefCounted
## Общее для этапов новой версии практики: окна времени, подписи и смена фона.
## Этап задаёт TITLE, AUDIO, DURATION, CUES и apply(t, fx), как и этапы первой версии.

## Виды фона — как в sky_dome.gdshader и v2_extras.gd
enum Backdrop { SPACE, MOUNTAINS, OCEAN, GOLDEN }
## Сколько секунд один фон переходит в другой
const SKY_FADE := 3.0

func _win(t: float, a: float, b: float, fade_in: float, fade_out: float) -> float:
	return smoothstep(a, a + fade_in, t) * (1.0 - smoothstep(b - fade_out, b, t))

## captions — [[начало, конец, заголовок, текст], …]
func _captions(t: float, fx, captions: Array, fade := 1.0) -> void:
	fx.title = ""
	fx.text = ""
	fx.text_alpha = 0.0
	for c in captions:
		if t >= c[0] and t <= c[1]:
			fx.title = c[2]
			fx.text = c[3]
			fx.text_alpha = _win(t, c[0], c[1], fade, fade)
			return

## timeline — [[с какого момента, вид фона], …] по порядку; фоны сменяют друг друга с переходом SKY_FADE
func _sky(t: float, fx, timeline: Array) -> void:
	var current := 0
	for i in timeline.size():
		if t >= timeline[i][0]:
			current = i
	fx.sky_to = timeline[current][1]
	fx.sky_from = timeline[maxi(current - 1, 0)][1]
	fx.sky_blend = smoothstep(timeline[current][0], timeline[current][0] + SKY_FADE, t) if current > 0 else 1.0
