// The sea mirroring the sky, worked out per game pixel counted from the camera at home, so it stays crisp at any scale.

uniform vec4 zenith : source_color = vec4(0.26, 0.53, 0.86, 1.0);
uniform vec4 middle : source_color = vec4(0.5, 0.74, 0.94, 1.0);
uniform vec4 low : source_color = vec4(0.82, 0.91, 0.95, 1.0);
uniform vec4 glow : source_color = vec4(0.0);
uniform float glow_radius = 100.0;
// The sun and the moon are in the sky's own pixels.
uniform vec2 sun = vec2(-10000.0);
uniform vec4 sun_colour : source_color = vec4(1.0);
uniform float sun_light = 0.0;
uniform float sun_width = 20.0;
uniform vec2 moon = vec2(-10000.0);
uniform vec4 moon_colour : source_color = vec4(0.95, 0.93, 0.8, 1.0);
uniform float moon_light = 0.0;
uniform vec4 sea : source_color = vec4(0.3, 0.5, 0.6, 1.0);
// Where the node's corner lies with the camera at home, and what turns its x into the sky's.
uniform vec2 home = vec2(0.0);
uniform float to_sky = 0.0;
uniform float rough = 1.0;
uniform float time = 0.0;

// These match SkyView's horizon and gradient, and the near waterline.
const float HORIZON = 106.0;
const float SKY_TOP = -44.0;
const float SKY_BANDS = 9.0;
const float WATERLINE = 160.0;
// Each row of sea mirrors this many rows of sky, so the near water shows the sky well above the horizon.
const float MIRROR = 1.8;
// The moon lays a narrower path than the sun, being smaller and dimmer.
const float MOON_WIDTH = 9.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 sky_at(vec2 p) {
	float t = clamp((p.y - SKY_TOP) / (HORIZON - SKY_TOP), 0.0, 1.0);
	float q = clamp(floor(t * SKY_BANDS * 2.0 + 0.5) / (SKY_BANDS * 2.0), 0.0, 1.0);
	vec3 col = q < 0.5 ? mix(zenith.rgb, middle.rgb, q * 2.0) : mix(middle.rgb, low.rgb, (q - 0.5) * 2.0);
	float r = length((p - sun) * vec2(1.0, 1.4)) / glow_radius;
	float g = clamp(1.0 - r, 0.0, 1.0);
	g = floor(g * g * 7.0 + 0.5) / 7.0;
	return mix(col, glow.rgb, g * glow.a);
}

float nearness(float wy) {
	return clamp((wy + 0.5 - HORIZON) / (WATERLINE - HORIZON), 0.0, 1.0);
}

// A ripple tilts the water, so it mirrors the sky a few rows higher or lower; 0 where the water lies flat.
float tilt(float wx, float wy) {
	float d = nearness(wy);
	float len = 3.0 + floor(hash(vec2(wy, 7.0)) * 9.0);
	float drift = (hash(vec2(wy, 11.0)) - 0.5) * 4.0 * (0.5 + rough);
	float seg = floor((wx + time * drift) / len);
	if (hash(vec2(seg, wy)) > 0.2 + 0.12 * rough * d) {
		return 0.0;
	}
	return (hash(vec2(seg, wy + 0.5)) < 0.5 ? -1.0 : 1.0) * (5.0 + 12.0 * d) * (0.6 + 0.4 * rough);
}

vec3 water_at(float wx, float wy, float sx, vec3 lit) {
	float d = nearness(wy);
	vec3 sky = sky_at(vec2(sx, HORIZON - (wy + 0.5 - HORIZON) * MIRROR + tilt(wx, wy)));
	vec3 col = mix(sky, sea.rgb * lit, mix(0.08, 0.34, d)) * mix(0.98, 0.86, d);
	// Now and then a ripple catches the light along its crest.
	float len = 4.0 + floor(hash(vec2(wy, 13.0)) * 6.0);
	float seg = floor((wx + time * (2.0 + hash(vec2(wy, 17.0)) * 3.0)) / len);
	return hash(vec2(seg, wy + 0.25)) < 0.02 + 0.02 * rough ? mix(col, vec3(1.0), 0.12) : col;
}

// A light's path down the sea: a soft stepped column, wider nearer the viewer, with short dashes twinkling in it.
float path(float wx, float wy, float sx, vec2 at, float width, float light) {
	if (light <= 0.0) {
		return 0.0;
	}
	float across = abs(sx - at.x) / (width * mix(0.45, 1.0, nearness(wy)));
	if (across >= 1.0) {
		return 0.0;
	}
	float soft = floor((1.0 - across * across) * 3.0) / 3.0 * 0.22;
	float cell = floor((wx + floor(hash(vec2(wy, 5.0)) * 4.0)) / 3.0);
	float h = hash(vec2(cell, wy * 1.37));
	float twinkle = sin(time * (1.4 + h * 3.0) + h * 40.0);
	float spark = h > 0.5 && twinkle > 0.3 && hash(vec2(cell, wy + 9.0)) > across * across ? 0.85 : 0.0;
	return max(soft, spark) * light;
}

vec3 lit_water(float wx, float wy, float sx, vec3 lit) {
	vec3 col = water_at(wx, wy, sx, lit);
	col = mix(col, sun_colour.rgb, path(wx, wy, sx, sun, sun_width, sun_light));
	return mix(col, moon_colour.rgb, path(wx, wy, sx, moon, MOON_WIDTH, moon_light));
}
