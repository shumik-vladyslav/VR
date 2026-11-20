extends "res://src/practice/v2/v2_stage.gd"
## Этап 10 новой версии. Запечатывание — завершающее подношение.
## Шамбхави-мудра, объединение внутреннего и внешнего; Четыре Безмерных — из центра груди Даттатрейи во все стороны
## исходит множество лучей, всё окружение начинает сиять, идёт дождь из цветов. Записи нет — тихий гул поющей чаши.

const TITLE := "10. Запечатывание"
const AUDIO := "res://audio/teurgia1_v2/bowl_drone.ogg"
const DURATION := 155.0

const SHAMBHAVI := Vector2(2.0, 28.0)
const UNITY := Vector2(28.0, 50.0)
const STATES := [50.0, 70.0, 90.0, 110.0]      # любовь, сострадание, сорадование, равностность
const SEAL := 132.0
const STATE_COLORS := [Color(1.0, 0.58, 0.62), Color(0.45, 0.72, 1.0), Color(1.0, 0.82, 0.3), Color(0.95, 0.97, 1.0)]

const CUES := [0.0, SHAMBHAVI.x, UNITY.x, 50.0, 70.0, 90.0, 110.0, SEAL]

const CAPTIONS := [
	[SHAMBHAVI.x, SHAMBHAVI.y - 0.5, "Шамбхави-мудра", "Вхождение в естественное состояние: глаза открыты, взгляд мягко направлен в пространство,\nум покоится сам в себе."],
	[UNITY.x, UNITY.y - 0.5, "Объединение внутреннего и внешнего", "Внутреннее и внешнее — одно сияющее пространство божества."],
	[50.0, 69.5, "Безмерная любовь — майтри", "Пусть все существа будут счастливы и обретут причины счастья."],
	[70.0, 89.5, "Безмерное сострадание — каруна", "Пусть все существа будут свободны от страдания и его причин."],
	[90.0, 109.5, "Безмерная радость — мудита", "Пусть все существа никогда не разлучаются с истинным счастьем.\nРадуемся счастью и благу каждого."],
	[110.0, SEAL - 0.5, "Безмерная равностность — упекша", "Пусть все существа пребывают в равностности, свободные от привязанности к близким\nи неприязни к далёким."],
	[SEAL, DURATION - 2.0, "", "Свет возвращается в слог в центре груди. Практика запечатана."],
]

func apply(t: float, fx) -> void:
	fx.datta_reveal = 1.0
	fx.merge = 1.0
	fx.whiteout = 0.14 * _win(t, SHAMBHAVI.x, SHAMBHAVI.y, 5.0, 5.0)
	var unity := smoothstep(UNITY.x, UNITY.y, t)
	fx.radiance = 0.3 + 0.3 * unity
	fx.body_glow = 0.5 + 0.4 * unity

	# Четыре Безмерных: лучи из груди Даттатрейи во все стороны, волны своего цвета, дождь цветов, всё сияет
	var i := -1
	for k in STATES.size():
		if t >= STATES[k]:
			i = k
	var shine := _win(t, STATES[0], SEAL + 6.0, 4.0, 8.0)
	fx.center_beams = 0.45 * shine
	fx.center_pulse = fmod(t, 5.0) / 5.0
	fx.aura = 1.0 + 0.4 * shine

	fx.sparkle = 0.9 * shine
	fx.petals = 1.0 if t >= STATES[0] and t < SEAL else 0.0
	fx.sky = 0.35 * shine
	_sky(t, fx, [[0.0, Backdrop.GOLDEN]])
	if i >= 0 and t < SEAL:
		fx.ring_phase = fmod(t - STATES[i], 4.5) / 4.5
		fx.ring_strength = 1.2 * shine
		fx.ring_color = STATE_COLORS[i]
	# запечатывание: свет возвращается в слог
	fx.rays_in = _win(t, SEAL, DURATION, 2.0, 4.0)
	fx.om_intensity = 0.5 * fx.rays_in
	_captions(t, fx, CAPTIONS)
