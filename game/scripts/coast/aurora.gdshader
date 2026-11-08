shader_type canvas_item;
render_mode blend_add;
// The northern lights from Farmus Maximus: curtains across the sky or streamers rising up it, green at the hem fading
// through teal to violet, drawn as in Farmus's taller sky and shrunk by `shrink` toward this sky's horizon.

uniform float amount = 0.0;
// The sprite's size and top left corner in sky pixels.
uniform vec2 area = vec2(1536.0, 400.0);
uniform vec2 origin = vec2(0.0, -120.0);
// Seconds the lights have been moving.
uniform float clock = 0.0;
// 0 for a night of curtains across the sky, 1 for a night of streamers rising up it.
uniform float rising = 0.0;
// This sky's horizon row, and how much smaller its sky is than Farmus's, whose horizon is at row 205.
uniform float horizon = 106.0;
uniform float shrink = 0.7;

float hash(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// One curtain: its lower hem waves across the sky and drifts slowly sideways.
float curtain(vec2 p, float seed, float hem, float height, float t) {
	float wave = hem + 18.0 * sin(p.x * 0.011 + seed * 2.1 + t * 0.07) + 9.0 * sin(p.x * 0.027 - seed + t * 0.11) + 4.0 * sin(p.x * 0.06 + t * 0.2 + seed * 3.0);
	float above = wave - p.y;
	// A broad glowing ribbon just above the hem, a soft spill of light below it, and a long fade upward.
	float ribbon = exp(-pow((above - 7.0) / 9.0, 2.0));
	float spill = exp(min(above, 0.0) * 0.4);
	float body = exp(-max(above, 0.0) / height) * spill;
	// Rays: thin vertical streaks that brighten and dim along the curtain.
	float rays = 0.55 + 0.45 * noise(p.x * 0.35 + seed * 13.0 + t * 0.6) * noise(p.x * 0.09 - t * 0.25 + seed);
	// Some stretches of the curtain are strong and others nearly gone, and this shifts over the night.
	float patch = smoothstep(0.25, 0.75, noise(p.x * 0.006 + seed * 5.0 + t * 0.03));
	return (ribbon * 0.9 + body * 0.55) * rays * patch;
}

// A streamer: a narrow ribbon rising almost straight up from the curtains, swaying as it goes, which wanders slowly
// across the sky and comes and goes over the night.
vec3 streamer(vec2 p, float seed, float t) {
	float base = mod(seed * 523.0 + t * 1.2, 1700.0) - 80.0;
	float sway = 18.0 * sin(p.y * 0.02 + t * 0.12 + seed * 3.0) + 5.0 * sin(p.y * 0.06 - t * 0.18 + seed);
	float dx = p.x - base - sway - (110.0 - p.y) * 0.25;
	float core = exp(-pow(dx / 11.0, 2.0)) * 0.8 + exp(-pow(dx / 30.0, 2.0)) * 0.4;
	float span = smoothstep(-60.0, 10.0, p.y) * smoothstep(150.0, 112.0, p.y);
	// Each streamer brightens and fades over the night but never quite goes out, so the sky is never empty.
	float alive = mix(0.3, 1.0, smoothstep(0.2, 0.6, noise(t * 0.015 + seed * 7.0)));
	float rays = 0.6 + 0.4 * noise(p.y * 0.3 + seed * 11.0 - t * 0.8);
	float up = clamp((110.0 - p.y) / 130.0, 0.0, 1.0);
	vec3 colour = mix(mix(vec3(0.32, 1.0, 0.62), vec3(0.2, 0.75, 0.85), smoothstep(0.15, 0.5, up)), vec3(0.62, 0.36, 0.92), smoothstep(0.55, 1.0, up));
	return colour * core * span * alive * rays;
}

void fragment() {
	vec2 here = floor(origin + UV * area);
	vec2 p = vec2(here.x / shrink, 205.0 - (horizon - here.y) / shrink);
	float t = clock;
	vec3 total = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float seed = float(i) * 1.7 + 0.4;
		float hem = 110.0 - float(i) * 28.0;
		float height = 34.0 + float(i) * 10.0;
		float c = curtain(p, seed, hem, height, t);
		// How far above the hem this pixel is, from 0 at the hem to 1 high up, picks the colour.
		float up = clamp((hem - p.y) / (height * 2.4), 0.0, 1.0);
		vec3 green = vec3(0.32, 1.0, 0.62);
		vec3 teal = vec3(0.2, 0.75, 0.85);
		vec3 violet = vec3(0.62, 0.36, 0.92);
		vec3 colour = mix(mix(green, teal, smoothstep(0.1, 0.45, up)), violet, smoothstep(0.45, 0.95, up));
		total += colour * c * (1.0 - float(i) * 0.22) * (1.0 - rising);
	}
	for (int i = 0; i < 7; i++) {
		total += streamer(p, float(i) * 2.3 + 0.7, t) * 1.5 * rising;
	}
	// Low down near the hills the light is lost in the haze.
	total *= smoothstep(196.0, 150.0, p.y);
	COLOR = vec4(total * amount * 0.7, 1.0);
}
