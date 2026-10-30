// Лепесток цветка на изогнутой 3D-сетке (offering.gd → _make_petal_mesh). UV.x — поперёк (0..1), UV.y — от основания (0) к краю (1).
// Тёплое светлое основание, живые пятна тона, рельеф прожилок, бархатный отблеск, просвечивает на свету.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

instance uniform vec4 petal_color : source_color = vec4(1.0, 0.35, 0.5, 1.0);
instance uniform float petal_fade = 1.0;
instance uniform float petal_seed = 0.0;
// цвет основания лепестка (у лотоса — белый, у розы — тёплый светлый)
instance uniform vec4 base_color : source_color = vec4(1.0, 0.93, 0.75, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	if (petal_fade < 0.01) {
		discard;
	}
	float u = UV.x * 2.0 - 1.0;
	float v = UV.y;
	vec3 col = petal_color.rgb;
	vec3 base = mix(base_color.rgb, col, 0.25);
	// основание → цвет; край немного глубже
	vec3 c = mix(base, col, smoothstep(0.02, 0.5, v));
	c *= 1.0 - 0.14 * smoothstep(0.55, 1.0, v) - 0.08 * smoothstep(0.6, 1.0, abs(u));
	// живые мягкие пятна тона, у каждого лепестка свои
	float blot = noise(vec2(u * 2.5, v * 3.0) + petal_seed * 7.3);
	c *= 0.92 + 0.12 * blot;
	// центральная жилка у основания — светлее
	c = mix(c, base, 0.25 * exp(-pow(u / 0.07, 2.0)) * (1.0 - smoothstep(0.0, 0.5, v)));

	// рельеф прожилок веером от основания (нормаль, а не краска)
	float fan = u / (0.35 + 0.65 * v);
	float vein_amt = 0.25 * smoothstep(0.05, 0.3, v) * (1.0 - smoothstep(0.7, 1.0, v));
	NORMAL_MAP = normalize(vec3(0.5 + 0.5 * cos(fan * 22.0) * vein_amt * 0.4, 0.5, 1.0));
	c *= 1.0 + 0.03 * sin(fan * 22.0) * vein_amt;

	ALBEDO = c;
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
	RIM = 0.45;
	RIM_TINT = 0.7;
	BACKLIGHT = col * 0.8;
	// при растворении в конце полёта лепесток светится
	EMISSION = col * (0.04 + 0.9 * (1.0 - petal_fade));
}
