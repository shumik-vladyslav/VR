// Сияние тела божества медитации (transformation.gd): накладывается поверх материалов модели (material_overlay).
// Тёплое свечение кожи и светящийся контур — «каждый элемент тела сияет»; на глазах — сильнее.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform float radiance : hint_range(0.0, 3.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.86, 0.6, 1.0);

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.5);
	float pulse = 0.9 + 0.1 * sin(TIME * 0.8);
	ALBEDO = color.rgb * (0.12 + 0.9 * rim) * radiance * pulse;
}
