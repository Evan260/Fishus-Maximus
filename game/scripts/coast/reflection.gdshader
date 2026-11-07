shader_type canvas_item;
// A row of land mirrored in the sea below it, each column turned over about its own shore so rocks mirror where they stand.

uniform vec4 sea : source_color = vec4(0.3, 0.5, 0.6, 1.0);
uniform float tint = 0.5;
uniform float dark = 0.85;
uniform float strength = 0.9;
uniform float reach = 24.0;
uniform float rough = 1.0;
uniform float scan = 12.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 pixel(vec2 size, float x, float y) {
	return (vec2(mod(x, size.x), y) + 0.5) / size;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * size);
	float shore = -1.0;
	for (int k = 0; k < 24; k++) {
		if (float(k) >= scan) {
			break;
		}
		if (texture(TEXTURE, pixel(size, px.x, size.y - 1.0 - float(k))).a > 0.5) {
			shore = size.y - float(k);
			break;
		}
	}
	float r = px.y - shore;
	COLOR = vec4(0.0);
	if (shore >= 0.0 && r >= 0.0 && r < reach) {
		float far = r / reach;
		// The rows nearest the shore lie still; further out each row sways by whole pixels, out of step with its neighbours.
		float amp = rough * min(2.0, max(0.0, r - 1.0) * 0.25);
		float off = floor(sin(r * 1.7 + TIME * 1.3 + hash(vec2(r, 3.0)) * 6.0) * amp + 0.5);
		vec4 c = texture(TEXTURE, pixel(size, px.x + off, shore - 1.0 - r));
		if (c.a > 0.5) {
			float len = 5.0 + floor(hash(vec2(r, 7.0)) * 12.0);
			float drift = (hash(vec2(r, 11.0)) - 0.5) * 6.0 * (0.4 + rough);
			float seg = floor((px.x + TIME * drift) / len);
			float h = hash(vec2(seg, r));
			float fade = strength * (1.0 - smoothstep(0.45, 1.0, far));
			vec3 rgb = mix(mix(c.rgb, sea.rgb, tint) * dark, sea.rgb, far * 0.6);
			if (h < 0.05 + 0.3 * far * rough) {
				// A ripple crossing the reflection shows the sea there, lit a little by the sky.
				rgb = mix(sea.rgb, vec3(1.0), 0.14);
			}
			COLOR = vec4(rgb, fade);
		}
	}
}
