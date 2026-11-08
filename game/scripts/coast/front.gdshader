shader_type canvas_item;
// A plant in front of the view breaking away in square blocks scattered at random, as Farmus's screens do on the way
// to the market; the blocks are held to the picture's own pixels, so they slide with the plant.

uniform float progress = 0.0;
uniform float cell = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	if (hash(floor(UV / TEXTURE_PIXEL_SIZE / cell)) < progress) {
		discard;
	}
}
