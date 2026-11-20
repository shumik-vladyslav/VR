// Небо мандалы 24 божеств: фиолетовое, к горизонту светлеет до сиреневого — как фон иконы.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.42, 0.08, 0.92, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.86, 0.78, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.36, 0.06, 0.82, 1.0);

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.4, y));
	c = mix(c, bottom_color.rgb, smoothstep(0.0, -0.7, y));
	COLOR = c;
}
