class_name LineFight
extends RefCounted
## A fish on the line. It runs and rests by turns until it tires, a big or strong fish running more often and for
## longer. Reeling while it runs soon breaks the line, giving line keeps it safe, reeling while it rests brings it in,
## and a line left slack too long lets the hook slip.

var fish := ""
var pounds := 0.0
## How hard the line is pulled, as a share of what it can bear: 1 is breaking.
var tension := 0.0
var distance := 120.0
var state := "fighting"
var gentle := false
var _power := 0.5
var _energy := 1.0
var _full_energy := 1.0
var _pull := 1.0
var _rise := 1.0
var _slip_after := 2.5
var _running := true
var _phase_left := 1.0
var _over := 0.0
var _slack := 0.0
var _rng: RandomNumberGenerator
## The fight's numbers from balance.json, read once.
var _k := {}


func setup(id: String, lb: float, gear: Dictionary, is_gentle: bool, rng: RandomNumberGenerator) -> void:
	fish = id
	pounds = lb
	gentle = is_gentle
	_rng = rng
	_k = Data.value("fishing.fight", {})
	var f: Dictionary = Data.fish[id]
	var size := clampf((lb - float(f["pounds"][0])) / maxf(0.01, float(f["pounds"][1]) - float(f["pounds"][0])), 0.0, 1.0)
	_pull = float(gear.get("pull", 1))
	_slip_after = _n("slip_seconds") + _n("slip_per_hold") * float(gear.get("hold", 1))
	var by_size: Array = _pair("size_power")
	_power = clampf(float(f["strength"]) / 10.0 * lerpf(by_size[0], by_size[1], size) / (1.0 + _n("rod_eases") * (_pull - 1.0)), 0.0, 1.0)
	by_size = _pair("size_energy")
	_full_energy = (_n("energy") + _n("energy_per_stamina") * float(f["stamina"])) * lerpf(by_size[0], by_size[1], size) \
		/ (1.0 + _n("rod_tires") * (_pull - 1.0))
	_energy = _full_energy
	var breaks: Array = _pair("break_seconds")
	_rise = (1.0 - _n("rest_tension")) / (lerpf(breaks[0], breaks[1], _power) * float(gear.get("strength", 0.6)))
	tension = _n("rest_tension")
	_running = true
	_phase_left = _run_seconds()


func resting() -> bool:
	return state == "fighting" and not _running


func running() -> bool:
	return state == "fighting" and _running


func tired() -> float:
	return 1.0 - _energy / maxf(0.01, _full_energy)


func step(reeling: bool, delta: float) -> void:
	if state != "fighting":
		return
	_phase_left -= delta
	if _phase_left <= 0.0:
		_running = not _running and _energy > 0.0
		_phase_left = _run_seconds() if _running else _rest_seconds()
	if _running:
		var fresh := _energy / maxf(0.01, _full_energy)
		_energy = maxf(0.0, _energy - delta * (_n("tire_against") if reeling else 1.0))
		if _energy <= 0.0:
			_running = false
			_phase_left = INF
		var speeds: Array = _pair("run_speed")
		distance += lerpf(speeds[0], speeds[1], _power) * (0.4 + 0.6 * fresh) * (_n("against_run") if reeling else 1.0) * delta
	elif reeling:
		distance -= (_n("reel_speed") + _n("reel_per_pull") * _pull) * delta
	if _running and reeling:
		tension += _rise * delta
	else:
		var target := _n("run_tension") if _running else (_n("rest_tension") if reeling else 0.0)
		tension = lerpf(tension, target, minf(1.0, _n("ease") * delta))
	if gentle:
		tension = minf(tension, _n("gentle_cap"))
	_over = _over + delta if tension > 1.0 else 0.0
	_slack = _slack + delta if tension < _n("slack") else 0.0
	if distance <= 0.0:
		distance = 0.0
		state = "landed"
	elif not gentle and _over >= _n("snap_after"):
		state = "snapped"
	elif not gentle and _slack >= _slip_after:
		state = "slipped"


## A run is longer for a stronger fish and shorter as it tires.
func _run_seconds() -> float:
	var r: Array = _pair("run_seconds")
	return lerpf(r[0], r[1], _power) * _vary() * (0.5 + 0.5 * _energy / maxf(0.01, _full_energy))


## A rest is shorter for a stronger fish, so it runs more often.
func _rest_seconds() -> float:
	var r: Array = _pair("rest_seconds")
	return lerpf(r[0], r[1], _power) * _vary()


func _vary() -> float:
	return _rng.randf_range(1.0 - _n("vary"), 1.0 + _n("vary"))


func _n(key: String) -> float:
	return float(_k.get(key, 0.0))


func _pair(key: String) -> Array:
	return _k.get(key, [0.0, 0.0])
