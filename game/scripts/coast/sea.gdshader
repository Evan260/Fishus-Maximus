shader_type canvas_item;
// A band of sea under a row of land, mirroring the sky, shading in over the rows above its top from the band behind.
#include "res://scripts/coast/water.gdshaderinc"

uniform float ramp = 0.0;

varying vec2 local;
varying vec4 lit;

void vertex() {
	local = VERTEX;
	lit = COLOR;
}

void fragment() {
	vec2 px = floor(local);
	float a = px.y < 0.0 ? 1.0 + px.y / (ramp + 1.0) : 1.0;
	COLOR = vec4(lit_water(home.x + px.x, home.y + px.y, px.x + 0.5 + to_sky, lit.rgb), a);
}
