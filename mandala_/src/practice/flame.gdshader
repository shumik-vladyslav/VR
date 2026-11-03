// Огонёк масляной лампы (puja_items.gd): капля пламени на квадрате, всегда лицом к камере, мерцает. Аддитивно.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity : hint_range(0.0, 4.0) = 1.4;
uniform float seed = 0.0;

void vertex() {
	// лицом к камере, но размер — от масштаба узла (лампа в руке маленькая, вокруг Даттатрейи — большая)
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	float y = 1.0 - UV.y;   // 0 — у фитиля, 1 — кончик
	float t = TIME * (7.0 + 2.0 * seed) + seed * 40.0;
	// пламя колышется: кончик гуляет сильнее основания
	float sway = (0.06 * sin(t) + 0.03 * sin(t * 2.3 + 1.7)) * y * y;
	float x = UV.x - 0.5 - sway;
	// капля: широкая внизу, острая вверху
	float w = 0.26 * pow(sin(3.14159 * clamp(pow(y, 0.7), 0.0, 1.0)), 0.8) * (1.0 - 0.35 * y);
	float body = 1.0 - smoothstep(w * 0.55, w, abs(x));
	body *= smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.82, 1.0, y));
	float core = (1.0 - smoothstep(0.0, w * 0.6, abs(x))) * (1.0 - smoothstep(0.15, 0.6, y)) * smoothstep(0.02, 0.1, y);
	float halo = exp(-pow(length(vec2(x, (y - 0.3) * 0.7)) / 0.3, 2.0)) * 0.25;
	float flicker = 0.85 + 0.15 * sin(t * 1.9) * sin(t * 0.7);
	vec3 col = vec3(1.0, 0.45, 0.08) * body + vec3(1.0, 0.9, 0.6) * core * 1.4 + vec3(1.0, 0.6, 0.2) * halo;
	ALBEDO = col * intensity * flicker;
}
