// Вспышка, из которой проявляется фигура мандалы (mandala24_3d.gd): яркое золотое ядро, мягкий ореол и лучи.
// Billboard, аддитивно; пока она в силе, фигура под ней проступает — и не видно, как фигура дорисовывается.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity = 0.0;
uniform float seed = 0.0;
uniform vec3 core_color : source_color = vec3(1.0, 0.97, 0.88);
uniform vec3 halo_color : source_color = vec3(1.0, 0.78, 0.42);

void vertex() {
	// всегда лицом к камере, с масштабом самого узла
	float scale = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale, INV_VIEW_MATRIX[1] * scale, INV_VIEW_MATRIX[2] * scale, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float ang = atan(p.y, p.x) + seed * 6.2832 + TIME * 0.25;
	float core = exp(-r * r * 4.5);
	float halo = exp(-r * r * 2.0) * 0.35;
	// 16 лучей разной яркости, медленно поворачиваются
	float rays = pow(0.5 + 0.5 * cos(ang * 16.0), 24.0) * (0.6 + 0.4 * cos(ang * 5.0 + seed * 9.0));
	rays *= smoothstep(0.05, 0.3, r) * (1.0 - smoothstep(0.3, 1.0, r)) * 0.8;
	vec3 col = mix(halo_color, core_color, core);
	ALBEDO = col * (core * 1.6 + halo + rays) * intensity * smoothstep(1.0, 0.85, r);
}
