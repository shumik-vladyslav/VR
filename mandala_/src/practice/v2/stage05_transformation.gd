extends "res://src/practice/v2/v2_stage.gd"
## Этап 5 новой версии. Преображение в иллюзорное тело божества — как этап 6 первой версии (та же запись),
## но после вспышки преображения радужный свет расходится по пространству кругами, как по воде.

const Base := preload("res://src/practice/stage6_transformation.gd")
const TITLE := "5. Преображение в иллюзорное тело божества"
const AUDIO := Base.AUDIO
const DURATION := Base.DURATION
const CUES := Base.CUES

const RIPPLES := Vector2(16.0, 34.0)
const RIPPLE_PERIOD := 3.0

var _base := Base.new()

func apply(t: float, fx) -> void:
	_base.apply(t, fx)
	if t >= RIPPLES.x and t < RIPPLES.y:
		var n := floorf((t - RIPPLES.x) / RIPPLE_PERIOD)
		fx.ring_phase = fmod(t - RIPPLES.x, RIPPLE_PERIOD) / RIPPLE_PERIOD
		fx.ring_strength = 1.5 * _win(t, RIPPLES.x, RIPPLES.y, 0.5, 4.0)
		fx.ring_color = Color.from_hsv(fmod(n * 0.17, 1.0), 0.55, 1.0)
