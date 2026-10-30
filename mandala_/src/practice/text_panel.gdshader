// Подложка под текст: полупрозрачная тёмная плашка со скруглёнными углами и тонкой золотой рамкой.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec2 size = vec2(1.0, 0.3);       // размер плашки (м) — для скругления и рамки
uniform float radius = 0.05;
uniform float alpha_mul : hint_range(0.0, 1.0) = 1.0;
uniform vec4 bg : source_color = vec4(0.04, 0.03, 0.1, 0.62);
uniform vec4 border : source_color = vec4(1.0, 0.82, 0.45, 0.55);

void fragment() {
	vec2 p = (UV - 0.5) * size;
	vec2 q = abs(p) - size * 0.5 + radius;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float aa = fwidth(d);
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float line = 1.0 - smoothstep(0.0, aa * 1.5, abs(d + 0.006) - 0.0015);
	ALBEDO = mix(bg.rgb, border.rgb, line);
	ALPHA = clamp(inside * bg.a + line * border.a, 0.0, 1.0) * alpha_mul;
}
