// Белый свет, заполняющий взгляд. Квадрат прямо перед камерой (в VR — перед XR-камерой).
// fill — свет стекает сверху вниз («с макушки до ног»), whiteout — полное растворение в свете.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform float fill : hint_range(0.0, 1.2) = 0.0;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.5;
uniform float whiteout : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.95, 0.82, 1.0);

void fragment() {
	float y = SCREEN_UV.y;                       // 0 сверху
	float edge = 0.25;
	float m = 1.0 - smoothstep(fill * (1.0 + edge) - edge, fill * (1.0 + edge), y);
	float shimmer = 0.9 + 0.1 * sin(y * 40.0 - TIME * 2.0);
	float a = max(m * fill_alpha * shimmer, whiteout);
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
