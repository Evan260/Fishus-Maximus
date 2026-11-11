class_name ShoreWash
## The rhythm of the sea washing up the beach beyond the pond, which wash.gdshader draws per pixel: each wave surges
## up the sand fast, slows to a stop, and draws back slowly, sinking a little past the still line as the backwash runs
## out, before the next one comes in.

## Seconds from one wave to the next.
const PERIOD := 9.0
## The share of a wave's cycle spent surging up the sand, and the share then spent drawing back.
const SURGE := 0.28
const BACK := 0.62
## How far below the still line the backwash sinks, as a share of the wave's reach.
const BACKWASH := 0.18
## The still line's row in the beach picture, and how many rows the biggest wave runs up past it.
const SHORE := 20.0
const REACH := 16.0


## How far up the sand a wave has run, from 1 at its highest to slightly below 0, a share u through its cycle.
static func run_up(u: float) -> float:
	u = fposmod(u, 1.0)
	if u < SURGE:
		var s := u / SURGE
		return 1.0 - (1.0 - s) * (1.0 - s)
	return lerpf(1.0, -BACKWASH, smoothstep(0.0, 1.0, (u - SURGE) / BACK))


## Hands the rhythm to the shader that draws it.
static func set_up(m: ShaderMaterial) -> void:
	m.set_shader_parameter("period", PERIOD)
	m.set_shader_parameter("surge", SURGE)
	m.set_shader_parameter("back", BACK)
	m.set_shader_parameter("backwash", BACKWASH)
	m.set_shader_parameter("shore", SHORE)
	m.set_shader_parameter("reach", REACH)
