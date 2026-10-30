// Объёмный луч света: конус с вершиной в источнике. UV.y — 0 у вершины, 1 на дальнем конце.
// pulse — положение бегущей волны света вдоль луча (0..1).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity : hint_range(0.0, 3.0) = 0.0;
uniform float pulse = -1.0;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.65, 1.0);

void fragment() {
	float d = UV.y;
	// мягкий край конуса: ярче там, где луч смотрит на зрителя боком
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft = facing * facing;
	float fade = pow(1.0 - d, 1.4) * smoothstep(0.0, 0.04, d);
	float front = exp(-pow((d - pulse) / 0.09, 2.0));
	float shimmer = 0.85 + 0.15 * sin(d * 30.0 - TIME * 4.0);
	ALBEDO = color.rgb * (0.35 * fade * shimmer + 1.4 * front * (1.0 - 0.6 * d)) * soft * intensity;
}
