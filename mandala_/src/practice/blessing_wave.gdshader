// Волна благословения от Даттатрейи (scene_extras.gd): расширяющаяся светящаяся оболочка-сфера.
// Видна как кольцо света (ярче по краю), проходит сквозь практикующего. Аддитивно.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity : hint_range(0.0, 3.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.88, 0.62, 1.0);

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 3.0);
	float shimmer = 0.85 + 0.15 * sin(UV.y * 60.0 + TIME * 2.0);
	ALBEDO = color.rgb * (0.05 + rim * 1.4) * shimmer * intensity;
}
