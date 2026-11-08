shader_type canvas_item;
// Everything drawn under the waterline seen through murky water, worked out as Murk.colour() does for the tests.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
// The hour's light, already on what lies underneath, so the murk works on the colours as painted.
uniform vec4 light : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(0.38, 0.47, 0.49, 1.0);
uniform float keep = 0.75;
uniform float fog = 0.1;
uniform float fog_deep = 0.45;
// The water's colours by depth, as WaterView paints them.
uniform vec4 surface : source_color = vec4(0.44, 0.72, 0.7, 1.0);
uniform vec4 mid : source_color = vec4(0.18, 0.5, 0.56, 1.0);
uniform vec4 deep : source_color = vec4(0.07, 0.2, 0.28, 1.0);
uniform float depth = 300.0;
uniform float cam_y = 0.0;

const vec3 WEIGHTS = vec3(0.299, 0.587, 0.114);

varying float below;

void vertex() {
	below = VERTEX.y + cam_y;
}

vec3 mute(vec3 c) {
	return mix(tint.rgb * dot(c, WEIGHTS) / dot(tint.rgb, WEIGHTS), c, keep);
}

void fragment() {
	vec4 under = texture(screen, SCREEN_UV);
	vec3 lit = max(light.rgb, vec3(0.05));
	// Whole game pixels, so the water's colour steps down the rows of the picture rather than the window's.
	float row = floor(below);
	float d = clamp(row / depth, 0.0, 1.0);
	vec3 water = mix(mix(surface.rgb, mid.rgb, clamp(d * 2.2, 0.0, 1.0)), deep.rgb, clamp(d * 2.0 - 0.6, 0.0, 1.0));
	vec3 m = mix(mute(under.rgb / lit), mute(water), mix(fog, fog_deep, d));
	COLOR = vec4(m * light.rgb, under.a);
}
