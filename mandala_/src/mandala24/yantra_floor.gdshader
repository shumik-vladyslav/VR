// Пол мандалы 24 божеств — янтра как на иконе: квадрат-бхупура с Т-образными воротами на четыре стороны,
// два розовых круга и лотос. Полупрозрачный: под ним, внизу, виден Вишну (надир).
// Координаты — метры в плоскости пола (центр — Датта).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float half_size = 6.5;      // половина стороны квадрата
uniform float gate_half = 1.3;      // половина ширины ворот
uniform float gate_depth = 0.55;    // насколько ворота выступают
uniform float cap_half = 2.1;       // половина ширины перекладины «Т»
uniform float cap_depth = 0.22;
uniform vec4 fill_color : source_color = vec4(1.0, 0.94, 0.72, 1.0);
uniform vec4 frame_color : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform vec4 circle_color : source_color = vec4(1.0, 0.45, 0.78, 1.0);
uniform vec4 lotus_color : source_color = vec4(0.72, 0.55, 1.0, 1.0);
uniform float fill_alpha = 0.32;
uniform float reveal = 1.0;         // 0..1 — появление пола

varying vec2 p;

void vertex() {
	p = VERTEX.xz;
}

float box(vec2 q, vec2 c, vec2 b) {
	vec2 d = abs(q - c) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// тонкая линия по расстоянию d с шириной w (м), сглаженная по пикселю
float line(float d, float w) {
	float aa = max(fwidth(d), 1e-4);
	return 1.0 - smoothstep(w, w + aa, abs(d));
}

// контур лепестков: n заострённых лепестков от r0 до r1
float petals(vec2 q, float n, float r0, float r1, float phase, float w) {
	float r = length(q);
	float s = fract(atan(q.y, q.x) / 6.2831853 * n + phase);
	float u = abs(s - 0.5) * 2.0;                 // 0 — середина лепестка, 1 — стык
	float edge = r0 + (r1 - r0) * pow(1.0 - u, 0.75);
	return line(r - edge, w) * step(r0 - 0.05, r);
}

void fragment() {
	// симметрия: работаем в одном секторе (+X), остальные три стороны — отражения
	vec2 q = abs(p);
	if (q.y > q.x) q = q.yx;
	float d = box(q, vec2(0.0), vec2(half_size));
	d = min(d, box(q, vec2(half_size + gate_depth * 0.5, 0.0), vec2(gate_depth * 0.5 + 0.01, gate_half)));
	d = min(d, box(q, vec2(half_size + gate_depth + cap_depth * 0.5, 0.0), vec2(cap_depth * 0.5, cap_half)));

	float inside = 1.0 - smoothstep(0.0, max(fwidth(d), 1e-4), d);
	float frame = max(line(d, 0.07), line(d + 0.32, 0.035));
	float r = length(p);
	float circles = max(line(r - 5.75, 0.05), line(r - 5.45, 0.035));
	float lotus = max(petals(p, 8.0, 2.0, 5.1, 0.0, 0.05), petals(p, 8.0, 2.0, 4.0, 0.5, 0.04));
	lotus = max(lotus, line(r - 2.0, 0.04));
	// мягкий тёплый свет в центре, под Даттой
	float center = exp(-r * r / 6.0);

	float pulse = 0.9 + 0.1 * sin(TIME * 0.5);
	vec3 col = fill_color.rgb * (0.85 + 0.6 * center);
	float a = inside * fill_alpha * (0.6 + 0.4 * smoothstep(7.0, 2.0, r));
	col = mix(col, lotus_color.rgb, lotus * 0.8);
	a = max(a, lotus * 0.55);
	col = mix(col, circle_color.rgb * 1.2, circles);
	a = max(a, circles * 0.8);
	col = mix(col, frame_color.rgb * 1.4 * pulse, frame);
	a = max(a, frame * 0.9);
	a = max(a, center * 0.35 * inside);

	ALBEDO = col;
	ALPHA = a * reveal;
}
