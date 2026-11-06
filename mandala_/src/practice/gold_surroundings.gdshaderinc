// То, что отражает золото: тёплый купол и две мягкие полосы света (мировые координаты)
vec3 surroundings(vec3 dir) {
	float up = dir.y * 0.5 + 0.5;
	vec3 c = mix(vec3(0.16, 0.08, 0.03), vec3(0.8, 0.58, 0.3), smoothstep(0.45, 0.98, up));
	c += vec3(1.0, 0.92, 0.75) * 1.1 * pow(max(dot(dir, normalize(vec3(-0.35, 0.86, 0.36))), 0.0), 48.0);
	c += vec3(1.0, 0.8, 0.55) * 0.4 * pow(max(dot(dir, normalize(vec3(0.62, 0.5, -0.6))), 0.0), 10.0);
	return c;
}
