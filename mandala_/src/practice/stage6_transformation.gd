extends RefCounted
## Этап 6. Преображение в божество медитации: Даттатрейя остаётся на лотосе, а практикующий под волной
## благословений преображается в божество медитации без атрибутов — «маленького Даттатрейю»: одна голова,
## две руки, юный, с иконописными чертами. Каждый элемент тела сияет: земля — кожа, вода — глаза,
## огонь — свет из тела, воздух — аура. Опустив взгляд, он видит своё тело, в зеркале из света — себя целиком.

const TITLE := "6. Преображение в божество медитации"
const AUDIO := "res://audio/teurgia1/transformation.ogg"
const DURATION := 187.0

# Моменты — по распознанной записи (Whisper)
const TRANSFORM := Vector2(6.4, 16.0)     # «ваше тело начинает преображаться… в божество медитации» — во вспышке
const MIRROR := Vector2(31.2, 182.0)      # «красивый облик, иконописные черты лица…» — зеркало
const ELEMENTS := 51.2                    # «каждый элемент вашего тела сияет»
const EARTH := 58.9                       # земля — стройные мышцы и гладкая кожа
const WATER := 65.6                       # вода — лучащиеся глаза
const FIRE := 73.9                        # огонь — свет из тела
const AIR := 82.1                         # воздух — красивая аура
const I_AM := Vector2(108.8, 124.3)       # «Я — Даттатрейя. Ахам Брахмасми. Я есть сама Божественность»
const READY := 179.5                      # «теперь мы готовы призвать Даттатрейю»

const CUES := [0.0, TRANSFORM.x, MIRROR.x, ELEMENTS, I_AM.x, 131.3]
# Подписей нет — всё говорится в записи

func _win(t: float, a: float, b: float, fade_in: float, fade_out: float) -> float:
	return smoothstep(a, a + fade_in, t) * (1.0 - smoothstep(b - fade_out, b, t))

func apply(t: float, fx) -> void:
	# Даттатрейя на лотосе в сиянии — всё время этапа
	fx.datta_reveal = 1.0
	fx.aura = 0.9

	# волна света нарастает и заполняет взгляд; в самом ярком месте — преображение, потом свет рассеивается
	fx.merge = 1.0 if t >= TRANSFORM.y else 0.0
	var rise := smoothstep(TRANSFORM.x, TRANSFORM.y - 1.0, t)
	var settle := 1.0 - smoothstep(TRANSFORM.y + 0.5, TRANSFORM.y + 5.0, t)
	fx.whiteout = 0.97 * rise * settle

	# «Я — Даттатрейя…» — всё сияние в полную силу
	var i_am := _win(t, I_AM.x, I_AM.y + 4.0, 3.0, 5.0)
	# стихии загораются одна за другой и остаются
	var earth := smoothstep(EARTH, EARTH + 3.0, t)
	var water := smoothstep(WATER, WATER + 2.5, t)
	var fire := smoothstep(FIRE, FIRE + 3.0, t)
	var air := smoothstep(AIR, AIR + 4.0, t)
	var base := smoothstep(TRANSFORM.y, TRANSFORM.y + 4.0, t)   # лёгкое сияние сразу после преображения
	fx.radiance = 0.25 * base + 0.35 * earth + 0.4 * i_am
	fx.eyes_glow = 0.6 * water + 0.3 * i_am
	fx.body_light = 0.7 * fire + 0.5 * i_am
	fx.body_glow = 0.35 * base + 0.65 * air + 0.5 * i_am
	fx.mirror = _win(t, MIRROR.x, MIRROR.y, 4.0, 5.0)

	fx.title = ""
	fx.text = ""
	fx.text_alpha = 0.0
