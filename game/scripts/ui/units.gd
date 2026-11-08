class_name Units
## Weights as the player reads them, in kilograms or in pounds by the settings. Every weight is kept in pounds.

const KG_PER_LB := 0.45359237


static func metric() -> bool:
	return Settings.units != "imperial"


## A fish's weight: two decimals under one of the unit, one above, as "1.4 kg" or "3.1 lb".
static func weight(lb: float) -> String:
	var v := _amount(lb)
	return (("%.2f" % v) if v < 1.0 else ("%.1f" % v)) + _unit()


## A weight asked for or suited, rounded so it reads as a person would say it: one decimal under ten, whole above.
static func need(lb: float) -> String:
	var v := _amount(lb)
	v = snappedf(v, 0.1) if v < 10.0 else roundf(v)
	var text := "%.1f" % v
	return (text.trim_suffix(".0")) + _unit()


## Text with each {weight} in it written as need(lb), so a request in the data reads in the chosen unit.
static func fill(text: String, lb: float) -> String:
	return text.replace("{weight}", need(lb))


static func _amount(lb: float) -> float:
	return lb * KG_PER_LB if metric() else lb


static func _unit() -> String:
	return " kg" if metric() else " lb"
