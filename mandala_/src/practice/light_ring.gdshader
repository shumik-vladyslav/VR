// Волна света от груди практикующего (scene_extras.gd): расширяющаяся стена-кольцо из света вокруг него.
// Видна изнутри — полоса света по горизонту, которая уходит вдаль ко всем существам. Аддитивно.
// UV.y — по высоте стены (0 вверху, 1 внизу).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity : hint_range(0.0, 3.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.88, 0.62, 1.0);

void fragment() {
	// ярче посередине по высоте, мягко растворяется вверх и вниз
	float band = exp(-pow((UV.y - 0.5) / 0.2, 2.0));
	float shimmer = 0.8 + 0.2 * sin(UV.x * 120.0 + TIME * 1.5) * sin(UV.x * 37.0 - TIME * 0.8);
	ALBEDO = color.rgb * band * shimmer * intensity;
}
