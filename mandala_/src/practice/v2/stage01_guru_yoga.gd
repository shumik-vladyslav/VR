extends "res://src/practice/v2/v2_stage.gd"
## Этап 1 новой версии. Гуру-йога с Ом: призывание и впитывание мудрости святых.
## Чистое голубое пространство, в центре — золотой светящийся слог Ом. На каждом пропетом Ом слог излучает свет:
## первый — волна света во все стороны, второй — свет собирается в сердце практикующего, третий — свет растворяет всё.

const TITLE := "1. Гуру-йога с Ом"
const AUDIO := "res://audio/teurgia1_v2/01_three_om.mp3"
const DURATION := 36.0

# Пропетые Ом в записи (по громкости)
const OM1 := Vector2(1.4, 9.2)
const OM2 := Vector2(12.3, 20.1)
const OM3 := Vector2(23.7, 31.4)

const CUES := [0.0, OM2.x - 0.5, OM3.x - 0.5]

const CAPTIONS := [
	[0.3, OM1.y + 1.5, "ОМ", "Первый Ом: из слога волна света исходит во все стороны."],
	[OM2.x - 0.5, OM2.y + 1.5, "ОМ", "Второй Ом: свет собирается в вашем сердце."],
	[OM3.x - 0.5, DURATION, "ОМ", "Третий Ом: свет растворяет всё в пространстве."],
]

func apply(t: float, fx) -> void:
	# только пространство и слог: ни древа, ни Даттатрейи, ни пола
	fx.sky = 1.0
	_sky(t, fx, [[0.0, Backdrop.SPACE]])
	fx.floor_visible = 0.0
	fx.tree_reveal = 0.0

	var om_on := smoothstep(0.0, 1.5, t) * (1.0 - smoothstep(OM3.x + 2.0, OM3.y, t))
	var chant := maxf(_win(t, OM1.x, OM1.y + 0.8, 1.0, 1.5), maxf(_win(t, OM2.x, OM2.y + 0.8, 1.0, 1.5), _win(t, OM3.x, OM3.y, 1.0, 1.5)))
	fx.center_om = om_on * (0.7 + 0.3 * chant)
	fx.center_halo = om_on * (0.25 + 0.6 * chant)

	# первый Ом: лучи и волна света бегут от слога во все стороны
	var first := _win(t, OM1.x, OM1.y + 1.5, 1.0, 2.0)
	fx.center_rays = 0.8 * first
	fx.center_beams = 0.7 * first
	fx.center_pulse = fmod(t - OM1.x, 3.0) / 3.0 if first > 0.01 else -1.0

	# второй Ом: свет собирается к практикующему — кольцо света сжимается к груди, в груди загорается Ом
	var second := _win(t, OM2.x, OM2.y + 1.5, 1.0, 2.0)
	if second > 0.01:
		fx.ring_phase = 0.45 * (1.0 - fmod(t - OM2.x, 2.6) / 2.6)
		fx.ring_strength = 1.4 * second
		fx.ring_color = Color(1.0, 0.86, 0.55)
	fx.rays_in = second
	fx.om_intensity = 0.8 * smoothstep(OM2.x + 2.0, OM2.y, t) * (1.0 - smoothstep(OM3.x + 3.0, OM3.y, t))
	fx.om_halo = fx.om_intensity

	# третий Ом: свет заполняет всё — следующий этап выходит из этого света
	fx.whiteout = smoothstep(OM3.x + 1.0, OM3.y, t)

	_captions(t, fx, CAPTIONS)
