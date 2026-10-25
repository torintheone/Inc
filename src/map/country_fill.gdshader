shader_type canvas_item;
// Заливка стран одним мешем: в UV.x каждой вершины записан номер страны,
// а цвет берётся из текстуры-палитры шириной в число стран. Перекрасить
// страну — значит поменять один пиксель палитры.

uniform sampler2D country_colors : filter_nearest, repeat_disable;

void fragment() {
	COLOR = texelFetch(country_colors, ivec2(int(UV.x + 0.5), 0), 0);
}
