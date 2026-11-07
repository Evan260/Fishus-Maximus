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
