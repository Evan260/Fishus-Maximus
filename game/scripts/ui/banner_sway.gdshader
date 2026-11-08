shader_type canvas_item;
// Sways a hanging part of the catch banner by whole texels: not at all above `from_row`, most at `to_row` and below.

uniform float from_row = 0.0;
uniform float to_row = 64.0;
// How many texels its foot sways, its own phase, and how much neighbouring columns differ, so threads ripple.
uniform float amount = 1.5;
uniform float phase = 0.0;
uniform float ripple = 0.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * size);
	float down = clamp((px.y - from_row) / max(1.0, to_row - from_row), 0.0, 1.0);
	float wave = sin(TIME * 1.4 + phase - px.y * 0.05) * 0.8 + 0.2 * sin(TIME * 2.6 + phase * 1.7 + px.x * ripple);
	float x = px.x - floor(wave * amount * down + 0.5);
	COLOR = x < 0.0 || x >= size.x ? vec4(0.0) : texture(TEXTURE, (vec2(x, px.y) + 0.5) / size) * tint;
}
