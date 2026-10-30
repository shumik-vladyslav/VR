// Символ Ом в груди: знак, пятицветное радужное сияние и лучи света.
// Рисуется на одном квадрате (центр — знак), аддитивно.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D glyph : source_color, filter_linear_mipmap;
uniform float glyph_size = 0.22;        // доля квадрата под знак
uniform float intensity : hint_range(0.0, 2.0) = 1.0;   // общая яркость знака
uniform float halo : hint_range(0.0, 2.0) = 1.0;        // пятицветное сияние
uniform float rays_out : hint_range(0.0, 2.0) = 0.0;    // лучи от знака во все стороны
uniform float rays_in : hint_range(0.0, 2.0) = 0.0;     // лучи к знаку из пространства
uniform vec4 glyph_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform bool billboard = false;     // всегда лицом к зрителю (большой Ом в центре)

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

// Пять цветов: белый, жёлтый, красный, зелёный, синий
const vec3 FIVE[5] = vec3[5](
	vec3(1.0, 1.0, 1.0),
	vec3(1.0, 0.85, 0.2),
	vec3(1.0, 0.25, 0.2),
	vec3(0.25, 0.9, 0.4),
	vec3(0.25, 0.45, 1.0)
);

vec3 five(float x) {
	x = fract(x) * 5.0;
	int i = int(floor(x)) % 5;
	return mix(FIVE[i], FIVE[(i + 1) % 5], smoothstep(0.0, 1.0, fract(x)));
}

float glyph_alpha(vec2 uv) {
	vec2 g = (uv - 0.5) / glyph_size + 0.5;
	if (g.x < 0.0 || g.x > 1.0 || g.y < 0.0 || g.y > 1.0) return 0.0;
	return texture(glyph, g).a;
}

float glyph_glow(vec2 uv) {
	// мягкое свечение вокруг знака: размытый альфа-канал через мип-уровень
	vec2 g = (uv - 0.5) / glyph_size + 0.5;
	if (g.x < -0.3 || g.x > 1.3 || g.y < -0.3 || g.y > 1.3) return 0.0;
	return textureLod(glyph, clamp(g, 0.0, 1.0), 5.0).a;
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;           // 0 в центре, 1 на краю квадрата
	float ang = atan(p.y, p.x);

	// Знак
	float ga = glyph_alpha(UV);
	vec3 col = glyph_color.rgb * ga * 1.15 * intensity;

	// Ореол вокруг знака, мягко переливающийся пятью цветами
	float glow = glyph_glow(UV) * (1.0 - ga);
	col += five(TIME * 0.05 + r * 0.6) * glow * 0.9 * halo;

	// Кольца пятицветного сияния
	float rings = exp(-pow((r - 0.22) / 0.14, 2.0));
	col += five(ang / TAU + TIME * 0.03) * rings * 0.35 * halo;
	col += vec3(1.0, 0.9, 0.7) * exp(-r * r / 0.02) * 0.18 * halo;

	// Лучи наружу: бегущие от центра волны вдоль лучей
	float beams = pow(0.5 + 0.5 * cos(ang * 12.0 + sin(ang * 5.0 + TIME * 0.3)), 18.0);
	float wave_out = 0.5 + 0.5 * sin(r * 14.0 - TIME * 3.0);
	float fade = smoothstep(1.0, 0.25, r) * smoothstep(0.08, 0.2, r);
	col += five(ang / TAU) * beams * (0.35 + 0.65 * wave_out) * fade * rays_out * 0.7;

	// Лучи внутрь: волны бегут к центру, свет белый
	float wave_in = 0.5 + 0.5 * sin(r * 14.0 + TIME * 3.0);
	col += vec3(1.0, 0.98, 0.9) * beams * (0.35 + 0.65 * wave_in) * fade * rays_in * 0.7;

	ALBEDO = col;
}
