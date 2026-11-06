// Чеканное золото столов подношений: узор из лепестков лотоса на столешнице и блики металла.
// Блики рисуются самим шейдером: прожекторы в сцене без бликов (мигали в зеркальном полу), а настоящее отражение
// показывало тёмное небо и фиолетовый пол — золото выглядело ровным пластиком. Так оно одинаково и в Vulkan, и в OpenGL.
// Узор строится по координатам модели: столы — тела вращения вокруг оси Y, столешница на радиусах 0.23…0.41 м.
shader_type spatial;

#include "res://src/practice/gold_surroundings.gdshaderinc"

uniform vec3 gold : source_color = vec3(1.0, 0.77, 0.34);
// 1 — столешница с чеканкой, 0 — гладкая поверхность с лёгкой ковкой
uniform float chasing = 0.0;
// яркость бликов
uniform float shine = 1.0;
// 1 — точёная деталь с веерным бликом, 0 — без него (бусины)
uniform float turned = 1.0;

const float PETALS = 16.0;
const float BEADS = 96.0;
const float INNER = 0.25;
const float OUTER = 0.385;
const float BEAD_RING = 0.402;

varying vec3 model_pos;
varying vec3 model_normal;

void vertex() {
	model_pos = VERTEX;
	model_normal = NORMAL;
}

float hash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float band(float x, float center, float width) {
	return 1.0 - smoothstep(width * 0.4, width, abs(x - center));
}

// Рельеф столешницы: 1 — линия чеканки, 0 — ровное поле
float relief(float r, float angle) {
	float h = band(r, INNER - 0.012, 0.005) + band(r, OUTER + 0.004, 0.004);
	float t = clamp((r - INNER) / (OUTER - INNER), 0.0, 1.0);
	float inside = step(INNER, r) * step(r, OUTER);
	// лепестки: контур, сходящийся к острию у края, и жилка посередине
	float s = abs(fract(angle * PETALS / TAU) - 0.5);
	float petal_half = 0.47 * pow(1.0 - t, 0.6) * smoothstep(0.0, 0.14, t);
	h += inside * band(s, petal_half, 0.028);
	h += inside * band(s, 0.0, 0.016) * smoothstep(0.1, 0.25, t) * (1.0 - smoothstep(0.55, 0.75, t));
	// второй ряд — лепестки позади, в просветах между первыми
	float s2 = abs(fract(angle * PETALS / TAU + 0.5) - 0.5);
	float t2 = clamp((t - 0.3) / 0.7, 0.0, 1.0);
	float back_half = 0.3 * pow(1.0 - t2, 0.6);
	h += inside * step(petal_half, s) * step(0.3, t) * band(s2, back_half, 0.024);
	// ряд бусин вдоль края
	float cell = (fract(angle * BEADS / TAU) - 0.5) * (TAU * BEAD_RING / BEADS);
	h += 1.0 - smoothstep(0.0028, 0.0042, length(vec2(cell, r - BEAD_RING)));
	return min(h, 1.0);
}


void fragment() {
	float r = length(model_pos.xz);
	float angle = atan(model_pos.z, model_pos.x);
	vec3 radial = vec3(model_pos.x, 0.0, model_pos.z) / max(r, 0.0001);
	vec3 around = vec3(-radial.z, 0.0, radial.x);

	// только сверху столешницы
	float top = chasing * smoothstep(0.6, 0.9, model_normal.y);
	float step_r = 0.0012;
	float step_a = step_r / max(r, 0.02);
	float h = relief(r, angle) * top;
	float slope_r = (relief(r + step_r, angle) * top - h) / step_r;
	float slope_a = (relief(r, angle + step_a) * top - h) / step_r;

	// лёгкая ковка: поверхность чуть неровная, блик живой
	vec2 q = model_pos.xz * 60.0 + model_pos.y * 41.0;
	float hammer_x = noise(q + vec2(0.7, 0.0)) - noise(q - vec2(0.7, 0.0));
	float hammer_y = noise(q + vec2(0.0, 0.7)) - noise(q - vec2(0.0, 0.7));

	vec3 n = normalize(model_normal - (slope_r * radial + slope_a * around) * 0.006 + vec3(hammer_x, 0.0, hammer_y) * 0.05);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n, 0.0)).xyz);

	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 mirror_dir = reflect(-world_view, world_normal);
	float edge = pow(1.0 - clamp(dot(world_normal, world_view), 0.0, 1.0), 3.0);

	// точёный металл: блик расходится веером вдоль следов резца и поворачивается вслед за взглядом
	vec3 world_around = normalize((MODEL_MATRIX * vec4(around, 0.0)).xyz);
	vec3 half_dir = normalize(world_view + normalize(vec3(-0.3, 0.9, 0.32)));
	float along = dot(world_around, half_dir);
	float fan = pow(max(1.0 - along * along, 0.0), 90.0) * smoothstep(0.0, 0.3, dot(world_normal, half_dir));

	// в углублениях чеканки — тёмная патина, она и делает узор читаемым
	float patina = 1.0 - 0.6 * h;
	ALBEDO = gold * 0.4 * patina;
	METALLIC = 0.0;
	SPECULAR = 0.1;
	ROUGHNESS = 0.6;
	vec3 glint = mix(gold, vec3(1.0, 0.95, 0.85), 0.5) * 0.9 * fan * turned;
	EMISSION = (gold * surroundings(mirror_dir) * (0.6 + 0.5 * edge) + glint) * shine * patina;
}
