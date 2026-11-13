class_name Clock
## Game time in minutes since the first dawn. A day is twenty minutes of daylight from five in the morning to eight in
## the evening, then five minutes of night; seven days make a season and four seasons a year.

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]


static func minutes_per_day() -> float:
	return Data.num("time.day_minutes", 20) + Data.num("time.night_minutes", 5)


## The hour of the day, from 5.0 at dawn through 20.0 at dusk, wrapping past midnight to 5.0 again.
static func hour(t: float) -> float:
	var day := Data.num("time.day_minutes", 20)
	var m := fposmod(t, minutes_per_day())
	var dawn := Data.num("time.dawn_hour", 5)
	var dusk := Data.num("time.dusk_hour", 20)
	if m < day:
		return dawn + m / day * (dusk - dawn)
	return fposmod(dusk + (m - day) / Data.num("time.night_minutes", 5) * (24.0 - dusk + dawn), 24.0)


## The time on t's day when the clock shows hour h; the hours after midnight belong to the night that ends the day.
static func at_hour(t: float, h: float) -> float:
	var day := Data.num("time.day_minutes", 20)
	var dawn := Data.num("time.dawn_hour", 5)
	var dusk := Data.num("time.dusk_hour", 20)
	var start := day_of(t) * minutes_per_day()
	if h >= dawn and h < dusk:
		return start + (h - dawn) / (dusk - dawn) * day
	return start + day + fposmod(h - dusk, 24.0) / (24.0 - dusk + dawn) * Data.num("time.night_minutes", 5)


## How many minutes of game time move the clock on by so many hours from t, since a daylight hour lasts longer than a night one.
static func minutes_for_hours(t: float, hours: float) -> float:
	var day := Data.num("time.day_minutes", 20)
	var night := Data.num("time.night_minutes", 5)
	var dawn := Data.num("time.dawn_hour", 5)
	var dusk := Data.num("time.dusk_hour", 20)
	var left := hours
	var minutes := 0.0
	while left > 0.0:
		var m := fposmod(t + minutes, minutes_per_day())
		var to_end := (day - m) if m < day else (minutes_per_day() - m)
		var rate := ((dusk - dawn) / day) if m < day else ((24.0 - dusk + dawn) / night)
		if to_end * rate >= left:
			return minutes + left / rate
		minutes += to_end
		left -= to_end * rate
	return minutes


## The part of the day at t: "dawn" and "dusk" for the hour and a half at each end of daylight, "day" or "night".
static func part_of_day(t: float) -> String:
	if is_night(t):
		return "night"
	var h := hour(t)
	if h < Data.num("time.dawn_hour", 5) + 1.5:
		return "dawn"
	if h >= Data.num("time.dusk_hour", 20) - 1.5:
		return "dusk"
	return "day"


static func is_night(t: float) -> bool:
	return fposmod(t, minutes_per_day()) >= Data.num("time.day_minutes", 20)


static func day_of(t: float) -> int:
	return int(floorf(t / minutes_per_day()))


static func year_day(day: int) -> int:
	return posmod(day, int(Data.num("time.season_days", 7)) * 4)


static func season(day: int) -> String:
	return SEASONS[year_day(day) / int(Data.num("time.season_days", 7))]


## Real seconds away turned into the minutes of game time they count for: at most the cap, never less than nothing.
static func away(seconds: float) -> float:
	return clampf(seconds / 60.0, 0.0, Data.num("time.away_cap_hours", 8) * 60.0)
