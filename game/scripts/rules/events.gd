class_name Events
## The year's days out of the ordinary: the tuna run in spring, the Neptunalia on 23 July, the Saturnalia in winter,
## the pond show, and the days the dolphins come. Days are counted from 1 within each season.


static func on(day: int) -> Array[String]:
	var out: Array[String] = []
	var year_day := Clock.year_day(day)
	var season_days := int(Data.num("time.season_days", 7))
	var season := Clock.season(day)
	var in_season := year_day % season_days + 1
	if season == "spring" and in_season >= 3 and in_season <= 6:
		out.append("tuna_run")
	if season == "summer" and in_season == 4:
		out.append("neptunalia")
	if season == "winter" and in_season == 3:
		out.append("saturnalia")
	if year_day + 1 == 21:
		out.append("pond_show")
	if posmod(hash("dolphins:%d" % day), 6) == 0:
		out.append("dolphins")
	return out
