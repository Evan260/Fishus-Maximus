shader_type canvas_item;
// Gilds pixel lettering a row at a time: each line's capitals pale gold at the top, gold, then deep gold at the foot.

// Rows from a line's top to its capitals, how tall they are, and how far one line starts below the last.
uniform float cap_top = 7.0;
uniform float cap_height = 10.0;
uniform float line_step = 21.0;
uniform vec4 light : source_color = vec4(0.988, 0.91, 0.627, 1.0);
uniform vec4 middle : source_color = vec4(0.925, 0.769, 0.376, 1.0);
uniform vec4 deep : source_color = vec4(0.749, 0.525, 0.22, 1.0);

varying vec2 local;
varying vec4 tint;

void vertex() {
	local = VERTEX;
	tint = COLOR;
}

void fragment() {
	// The letters are drawn in white and gilded here; their shadow, drawn in its own colour, is left as it is.
	if (tint.r > 0.99 && tint.g > 0.99 && tint.b > 0.99) {
		float row = floor(mod(local.y, line_step)) - cap_top;
		float t = row / max(1.0, cap_height);
		COLOR.rgb = t < 0.3 ? light.rgb : (t < 0.7 ? middle.rgb : deep.rgb);
	}
}
