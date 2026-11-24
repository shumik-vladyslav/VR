// Фон заставки загрузки мандалы: фиолетовый, к центру светлее; из-за знака Ом в центре расходятся золотые лучи.
// Сам знак неподвижен (TextureRect поверх), лучи живут: тихо мерцают и по ним бегут волны света от центра.
shader_type canvas_item;

// радиус знака Ом в долях полувысоты экрана (знак — треть высоты экрана)
uniform float om_radius = 0.34;
// время анимации — его ведёт сцена (mandala24_3d.gd) и не даёт ему прыгать вперёд после подвисших кадров
uniform float t = 0.0;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;  // круг, а не эллипс
	float r = length(p) * 2.0;
	vec3 col = mix(vec3(0.50, 0.27, 0.72), vec3(0.13, 0.04, 0.25), smoothstep(0.0, 1.4, r));
	float breath = 0.8 + 0.2 * sin(t * 1.4);
	col += vec3(1.0, 0.82, 0.5) * exp(-r * r * 9.0) * 0.45 * breath;

	// 24 главных луча разной длины и 48 тонких; медленно вращаются (один оборот за ~1,5 мин)
	float ang = atan(p.y, p.x) + t * 0.07;
	float sector = floor(mod(ang, 6.2832) / 6.2832 * 24.0);
	float len_main = om_radius + mix(0.45, 1.1, hash(sector));
	float main_rays = pow(0.5 + 0.5 * cos(ang * 24.0), 30.0) * (1.0 - smoothstep(om_radius, len_main, r));
	float thin_rays = pow(0.5 + 0.5 * cos(ang * 48.0 + 1.57), 50.0) * (1.0 - smoothstep(om_radius, om_radius + 0.5, r)) * 0.5;
	// у каждого луча своё мерцание; по лучам от центра бегут мягкие волны
	float flicker = 0.75 + 0.25 * sin(t * 0.9 + hash(sector * 7.1) * 6.2832);
	float wave = 0.7 + 0.3 * sin(r * 9.0 - t * 1.6);
	float rays = (main_rays * flicker + thin_rays) * wave * smoothstep(om_radius * 0.8, om_radius * 1.05, r);
	col += vec3(1.0, 0.86, 0.55) * rays * 0.8;
	COLOR = vec4(col, 1.0) * COLOR;
}
