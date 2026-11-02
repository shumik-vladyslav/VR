// Зеркало из света перед практикующим (practice_fx.gd): овал с отражением (ViewportTexture от камеры-отражения)
// и золотым светящимся краем. Картинка камеры отражения зеркально развёрнута по горизонтали.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D reflection : source_color, filter_linear;
uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.45, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float e = length(p);                        // 1 — край овала (квад уже вытянут по высоте)
	float inside = 1.0 - smoothstep(0.9, 0.94, e);
	vec3 img = texture(reflection, vec2(1.0 - UV.x, UV.y)).rgb;
	// лёгкая светлая дымка по краю отражения — как будто зеркало из света
	img = mix(img, rim_color.rgb, 0.25 * smoothstep(0.6, 0.92, e));
	float rim = exp(-pow((e - 0.94) / 0.025, 2.0));
	float halo = exp(-pow((e - 0.94) / 0.08, 2.0)) * 0.5;
	vec3 col = img * inside + rim_color.rgb * (rim * 2.2 + halo);
	ALBEDO = col;
	ALPHA = clamp(inside + rim + halo, 0.0, 1.0) * alpha;
}
