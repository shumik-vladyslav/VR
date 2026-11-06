// Объёмный золотой Ом (practice_fx.gd). Блики рисует сам шейдер, как у столов подношений: настоящее отражение
// показало бы тёмное небо, а прожекторы в сцене без бликов. alpha — проявление, glow — как сильно он сияет.
shader_type spatial;
render_mode depth_draw_always, cull_back;

#include "res://src/practice/gold_surroundings.gdshaderinc"

uniform vec3 gold : source_color = vec3(1.0, 0.68, 0.2);
uniform float alpha = 1.0;
uniform float glow = 1.0;

varying vec3 model_pos;

void vertex() {
	model_pos = VERTEX;
}

void fragment() {
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	// плоская грань отражала бы один цвет; мягкие волны по поверхности дают полированному золоту тёмные и светлые разливы
	vec3 wave = vec3(sin(model_pos.y * 9.0 + model_pos.x * 5.0), sin(model_pos.x * 8.0 - model_pos.y * 3.0), 0.0) * 0.32;
	vec3 mirror_dir = normalize(reflect(-world_view, world_normal) + wave);
	float edge = pow(1.0 - clamp(dot(world_normal, world_view), 0.0, 1.0), 3.0);

	ALBEDO = gold * 0.35;
	METALLIC = 0.0;
	SPECULAR = 0.2;
	ROUGHNESS = 0.45;
	EMISSION = gold * (surroundings(mirror_dir) * (1.25 + 0.6 * edge) + 0.12) * glow;
	ALPHA = alpha;
}
