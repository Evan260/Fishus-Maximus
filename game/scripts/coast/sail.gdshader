shader_type canvas_item;
// Moves a boat's sail and flag by whole texels: the sail bellies out towards the bow with the wind as the boat sails,
// and the flag waves, more the further from its pole.

// The sail's corners in the boat's picture: top left, top right, bottom right and bottom left; none when all are zero.
uniform vec2 sail_tl;
uniform vec2 sail_tr;
uniform vec2 sail_br;
uniform vec2 sail_bl;
// How many texels the middle of the sail bellies out, from 0 at rest.
uniform float belly = 0.0;
// The first and last columns of a mast standing in front of the sail, which stays still as the cloth moves behind it.
uniform vec2 mast = vec2(0.0, -1.0);
// The flag: the column at its pole, the column at its free end, and its top and bottom rows; none when the rows match.
uniform vec4 flag = vec4(0.0);
// How many texels the flag's free end rises and falls, and the time it waves by.
uniform float flutter = 1.0;
uniform float clock = 0.0;
// Where his outline `man`, placed at `man_at` in the view, covers the boat, it is read from `bare`, the boat without its ropes.
uniform bool hide_ropes = false;
uniform sampler2D bare : filter_nearest;
uniform sampler2D man : filter_nearest;
uniform vec2 man_at;
uniform bool man_flip = false;
uniform bool boat_flip = false;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float line_y(vec2 a, vec2 b, float x) {
	return a.y + (b.y - a.y) * (x - a.x) / max(0.001, b.x - a.x);
}

float line_x(vec2 a, vec2 b, float y) {
	return a.x + (b.x - a.x) * (y - a.y) / (abs(b.y - a.y) < 0.001 ? 0.001 : b.y - a.y);
}

bool in_sail(vec2 p) {
	vec2 c = p + 0.5;
	return c.y >= line_y(sail_tl, sail_tr, c.x) && c.y <= line_y(sail_bl, sail_br, c.x)
		&& c.x >= line_x(sail_tl, sail_bl, c.y) && c.x <= line_x(sail_tr, sail_br, c.y);
}

bool in_flag(vec2 p) {
	return p.x >= min(flag.x, flag.y) && p.x <= max(flag.x, flag.y) && p.y >= flag.z && p.y <= flag.w;
}

bool behind_him(vec2 px, vec2 size) {
	vec2 m_size = vec2(textureSize(man, 0));
	vec2 v = vec2(boat_flip ? size.x - 1.0 - px.x : px.x, px.y) - man_at;
	if (man_flip) {
		v.x = m_size.x - 1.0 - v.x;
	}
	if (v.x < 0.0 || v.y < 0.0 || v.x >= m_size.x || v.y >= m_size.y) {
		return false;
	}
	return texelFetch(man, ivec2(v), 0).r > 0.5;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * size);
	vec2 from = px;
	bool moved = false;
	bool cleared = false;
	if (flag.w > flag.z) {
		float away = abs(px.x - flag.x);
		float reach = max(1.0, abs(flag.y - flag.x));
		float rise = floor(sin(clock * 3.1 - away * 0.9) * flutter * away / reach + 0.5);
		vec2 src = px - vec2(0.0, rise);
		if (in_flag(src)) {
			from = src;
			moved = true;
		} else if (in_flag(px)) {
			cleared = true;
		}
	}
	if (!moved && belly > 0.0 && sail_tr.x > sail_tl.x) {
		float top = line_y(sail_tl, sail_tr, px.x + 0.5);
		float bottom = line_y(sail_bl, sail_br, px.x + 0.5);
		float down = clamp((px.y + 0.5 - top) / max(1.0, bottom - top), 0.0, 1.0);
		vec2 src = px - vec2(floor(belly * sin(3.14159 * down) + 0.5), 0.0);
		if (src.x >= mast.x && src.x <= mast.y) {
			src.x = mast.x - 1.0;
		}
		bool on_mast = px.x >= mast.x && px.x <= mast.y;
		if (!on_mast && in_sail(src)) {
			from = src;
			cleared = false;
		} else if (!on_mast && in_sail(px)) {
			cleared = true;
		}
	}
	vec4 c = hide_ropes && behind_him(px, size) ? texture(bare, (from + 0.5) / size) : texture(TEXTURE, (from + 0.5) / size);
	COLOR = cleared ? vec4(0.0) : c * tint;
}
