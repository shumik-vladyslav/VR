// Поток света, нисходящий сверху на всё пространство (этап 2 новой версии): широкий столб, по нему бегут вниз струи.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.5, 1.0);

void fragment() {
	// UV.y: 0 — верх столба, 1 — пол
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft = pow(facing, 1.5);
	float streaks = 0.6 + 0.4 * sin(UV.x * 60.0 + sin(UV.x * 13.0) * 3.0) * sin(UV.y * 9.0 - TIME * 2.0);
	float fall = smoothstep(0.0, 0.25, UV.y) * (0.55 + 0.45 * UV.y);
	ALBEDO = color.rgb * intensity * soft * streaks * fall * 0.6;
}
