shader_type canvas_item;
// A picture whose edges fade into a plain colour, each of its pixels one even shade so the fade keeps them whole.

uniform vec4 plain : source_color;
uniform vec2 size;
// Pixels each edge fades over: left, top, right, bottom; 0 leaves that edge as painted.
uniform vec4 fade;

float side(float inside, float over) {
	return over <= 0.0 ? 1.0 : smoothstep(0.0, 1.0, clamp(inside / (over + 1.0), 0.0, 1.0));
}

void fragment() {
	vec2 texel = floor(UV * size) + 0.5;
	float keep = side(texel.x, fade.x) * side(texel.y, fade.y) * side(size.x - texel.x, fade.z) * side(size.y - texel.y, fade.w);
	COLOR = vec4(mix(plain.rgb, COLOR.rgb, keep), 1.0);
}
