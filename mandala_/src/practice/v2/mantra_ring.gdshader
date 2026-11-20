// Мантра «ॐ द्रां दत्तात्रेयाय नमः» кольцом вокруг слога Драм на груди Даттатрейи (этап 7 новой версии).
// Всегда лицом к практикующему, медленно вращается.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D ring : source_color, filter_linear_mipmap;
uniform float alpha = 0.0;
uniform float angle = 0.0;
uniform float glow = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 p = UV - 0.5;
	float c = cos(angle);
	float s = sin(angle);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y) + 0.5;
	vec4 t = texture(ring, q);
	ALBEDO = t.rgb * glow;
	ALPHA = t.a * alpha;
}
