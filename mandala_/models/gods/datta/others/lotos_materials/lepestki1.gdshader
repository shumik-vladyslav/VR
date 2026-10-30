shader_type spatial;

#include "res://models/gods/datta/others/lotos_materials/lotos_inc.gdshaderinc"

render_mode depth_prepass_alpha;

uniform sampler2D albedo: source_color;
uniform sampler2D mask1;
uniform sampler2D mask2;
uniform sampler2D mask3;
uniform sampler2D mask4;
uniform sampler2D mask5;
uniform vec4 tint1: source_color;
uniform vec4 tint2: source_color;
uniform vec4 tint3: source_color;
uniform vec4 tint4: source_color;
uniform vec4 tint5: source_color;

uniform float factorMask1: hint_range(0.0, 50, 0.01);
uniform float factorMask2: hint_range(0.0, 50, 0.01);
uniform float factorMask3: hint_range(0.0, 50, 0.01);
uniform float factorMask4: hint_range(0.0, 50, 0.01);
uniform float factorMask5: hint_range(0.0, 50, 0.01);

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float refraction : hint_range(-16,16);

uniform float emissionValue: hint_range(0.0, 30.0, 0.1) = 6.6;
uniform float metalic: hint_range(0.0, 1.0, 0.01) = 0.641;
uniform float roughness: hint_range(0.0, 1.0, 0.01) = 0.207;


const vec2 offset = vec2(-0.012,0);
// Посмтреть тему с эмиссионным параметром, вопрос цвета и цвета по маске
//- у нас цвета разные должны быть. Возможно не верное смешались???
// можно посмотреть естьли такая функция в visual И посмотреть код.
// то же про рефракцию
// посмотреть уроки по визуаль шейдеру.
/// https://godotshaders.com/shader/screen-space-refraction-shader/
/// https://github.com/NathanWarden/godot_refraction_shader/blob/main/RefractionShader.shader


void fragment() {
	vec4 base_color = texture(albedo, UV);
	ALBEDO = texture(albedo, UV).rgb;

	vec4 color1 = tint(texture(mask1, UV), tint1) * factorMask1;
	vec4 color2 = tint(texture(mask2, UV), tint2) * factorMask2;
	vec4 color3 = tint(texture(mask3, UV+offset), tint3) * factorMask3;
	vec4 color4 = tint(texture(mask4, UV), tint4) * factorMask4;
	vec4 color5 = tint(texture(mask5, UV), tint5) * factorMask5;

	vec4 tempColor = mixColors(mixColors(color5, color4, 0.5), mixColors(color2, color1, 0.5), 0.5);
	EMISSION = emissionValue * mixColors(color3, tempColor, 0.5).rgb;

	METALLIC = metalic;
	ROUGHNESS = roughness;

	//vec3 unpacked_normal = NORMAL;
	//unpacked_normal.xy = unpacked_normal.xy * 2.0 - 1.0;
	//unpacked_normal.z = sqrt(max(0.0, 1.0 - dot(unpacked_normal.xy, unpacked_normal.xy)));
	//vec3 ref_normal = normalize( mix(NORMAL,TANGENT * unpacked_normal.x + BINORMAL * unpacked_normal.y + NORMAL * unpacked_normal.z,NORMAL_MAP_DEPTH) );
	//vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction;
	//float ref_amount = 1.0 - base_color.a;
	//EMISSION += textureLod(screen_texture,ref_ofs,ROUGHNESS * 8.0).rgb * ref_amount * EXPOSURE;
	//ALBEDO *= 1.0 - ref_amount;
	//IOR 1.426 рефракция - какой алгоритм?? может в аддоне для шейдеров? Можно преобразовать станд. шейдер в код.
}
