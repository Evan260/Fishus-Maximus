class_name LineFight
extends RefCounted
## A fish on the line. It runs and rests by turns until it tires; reeling while it runs strains the line, reeling
## while it rests brings it in, and leaving the line slack too long lets the hook slip.

const SNAP_AFTER := 0.4
const SLACK := 0.1

var fish := ""
var pounds := 0.0
var tension := 0.0
var distance := 120.0
var state := "fighting"
var gentle := false
var _power := 0.5
var _energy := 1.0
var _full_energy := 1.0
var _pull := 1.0
var _strength := 0.6
var _slip_after := 2.5
var _running := true
var _phase_left := 1.0
var _over := 0.0
var _slack := 0.0
var _rng: RandomNumberGenerator


func setup(id: String, lb: float, gear: Dictionary, is_gentle: bool, rng: RandomNumberGenerator) -> void:
	fish = id
	pounds = lb
	gentle = is_gentle
	_rng = rng
	var f: Dictionary = Data.fish[id]
	var size := clampf((lb - float(f["pounds"][0])) / maxf(0.01, float(f["pounds"][1]) - float(f["pounds"][0])), 0.0, 1.0)
	_pull = float(gear.get("pull", 1))
	_strength = float(gear.get("strength", 0.6))
	_slip_after = 1.5 + 0.5 * float(gear.get("hold", 1))
	_power = float(f["strength"]) / 10.0 * (0.55 + 0.45 * size) / (0.8 + 0.2 * _pull)
	_full_energy = float(f["stamina"]) * (0.6 + 0.8 * size) / (1.0 + 0.3 * (_pull - 1.0))
	_energy = _full_energy
	_running = true
	_phase_left = _rng.randf_range(1.0, 3.0)


func resting() -> bool:
	return state == "fighting" and not _running


func tired() -> float:
	return 1.0 - _energy / maxf(0.01, _full_energy)


func step(reeling: bool, delta: float) -> void:
	if state != "fighting":
		return
	_phase_left -= delta
	if _phase_left <= 0.0:
		_running = not _running and _energy > 0.0
		_phase_left = _rng.randf_range(1.0, 3.0) if _running else _rng.randf_range(1.0, 2.0)
	var fresh := _energy / maxf(0.01, _full_energy)
	var target := 0.0
	if _running:
		_energy = maxf(0.0, _energy - delta * (1.5 if reeling else 1.0))
		if _energy <= 0.0:
			_running = false
			_phase_left = 9999.0
		var run_speed := (15.0 + _power * 40.0) * (0.4 + 0.6 * fresh)
		distance += run_speed * (0.4 if reeling else 1.0) * delta
		target = (0.35 + _power * 0.9) if reeling else (0.15 + _power * 0.35)
	elif reeling:
		distance -= (18.0 + _pull * 8.0) * delta
		target = 0.25 + _power * 0.25
	tension = lerpf(tension, target, minf(1.0, 2.5 * delta))
	if gentle:
		tension = minf(tension, _strength * 0.9)
	_over = _over + delta if tension > _strength else 0.0
	_slack = _slack + delta if tension < SLACK else 0.0
	if distance <= 0.0:
		distance = 0.0
		state = "landed"
	elif not gentle and _over >= SNAP_AFTER:
		state = "snapped"
	elif not gentle and _slack >= _slip_after:
		state = "slipped"
