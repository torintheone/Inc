shader_type canvas_item;
// Бумага под картой (море): лёгкое зерно и пятна, привязанные к координатам карты.

uniform vec4 paper_color : source_color = vec4(0.796, 0.749, 0.643, 1.0);
uniform float grain = 0.06;

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
	float blot = noise(map_pos * 0.012) * 0.6 + noise(map_pos * 0.05) * 0.4;
	float fiber = noise(map_pos * vec2(0.9, 0.12));
	COLOR = vec4(paper_color.rgb * (1.0 - grain * (blot - 0.5) * 1.8 - grain * 0.4 * (fiber - 0.5)), 1.0);
}
