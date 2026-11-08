shader_type canvas_item;
// The land under the water as two darker shades of the water already drawn behind it, the nearer slope the darker.

// Each slope's top per column, in rows under the waterline, and how fast its columns slide past.
uniform sampler2D far_tops : filter_nearest;
uniform sampler2D near_tops : filter_nearest;
uniform float far_factor = 0.55;
uniform float near_factor = 0.78;
uniform float far_shade = 0.8;
uniform float near_shade = 0.64;
uniform vec2 cam = vec2(0.0, -160.0);

varying vec2 at;

void vertex() {
	at = VERTEX;
}

float top_of(sampler2D tops, float factor) {
	int n = textureSize(tops, 0).x;
	return texelFetch(tops, ivec2(clamp(int(floor(at.x + cam.x * factor)), 0, n - 1), 0), 0).r;
}

void fragment() {
	float row = at.y + cam.y;
	float shade = 1.0;
	if (row >= top_of(far_tops, far_factor)) {
		shade = far_shade;
	}
	if (row >= top_of(near_tops, near_factor)) {
		shade = near_shade;
	}
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - shade);
}
