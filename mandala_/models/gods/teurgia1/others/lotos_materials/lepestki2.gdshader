shader_type spatial;

#include "res://models/gods/teurgia1/others/lotos_materials/lotos_inc.gdshaderinc"

render_mode depth_draw_always;

uniform sampler2D albedo: source_color;
uniform sampler2D mask1;
uniform sampler2D mask2;

uniform vec4 tint1: source_color;
uniform vec4 tint2: source_color;

uniform float factorMask1: hint_range(0.0, 15, 0.01);
uniform float factorMask2: hint_range(0.0, 15, 0.01);


uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float emissionValue: hint_range(0.0, 30.0, 0.1) = 6.6;
uniform float metalic: hint_range(0.0, 1.0, 0.01) = 0.641;
uniform float roughness: hint_range(0.0, 1.0, 0.01) = 0.207;
uniform float refraction : hint_range(-16,16);


void fragment() {
	vec4 base_color = texture(albedo, UV);
	ALBEDO = texture(albedo, UV).rgb;

	vec4 color1 = tint(texture(mask1, UV), tint1);
	vec4 color2 = tint(texture(mask2, UV), tint2);

	EMISSION = emissionValue * mixColors(color1 * factorMask1, color2 * factorMask2, 0.5).rgb;

	METALLIC = metalic;
	ROUGHNESS = roughness;
}
