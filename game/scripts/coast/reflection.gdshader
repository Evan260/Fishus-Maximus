shader_type canvas_item;
// A row of land and the sea below it: under each column's waterline the sea mirrors the sky and the land, turned over about that waterline.
#include "res://scripts/coast/water.gdshaderinc"

// Each column's waterline as a row of the picture, or -1 where nothing there is mirrored.
uniform sampler2D waterline : filter_nearest;
uniform float tint = 0.3;
uniform float dark = 0.8;
uniform float strength = 0.9;
// The row where the nearer water covers this land's sea, and the longest a reflection reaches.
uniform float until = 120.0;
uniform float reach = 40.0;

varying vec2 local;
varying vec4 lit;

void vertex() {
	local = VERTEX;
	lit = COLOR;
}

vec2 texel(vec2 size, float x, float y) {
	return (vec2(mod(x, size.x), y) + 0.5) / size;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * size);
	vec2 at = floor(local);
	vec4 own = px.y < size.y ? texture(TEXTURE, texel(size, px.x, px.y)) : vec4(0.0);
	float axis = texelFetch(waterline, ivec2(int(mod(px.x, size.x)), 0), 0).r;
	if (axis < 0.0 || px.y < axis) {
		COLOR = own * lit;
	} else {
		float wx = home.x + at.x;
		float wy = home.y + at.y;
		float sx = at.x + 0.5 + to_sky;
		vec3 water = water_at(wx, wy, sx, lit.rgb);
		// Sea painted above the horizon still hides the sky, while below it the bands and the reflections behind show through.
		float painted = wy < HORIZON ? own.a : 0.0;
		float r = px.y - axis;
		float far = r / max(1.0, min(reach, until - axis));
		// The rows nearest the shore lie still; further out each row sways by whole texels, out of step with its neighbours.
		float amp = rough * min(2.0, max(0.0, r - 1.0) * 0.25);
		float off = floor(sin(r * 1.7 + time * 1.3 + hash(vec2(r, 3.0)) * 6.0) * amp + 0.5);
		vec4 c = far < 1.0 && axis - 1.0 - r >= 0.0 ? texture(TEXTURE, texel(size, px.x + off, axis - 1.0 - r)) : vec4(0.0);
		float fade = c.a > 0.5 ? strength * (1.0 - smoothstep(0.45, 1.0, far)) : 0.0;
		float len = 5.0 + floor(hash(vec2(wy, 7.0)) * 12.0);
		float drift = (hash(vec2(wy, 11.0)) - 0.5) * 6.0 * (0.4 + rough);
		if (hash(vec2(floor((wx + time * drift) / len), wy)) < 0.05 + 0.3 * far * rough) {
			// A ripple crossing the reflection shows the sea there, lit a little by the sky.
			painted = max(painted, fade);
			fade = 0.0;
			water = mix(water, vec3(1.0), 0.07);
		}
		vec3 refl = mix(mix(c.rgb * lit.rgb, water, tint) * dark, water, far * 0.6);
		float a = fade + painted * (1.0 - fade);
		vec3 rgb = (refl * fade + water * painted * (1.0 - fade)) / max(a, 0.001);
		float sun_path = path(wx, wy, sx, sun, sun_width, sun_light) * step(0.001, a);
		float moon_path = path(wx, wy, sx, moon, MOON_WIDTH, moon_light) * step(0.001, a);
		rgb = mix(mix(rgb, sun_colour.rgb, sun_path), moon_colour.rgb, moon_path);
		COLOR = vec4(rgb, a);
	}
}
