shader_type canvas_item;
// Paints pixel lettering on the catch banner's linen: one ink, a few whole pixels thinner or thicker, as if brushed on.

uniform vec4 ink : source_color = vec4(0.243, 0.157, 0.118, 1.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float g = grain(floor(local));
	vec3 c = ink.rgb * (g < 0.16 ? 1.32 : (g > 0.92 ? 0.8 : 1.0));
	COLOR = vec4(c, COLOR.a);
}
