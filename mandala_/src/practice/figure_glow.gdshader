// Сияние за фигурой древа (refuge_tree.gd): тонкие лучи расходятся от фигуры, у каждой свой узор и медленное вращение.
// Billboard, аддитивно; сила — на каждую фигуру своя.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform float glow_strength = 0.0;
// постоянное число фигуры 0..1 — свой узор лучей (из координат нельзя: фигуры «парят», и узор скакал бы каждый кадр)
instance uniform float figure_seed = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.88, 0.62, 1.0);
// где кончается фигура (доля радиуса квада) — лучи начинаются от её края
uniform float figure_radius = 0.57;

varying float seed;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void vertex() {
	seed = figure_seed;
	// всегда лицом к камере
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float ang = atan(p.y, p.x) + seed * 6.28 + TIME * (0.03 + 0.025 * seed);   // один оборот за ~2–3.5 мин
	// 12 главных лучей разной длины и 24 тонких между ними
	// номер луча 0..11 (mod — чтобы на стыке atan лучи не меняли номер)
	float sector = floor(mod(ang, 6.2832) / 6.2832 * 12.0);
	float len_main = mix(mix(figure_radius, 1.0, 0.5), 1.0, hash(sector + seed * 31.0));
	float main_rays = pow(0.5 + 0.5 * cos(ang * 12.0), 40.0) * (1.0 - smoothstep(figure_radius, len_main, r));
	float thin_rays = pow(0.5 + 0.5 * cos(ang * 24.0 + 1.57), 60.0) * (1.0 - smoothstep(figure_radius, mix(figure_radius, 1.0, 0.55), r)) * 0.5;
	// лучи идут из-под края фигуры и тихо мерцают — каждый в своей случайной фазе
	// (фаза по порядку лучей давала волну по кругу, и казалось, что лучи крутятся)
	float start = smoothstep(figure_radius * 0.6, figure_radius, r);
	float flicker = 0.85 + 0.15 * sin(TIME * 0.2 + hash(sector * 7.1 + seed * 13.0) * 6.2832);
	float rays = (main_rays * flicker + thin_rays) * start;
	// небольшой ореол у самого края фигуры
	float rim = exp(-pow((r - figure_radius) / 0.08, 2.0)) * 0.35;
	ALBEDO = color.rgb * (rays * 1.3 + rim) * glow_strength * smoothstep(1.0, 0.9, r);
}
