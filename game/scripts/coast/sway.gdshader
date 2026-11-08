shader_type canvas_item;
// A plant on the sea floor swaying in the water by whole texels, most at its tips and not at all at its roots.

// The plant's top and root rows in its picture, and how many texels its tips sway.
uniform float top = 0.0;
uniform float root = 48.0;
uniform float amount = 1.5;
uniform float phase = 0.0;
uniform float time = 0.0;
// The share of its own colour the plant keeps, seen through murky water.
uniform float keep = 1.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * size);
	float up = clamp((root - px.y) / max(1.0, root - top), 0.0, 1.0);
	float wave = sin(time * 1.1 + phase - px.y * 0.09) + 0.35 * sin(time * 2.3 + phase * 1.7 - px.y * 0.21);
	float x = px.x - floor(wave * amount * up * up + 0.5);
	COLOR = x < 0.0 || x >= size.x ? vec4(0.0) : texture(TEXTURE, (vec2(x, px.y) + 0.5) / size) * tint;
	COLOR.rgb = mix(vec3(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114))), COLOR.rgb, keep);
}
