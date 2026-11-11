shader_type canvas_item;
// The beach beyond the pond and the sea washing up it: each wave breaks, runs up the sand in a sheet with a lip of foam,
// slows, and draws back, leaving the sand dark and wet where it reached until it dries. Worked out per game pixel.
#include "res://scripts/coast/water.gdshaderinc"

// The rhythm ShoreWash sets: the still line's row, how far the biggest wave runs up past it, the seconds from one wave
// to the next, the shares of its cycle spent surging and drawing back, and how far the backwash sinks.
uniform float shore = 20.0;
uniform float reach = 16.0;
uniform float period = 9.0;
uniform float surge = 0.28;
uniform float back = 0.62;
uniform float backwash = 0.18;
// The clock the waves keep, apart from the ripples' own.
uniform float wash_time = 0.0;
uniform vec4 foam : source_color = vec4(0.96, 0.95, 0.9, 1.0);

varying vec2 local;
varying vec4 lit;

void vertex() {
	local = VERTEX;
	lit = COLOR;
}

// The still water's edge along the beach, curving gently.
float still(float x) {
	return shore + 1.6 * sin(x * 0.019 + 0.7) + 0.9 * sin(x * 0.053 + 2.1);
}

// How far up the sand a wave has run a share u through its cycle, as ShoreWash.run_up works it out.
float run_up(float u) {
	if (u < surge) {
		float s = u / surge;
		return 1.0 - (1.0 - s) * (1.0 - s);
	}
	return mix(1.0, -backwash, smoothstep(0.0, 1.0, (u - surge) / back));
}

// Which wave is running at column x at time t, and how far through its cycle it is; each reaches the beach a moment
// later further along, so the front never moves as one straight line.
vec2 wave_at(float x, float t) {
	float phase = t / period + x * 0.0011 + 0.05 * sin(x * 0.009 + 0.4);
	return vec2(floor(phase), fract(phase));
}

// The size of the wave numbered n: some run far up the sand, some only a little way.
float strength(float n) {
	return 0.6 + 0.4 * hash(vec2(n, 3.7));
}

// The row the water reaches at column x and time t.
float front(float x, float t) {
	vec2 w = wave_at(x, t);
	float amp = reach * strength(w.x) * (0.86 + 0.14 * sin(x * 0.031 + w.x * 1.7));
	// The lip wavers as it runs, more while it surges than as it draws back.
	float waver = (0.6 + 0.6 * (1.0 - w.y)) * sin(x * 0.27 + t * 1.6 + w.x) * 0.6;
	return still(x) + amp * run_up(w.y) + waver;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(local);
	float x = home.x + px.x;
	float t = wash_time;
	float line = still(x);
	float edge = floor(front(x, t) + 0.5);
	vec3 sand = texture(TEXTURE, (vec2(mod(px.x, size.x), px.y) + 0.5) / size).rgb * lit.rgb;
	vec3 water = lit_water(x, home.y + px.y, px.x + 0.5 + to_sky, lit.rgb);
	// Sand lies wet where the water has been lately, drying back to its own colour over a few seconds.
	float wet = 0.0;
	for (int i = 1; i <= 10; i++) {
		if (px.y <= floor(front(x, t - float(i) * 0.5) + 0.5)) {
			wet = max(wet, 1.0 - float(i) / 11.0);
		}
	}
	vec3 damp = mix(sand, sand * vec3(0.68, 0.7, 0.74), wet);
	vec2 w = wave_at(x, t);
	float cell = floor(x / 2.0);
	vec3 white = foam.rgb * lit.rgb;
	if (px.y > edge) {
		COLOR = vec4(damp, 1.0);
		// Just left by the water, the sand shines with the film it keeps for a moment.
		if (wet > 0.85 && w.y > surge && px.y <= edge + 2.0) {
			COLOR.rgb = mix(COLOR.rgb, water, 0.35);
		}
		// Lace of foam stranded at the highest reach of the wave drawing back, breaking up as it goes.
		float top = floor(still(x) + reach * strength(w.x) * (0.86 + 0.14 * sin(x * 0.031 + w.x * 1.7)) + 0.5);
		float left = clamp((w.y - surge) / 0.4, 0.0, 1.0);
		if (w.y > surge && abs(px.y - top) < 0.5 && hash(vec2(floor(x), w.x)) > 0.35 + 0.65 * left) {
			COLOR.rgb = mix(COLOR.rgb, white, 0.7);
		}
	} else {
		float from_edge = edge - px.y;
		// Out past the still line the sea is deep enough to hide the sand; over the beach the sheet thins to its lip.
		float sheet = clamp((line - px.y) / 4.0, 0.0, 1.0);
		float cover = mix(clamp(0.42 + from_edge * 0.07, 0.42, 0.8), 1.0, sheet);
		// Shallow water over sand is lighter and greener than the sea, the sand glowing up through it.
		vec3 shallow = mix(damp * vec3(0.86, 0.96, 0.98), water * vec3(1.08, 1.16, 1.12), 0.55);
		COLOR = vec4(mix(damp, mix(shallow, water, sheet), cover), 1.0);
		// The sea above the beach fades into the band of sea behind, which draws the same water.
		COLOR.a = clamp((px.y - (line - 14.0)) / 4.0, 0.0, 1.0);
		// Streaks of foam carried in the sheet as it runs up and back.
		if (px.y > line - 1.0 && hash(vec2(floor((x + px.y * 3.0) / 3.0), floor(t * 2.0) + px.y)) > 0.93) {
			COLOR.rgb = mix(COLOR.rgb, white, 0.45);
		}
		// The lip of foam: two rows thick while the wave surges, thinning and breaking into lace as it draws back.
		float lip = w.y < surge ? 2.0 : (w.y < 0.6 ? 1.0 : 0.0);
		float bubble = hash(vec2(cell + floor(from_edge) * 13.0, w.x + floor(t * 3.0) * 0.01 * from_edge));
		if (from_edge < lip + 0.5 && bubble > (w.y < surge ? 0.1 + from_edge * 0.25 : 0.45)) {
			COLOR.rgb = mix(COLOR.rgb, white, from_edge < 0.5 ? 0.95 : 0.7 - from_edge * 0.12);
		}
		// The next wave's crest rolling in and breaking white just before it reaches the beach.
		if (w.y > 0.72) {
			float k = (w.y - 0.72) / 0.28;
			float crest = floor(line - 7.0 * (1.0 - k) + 0.5);
			float x_cell = floor((x + t * 1.5) / 3.0);
			if (abs(px.y - crest) < 0.5 && hash(vec2(x_cell, w.x)) < 0.25 + 0.7 * k) {
				COLOR.rgb = mix(COLOR.rgb, white, 0.4 + 0.5 * k);
			} else if (abs(px.y - crest - 1.0) < 0.5 && k > 0.5 && hash(vec2(x_cell, w.x + 1.0)) < k - 0.4) {
				COLOR.rgb = mix(COLOR.rgb, white, 0.45);
			}
		}
	}
}
