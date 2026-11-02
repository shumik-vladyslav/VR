// Солнце Сурьи над древом (scene_extras.gd): золотой диск с медленно вращающимися лучами. Billboard, аддитивно.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity : hint_range(0.0, 3.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float ang = atan(p.y, p.x) + TIME * 0.05;
	float disc = 1.0 - smoothstep(0.3, 0.33, r);
	float rim = exp(-pow((r - 0.32) / 0.025, 2.0));
	float corona = exp(-r * r / 0.18) * 0.8;
	float rays = pow(0.5 + 0.5 * cos(ang * 12.0), 14.0) * (1.0 - smoothstep(0.32, 0.95, r)) * smoothstep(0.3, 0.36, r);
	float rays2 = pow(0.5 + 0.5 * cos(ang * 24.0 + 1.0), 30.0) * (1.0 - smoothstep(0.32, 0.75, r)) * smoothstep(0.3, 0.36, r) * 0.5;
	vec3 gold = vec3(1.0, 0.72, 0.22);
	vec3 core = mix(vec3(1.0, 0.95, 0.75), gold, smoothstep(0.0, 0.3, r));
	vec3 col = core * disc * 1.3 + gold * (rim * 1.2 + corona * 0.5 + (rays + rays2) * 0.9);
	ALBEDO = col * intensity * smoothstep(1.0, 0.9, r);
}
