// Сияние вокруг Датты — «ответ» святых: мягкое свечение и медленные лучи. Billboard, аддитивно.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity : hint_range(0.0, 3.0) = 0.0;
uniform float rays : hint_range(0.0, 2.0) = 0.5;
uniform vec4 color : source_color = vec4(1.0, 0.82, 0.5, 1.0);

void vertex() {
	// всегда лицом к камере
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float ang = atan(p.y, p.x);
	float core = exp(-r * r / 0.12);
	float wide = exp(-r * r / 0.22);
	float beams = pow(0.5 + 0.5 * cos(ang * 16.0 + TIME * 0.08), 10.0) * smoothstep(1.0, 0.2, r);
	vec3 col = color.rgb * (core * 0.8 + wide * 0.35 + beams * 0.35 * rays);
	ALBEDO = col * intensity * smoothstep(1.0, 0.85, r);
}
