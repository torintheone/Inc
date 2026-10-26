shader_type canvas_item;
// Заливка стран одним мешем: в UV.x каждой вершины записан номер страны,
// а цвет берётся из текстуры-палитры шириной в число стран. Перекрасить
// страну — значит поменять один пиксель палитры. Поверх цвета — бумажное
// зерно и «чернильные» разводы: оттенок чуть плавает, как краска на бумаге.

uniform sampler2D country_colors : filter_nearest, repeat_disable;
uniform float grain = 0.07;

varying vec2 map_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	map_pos = VERTEX;
}

void fragment() {
	vec4 c = texelFetch(country_colors, ivec2(int(UV.x + 0.5), 0), 0);
	float blot = noise(map_pos * 0.035) * 0.6 + noise(map_pos * 0.11) * 0.4;
	float fiber = noise(map_pos * vec2(1.6, 0.25));
	float shade = 1.0 - grain * (blot - 0.5) * 1.6 - grain * 0.5 * (fiber - 0.5);
	c.rgb *= shade;
	COLOR = c;
}
