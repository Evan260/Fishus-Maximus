class_name Units
## Weights as the player reads them, in kilograms or in pounds by the settings. Every weight is kept in pounds.

const KG_PER_LB := 0.45359237


static func metric() -> bool:
	return Settings.units != "imperial"


## A fish's weight: two decimals under one of the unit, one above, as "1.4 kg" or "3.1 lb".
static func weight(lb: float) -> String:
	var v := _amount(lb)
	return _unit() % (("%.2f" % v) if v < 1.0 else ("%.1f" % v))


## A weight asked for or suited, rounded so it reads as a person would say it: two decimals under a tenth, one under
## ten, whole above.
static func need(lb: float) -> String:
	var v := _rounded(lb)
	if v < 0.1:
		return _unit() % ("%.2f" % v).trim_suffix("0")
	return _unit() % ("%.1f" % v).trim_suffix(".0")


## The weight `need` shows, back in pounds, so a fish that reads as heavy enough as the player was told always counts.
static func need_pounds(lb: float) -> float:
	return _rounded(lb) / KG_PER_LB if metric() else _rounded(lb)


static func _rounded(lb: float) -> float:
	var v := _amount(lb)
	if v < 0.1:
		return snappedf(v, 0.01)
	return snappedf(v, 0.1) if v < 10.0 else roundf(v)


## Text with each {weight} in it written as need(lb), so a request in the data reads in the chosen unit.
static func fill(text: String, lb: float) -> String:
	return text.replace("{weight}", need(lb))


static func _amount(lb: float) -> float:
	return lb * KG_PER_LB if metric() else lb


## The amount with its unit, as "%s kg", in the player's language.
static func _unit() -> String:
	return TranslationServer.translate("%s kg") if metric() else TranslationServer.translate("%s lb")
