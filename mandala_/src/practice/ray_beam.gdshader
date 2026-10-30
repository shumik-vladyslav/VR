// Луч благословения от Даттатрейи к практикующему (белый, красный, синий) — как лазер: раскалённая почти белая
// сердцевина и цветной ореол, а по лучу к практикующему летят яркие заряды. UV.y — 0 у источника, 1 за спиной практикующего.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity : hint_range(0.0, 3.0) = 0.0;
// сдвиг зарядов вдоль луча (растёт со временем — заряды летят к практикующему)
uniform float phase = 0.0;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// длина луча (м) — чтобы заряды были одного размера на любом луче
uniform float beam_length = 5.0;
// где на луче (0..1) точка входа в тело практикующего — дальше луч проходит насквозь и растворяется
uniform float hit = 0.92;
// на каком расстоянии от глаз (м) луч растворяется — у каждого луча своё
uniform vec2 near_fade = vec2(0.06, 0.22);
// насколько сердцевина белеет (у синего меньше — чтобы вокруг красного читался именно синий)
uniform float core_white = 0.7;
// 1 — луч-«трубка»: светится оболочка, середина почти пустая (синий вокруг красного, чтобы цвета не смешивались)
uniform float sheath = 0.0;

void fragment() {
	float d = UV.y;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 8.0);      // узкая раскалённая сердцевина
	float halo = pow(facing, 1.5);      // цветное свечение вокруг
	// у самых глаз растворяется, чтобы цилиндр не был виден гранями
	// (белый луч идёт в межбровье у самых глаз — гаснет раньше, иначе заряды у лица раздуваются в пятна)
	float near = smoothstep(near_fade.x, near_fade.y, length(VERTEX));
	// за телом практикующего луч гаснет
	float start = smoothstep(0.0, 0.015, d) * (1.0 - smoothstep(hit, 1.0, d));
	// заряды: каждые 1.2 м — светящийся отрезок ~0.45 м, летят от Даттатрейи к практикующему
	float f = fract(d * beam_length / 1.2 - phase);
	float bolt = smoothstep(0.0, 0.06, f) * (1.0 - smoothstep(0.3, 0.38, f));
	float beam = 0.5 + 1.8 * bolt;
	vec3 hot = mix(color.rgb, vec3(1.0), core_white);
	vec3 solid = hot * core * 1.8 + color.rgb * halo * 0.9;
	float band = pow(4.0 * facing * (1.0 - facing), 1.5);   // ярче всего на середине радиуса, в центре и по краю — ноль
	vec3 tube = color.rgb * band * 1.7;
	ALBEDO = mix(solid, tube, sheath) * beam * start * near * intensity;
}
