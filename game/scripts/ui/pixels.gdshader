shader_type canvas_item;
// Draws a picture as it looks at the game's own pixels at any size or turn, and waves a fish's tail by whole texels.

// The tail beat's phase, how many texels the tail swings, and how many waves run down the body at once.
uniform float swim = 0.0;
uniform float wave = 0.0;
uniform float waves = 0.7;
// Texels of room drawn round the picture, so the pixels along its edge are never cut off when it is turned.
uniform float edge = 0.0;
// The share of its own colour the picture keeps; a fish in murky water keeps less.
uniform float keep = 1.0;

varying vec2 world;
// The fragment's own COLOR comes already multiplied by the texture at UV, so the tint is carried through here.
varying vec4 tint;

vec2 room() {
	return vec2(edge, edge + ceil(wave));
}

void vertex() {
	// Only pictures drawn centred on their node ask for room, so each corner moves out from the middle.
	VERTEX += sign(VERTEX) * room();
	UV += sign(UV - 0.5) * room() * TEXTURE_PIXEL_SIZE;
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	// Texels are counted from the corner where UV is zero, which the vertex snap puts on a whole window pixel.
	vec2 t = UV * size + room();
	mat2 by_screen = mat2(dFdx(t), dFdy(t));
	mat2 world_by_screen = mat2(dFdx(world), dFdy(world));
	vec2 at = t;
	if (abs(determinant(by_screen)) > 1e-9 && abs(determinant(world_by_screen)) > 1e-9) {
		mat2 per_game_pixel = by_screen * inverse(world_by_screen);
		at = per_game_pixel * (floor(inverse(per_game_pixel) * t) + 0.5);
	}
	vec2 texel = floor(at - room());
	if (wave > 0.0) {
		float along = (texel.x + 0.5) / size.x;
		float swing = wave * pow(max(0.0, 1.0 - along), 1.5) * sin(swim + along * waves * 6.2832);
		texel.y -= floor(swing + 0.5);
	}
	if (texel.x < 0.0 || texel.y < 0.0 || texel.x >= size.x || texel.y >= size.y) {
		COLOR = vec4(0.0);
	} else {
		COLOR = tint * texture(TEXTURE, (texel + 0.5) / size);
		COLOR.rgb = mix(vec3(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114))), COLOR.rgb, keep);
	}
}
