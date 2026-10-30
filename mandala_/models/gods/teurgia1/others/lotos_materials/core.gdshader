shader_type spatial;

uniform vec3 color1: source_color;
uniform vec3 color2: source_color;
uniform sampler2D noiseTex;
uniform sampler2D normalTex;

uniform float metalic: hint_range(0.0, 1.0, 0.01) = 0.641;
uniform float roughness: hint_range(0.0, 1.0, 0.01) = 0.207;

void fragment() {

	ALBEDO = mix(color1, color2, texture(noiseTex, UV).r);
	METALLIC = metalic;
	ROUGHNESS = roughness;
	NORMAL_MAP = texture(normalTex, UV).rgb;
}
