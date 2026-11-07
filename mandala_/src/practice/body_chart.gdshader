// Схема тела к садхане 21-го слога Ом (practice_fx.gd): контур человека, светится названная таттва.
// part — номер таттвы 1…21: органы действия (1–5), органы чувств (6–10), энергии (11–15), оболочки (16–20), всё целиком (21).
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform int part = 0;
uniform float alpha = 0.0;
// 0..1 — звучит Ом, свет ярче
uniform float pulse = 0.0;
uniform vec3 line_color : source_color = vec3(0.96, 0.8, 0.45);
uniform vec3 light_color : source_color = vec3(1.0, 0.93, 0.7);

float capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)) - r;
}

float blend(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// руки и ноги симметричны: считаем на положительной стороне
float arms(vec2 p) {
	vec2 q = vec2(abs(p.x), p.y);
	float d = capsule(q, vec2(0.19, 0.44), vec2(0.28, 0.14), 0.055);
	d = blend(d, capsule(q, vec2(0.28, 0.14), vec2(0.32, -0.14), 0.045), 0.02);
	return blend(d, length(q - vec2(0.33, -0.2)) - 0.05, 0.02);
}

float legs(vec2 p) {
	vec2 q = vec2(abs(p.x), p.y);
	float d = capsule(q, vec2(0.085, -0.1), vec2(0.1, -0.5), 0.075);
	d = blend(d, capsule(q, vec2(0.1, -0.5), vec2(0.11, -0.8), 0.055), 0.02);
	return blend(d, capsule(q, vec2(0.11, -0.85), vec2(0.17, -0.87), 0.035), 0.02);
}

float head(vec2 p) {
	return length((p - vec2(0.0, 0.72)) * vec2(1.0, 0.88)) - 0.125;
}

float neck(vec2 p) {
	return capsule(p, vec2(0.0, 0.6), vec2(0.0, 0.52), 0.05);
}

float chest(vec2 p) {
	return capsule(p, vec2(0.0, 0.42), vec2(0.0, 0.26), 0.165);
}

float belly(vec2 p) {
	return capsule(p, vec2(0.0, 0.2), vec2(0.0, 0.08), 0.135);
}

float pelvis(vec2 p) {
	return capsule(p, vec2(-0.06, -0.02), vec2(0.06, -0.02), 0.105);
}

float body(vec2 p) {
	float d = blend(head(p), neck(p), 0.03);
	d = blend(d, chest(p), 0.04);
	d = blend(d, belly(p), 0.05);
	d = blend(d, pelvis(p), 0.05);
	d = blend(d, arms(p), 0.03);
	return blend(d, legs(p), 0.03);
}

float fill(float d) {
	return 1.0 - smoothstep(-0.006, 0.006, d);
}

// Насколько светится точка p для таттвы n
float tattva(int n, vec2 p, float d) {
	vec2 q = vec2(abs(p.x), p.y);
	if (n == 1 || n == 7) return fill(capsule(p, vec2(-0.035, 0.65), vec2(0.035, 0.65), 0.013));
	if (n == 2) return fill(arms(p));
	if (n == 3) return fill(legs(p));
	if (n == 4) return fill(length(p - vec2(0.0, -0.09)) - 0.05);
	if (n == 5) return fill(length(p - vec2(0.0, 0.0)) - 0.075);
	if (n == 6) return fill(capsule(p, vec2(0.0, 0.725), vec2(0.0, 0.685), 0.014));
	if (n == 8) return fill(length(q - vec2(0.05, 0.745)) - 0.02);
	if (n == 9) return fill(length(q - vec2(0.133, 0.715)) - 0.022);
	if (n == 10 || n == 15) return 1.0 - smoothstep(0.012, 0.03, abs(d));
	if (n == 11) return fill(d) * (1.0 - smoothstep(0.02, 0.05, p.y));
	if (n == 12) return fill(belly(p));
	if (n == 13) return fill(chest(p));
	if (n == 14) return fill(min(head(p), neck(p)));
	if (n == 16) return fill(d);
	if (n >= 17 && n <= 20) {
		// оболочки всё шире вокруг тела; уже пройденные остаются мягким контуром
		float reach = 0.06 * float(n - 16);
		float ring = 1.0 - smoothstep(0.008, 0.02, abs(d - reach));
		return max(ring, 0.35 * fill(d - reach));
	}
	if (n == 21) return max(fill(d), exp(-max(d, 0.0) * 9.0));
	return 0.0;
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * vec2(1.64, 2.4);
	float d = body(p);
	float line = 1.0 - smoothstep(0.004, 0.011, abs(d));
	float inside = fill(d);
	// сама точка мала, поэтому вокруг неё мягкий ореол: иначе глаза и нос не разглядеть
	float light = tattva(part, p, d);
	float halo = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854;
		halo += tattva(part, p + vec2(cos(a), sin(a)) * 0.035, d);
	}
	halo /= 8.0;
	float glow = clamp(light + 0.6 * halo, 0.0, 1.0) * (0.7 + 0.3 * pulse);

	// тёмная подложка: схема читается и поверх яркого сияния
	vec2 e = (UV - 0.5) * 2.0;
	float back = 0.62 * (1.0 - smoothstep(0.72, 1.0, length(e)));
	vec3 col = mix(vec3(0.05, 0.04, 0.12), line_color * 0.35, inside * 0.5);
	col = mix(col, line_color, line);
	col = mix(col, light_color * (1.0 + 0.6 * pulse), glow);
	ALBEDO = col;
	// свет и оболочки растворяются к краям квада, иначе виден его срез
	float rim = 1.0 - smoothstep(0.82, 1.0, max(abs(e.x), abs(e.y)));
	ALPHA = clamp(max(back, max(line, max(inside * 0.5, glow))), 0.0, 1.0) * alpha * rim;
}
