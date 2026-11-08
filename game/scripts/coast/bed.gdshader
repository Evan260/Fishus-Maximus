shader_type canvas_item;
// A piece lying on the sea floor, with only a share of its own colour left in the murky water.

uniform float keep = 1.0;

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.rgb = mix(vec3(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114))), COLOR.rgb, keep);
}
