shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Камень
uniform vec4 stone_color : source_color = vec4(0.03, 0.025, 0.055, 1.0);
uniform vec4 stone_vein_color : source_color = vec4(0.13, 0.08, 0.17, 1.0);
uniform float stone_roughness : hint_range(0.0, 1.0) = 0.15;
uniform float stone_metallic : hint_range(0.0, 1.0) = 0.25;

// Золотой узор
uniform vec4 gold_color : source_color = vec4(1.0, 0.68, 0.25, 1.0);
uniform float gold_emission : hint_range(0.0, 10.0) = 1.2;
uniform float line_width : hint_range(0.005, 0.1) = 0.03;

// Тёплое свечение вокруг лотоса
uniform float center_glow : hint_range(0.0, 2.0) = 0.3;

// Анимация
uniform float rotation_speed = 0.015; // радиан в секунду
uniform float pulse_speed = 0.8;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.4;

// Размер пола и растворение краёв
uniform float fade_start = 5.5;
uniform float outer_radius = 9.5;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX.xz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

// Сглаженная линия толщиной w вдоль d == 0
float line(float d, float w) {
	float aa = fwidth(d);
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + aa * 1.5, abs(d));
}

// Радиус контура лепестка в направлении ang и производная по углу.
// n лепестков, основание на r0, высота h; pointed — острые или округлые.
vec2 petal_curve(float ang, float n, float r0, float h, bool pointed) {
	float x = 2.0 * fract(ang / TAU * n) - 1.0; // -1..1 поперёк лепестка
	float shape;
	float dshape;
	if (pointed) {
		float t = max(1.0 - abs(x), 1e-3);
		shape = sqrt(t);
		dshape = -sign(x) * 0.5 / sqrt(t);
	} else {
		float t = max(cos(x * PI * 0.5), 1e-3);
		shape = pow(t, 0.7);
		dshape = -0.7 * pow(t, -0.3) * sin(x * PI * 0.5) * PI * 0.5;
	}
	return vec2(r0 + h * shape, h * dshape * 2.0 * n / TAU);
}

// Линия контура лепестков с поправкой на крутизну, чтобы толщина была ровной
float petal_line(float r, vec2 curve, float w) {
	float slope = curve.y / max(r, 0.01);
	float grad = min(sqrt(1.0 + slope * slope), 40.0);
	return line((r - curve.x) / grad, w);
}

void fragment() {
	vec2 p = local_pos;
	float r = length(p);
	if (r > outer_radius) {
		discard;
	}
	float ang = atan(p.y, p.x) + TIME * rotation_speed;
	float w = line_width;

	float gold = 0.0;

	// Кольца вокруг лотоса
	gold += line(r - 2.65, w);
	gold += line(r - 2.80, w * 0.6);

	// Два ряда лепестков: округлые спереди, острые позади них
	vec2 inner = petal_curve(ang, 16.0, 2.80, 0.85, false);
	vec2 outer = petal_curve(ang + PI / 16.0, 16.0, 2.80, 1.45, true);
	gold += petal_line(r, inner, w);
	gold += petal_line(r, outer, w) * step(inner.x, r);

	gold += line(r - 4.40, w);
	gold += line(r - 4.55, w * 0.6);

	// Кольцо точек
	float n_dots = 48.0;
	float arc = (fract(ang / TAU * n_dots) - 0.5) * TAU / n_dots * r;
	float dot_d = length(vec2(arc, r - 5.0));
	gold += 1.0 - smoothstep(0.055, 0.055 + fwidth(dot_d) * 1.5, dot_d);

	// Лучи
	gold += line(r - 5.45, w * 0.6);
	float n_rays = 72.0;
	float ray = (fract(ang / TAU * n_rays) - 0.5) * TAU / n_rays * r;
	float ray_mask = smoothstep(5.5, 5.8, r) * (1.0 - smoothstep(7.4, 7.8, r));
	gold += line(ray, w * 0.5) * ray_mask;
	gold += line(r - 7.9, w);

	gold = clamp(gold, 0.0, 1.0);

	// Тёмный камень с прожилками
	float n1 = fbm(p * 0.8);
	float veins = 1.0 - abs(2.0 * fbm(p * 1.6 + n1 * 2.0) - 1.0);
	veins = pow(veins, 6.0);
	vec3 stone = mix(stone_color.rgb, stone_vein_color.rgb, veins);

	float glow = exp(-r * r / 6.0) * center_glow;
	// Волна света, расходящаяся от центра
	float pulse = 1.0 + pulse_strength * sin(TIME * pulse_speed - r * 0.9);

	ALBEDO = mix(stone, gold_color.rgb, gold);
	METALLIC = mix(stone_metallic, 1.0, gold);
	ROUGHNESS = mix(stone_roughness, 0.3, gold);
	EMISSION = gold_color.rgb * (gold * gold_emission * pulse + glow);
	ALPHA = 1.0 - smoothstep(fade_start, outer_radius, r);
}
