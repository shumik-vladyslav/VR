// Фон новой версии практики (v2_extras.gd): сфера вокруг практикующего поверх неба.
// Виды фона: 0 — чистое голубое пространство, 1 — величественные горы, 2 — океан, 3 — золотой свет чистой земли.
// from / to / blend — плавный переход между видами, alpha — насколько фон закрывает обычное небо.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_front, shadows_disabled, fog_disabled;

uniform int from_mode = 0;
uniform int to_mode = 0;
uniform float blend = 0.0;
uniform float alpha = 0.0;





float ridge(float a, float scale, float seed) {
	// гряда — сумма синусов с несоизмеримыми частотами, острые вершины через 1 − |sin|
	float h = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		float k = float(i);
		h += amp * (1.0 - abs(sin(a * scale * (1.0 + 0.37 * k) + seed * (1.7 + k))));
		scale *= 1.93;
		amp *= 0.5;
	}
	return h;
}

vec3 space(vec3 d) {
	// светлая лазурь у горизонта, глубокая синева вверху, мягкое сияние впереди
	vec3 top = vec3(0.18, 0.36, 0.78);
	vec3 horizon = vec3(0.62, 0.8, 0.98);
	vec3 c = mix(horizon, top, smoothstep(-0.1, 0.7, d.y));
	c += vec3(0.25, 0.3, 0.35) * pow(max(dot(d, normalize(vec3(0.0, 0.25, -1.0))), 0.0), 6.0);
	return c;
}

vec3 mountains(vec3 d) {
	vec3 c = mix(vec3(0.95, 0.78, 0.6), vec3(0.32, 0.5, 0.82), smoothstep(-0.05, 0.6, d.y));
	float a = atan(d.x, d.z);
	// три гряды: дальняя светлая, ближние темнее, у вершин снег
	float far = 0.04 + 0.22 * ridge(a, 2.2, 3.0);
	float near = -0.02 + 0.16 * ridge(a, 3.4, 11.0);
	if (d.y < far) {
		float snow = smoothstep(far - 0.05, far - 0.01, d.y);
		c = mix(vec3(0.46, 0.52, 0.66), vec3(0.92, 0.94, 1.0), snow);
	}
	if (d.y < near) {
		float snow = smoothstep(near - 0.035, near - 0.008, d.y);
		c = mix(vec3(0.24, 0.27, 0.36), vec3(0.85, 0.87, 0.93), snow);
	}
	return c;
}

vec3 ocean(vec3 d) {
	vec3 c = mix(vec3(0.85, 0.9, 0.98), vec3(0.25, 0.48, 0.85), smoothstep(0.0, 0.6, d.y));
	if (d.y < 0.0) {
		// вода: к горизонту светлее, по ней бегут блики
		float depth = smoothstep(0.0, -0.4, d.y);
		c = mix(vec3(0.42, 0.66, 0.85), vec3(0.04, 0.2, 0.42), depth);
		float a = atan(d.x, d.z);
		float wave = sin(a * 90.0 + TIME * 0.5 + 3.0 * sin(d.y * 60.0 + a * 7.0)) * sin(d.y * 220.0 - TIME * 0.8 + a * 23.0);
		float glint = pow(max(wave, 0.0), 30.0);
		c += vec3(1.0, 0.95, 0.85) * glint * (1.0 - depth) * 0.6;
	}
	return c;
}

vec3 golden(vec3 d) {
	vec3 c = mix(vec3(1.0, 0.86, 0.55), vec3(0.95, 0.62, 0.32), smoothstep(-0.1, 0.8, d.y));
	c += vec3(0.4, 0.3, 0.15) * pow(max(dot(d, normalize(vec3(0.0, 0.3, -1.0))), 0.0), 4.0);
	return c;
}

vec3 view(int mode, vec3 d) {
	if (mode == 1) return mountains(d);
	if (mode == 2) return ocean(d);
	if (mode == 3) return golden(d);
	return space(d);
}

void fragment() {
	// направление взгляда в мире — точно в каждой точке (через интерполяцию вершин сферы гряды гор шли ступеньками)
	vec3 d = normalize((INV_VIEW_MATRIX * vec4(normalize(VERTEX), 0.0)).xyz);
	ALBEDO = mix(view(from_mode, d), view(to_mode, d), blend);
	ALPHA = alpha;
}
