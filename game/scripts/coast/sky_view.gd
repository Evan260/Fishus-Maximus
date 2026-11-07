class_name SkyView
extends Node2D
## The sky behind everything, by the hour: a gradient, the sun crossing it by day, the moon and stars at night. The
## places' land is painted in daylight and tinted by the hour's light, so the sky is drawn here rather than painted.

const KEYS := [
	[0.0, Color("#0d1530"), Color("#1d2a4d")],
	[4.5, Color("#1a2242"), Color("#3a3a5c")],
	[5.5, Color("#7f8fb5"), Color("#f0b48a")],
	[7.0, Color("#8fb8d8"), Color("#f4d9b0")],
	[10.0, Color("#6fa8d8"), Color("#bcdcef")],
	[16.0, Color("#78a9d4"), Color("#d8dcd0")],
	[18.5, Color("#c07a6a"), Color("#f3b06a")],
	[20.0, Color("#4a3c62"), Color("#c76a4e")],
	[21.0, Color("#1a2040"), Color("#3e3456")],
	[24.0, Color("#0d1530"), Color("#1d2a4d")],
]

var hour := 12.0
var horizon := 106.0


func colours(h: float) -> Array:
	for i in range(1, KEYS.size()):
		if h <= KEYS[i][0]:
			var a: Array = KEYS[i - 1]
			var b: Array = KEYS[i]
			var k: float = (h - a[0]) / maxf(0.001, b[0] - a[0])
			return [a[1].lerp(b[1], k), a[2].lerp(b[2], k)]
	return [KEYS[0][1], KEYS[0][2]]


## The light the hour casts on the land and the sea.
static func light(h: float) -> Color:
	if h < 4.5 or h >= 21.0:
		return Color(0.42, 0.5, 0.78)
	if h < 6.5:
		return Color(0.42, 0.5, 0.78).lerp(Color(1.0, 0.85, 0.76), (h - 4.5) / 2.0)
	if h < 9.0:
		return Color(1.0, 0.85, 0.76).lerp(Color.WHITE, (h - 6.5) / 2.5)
	if h < 17.0:
		return Color.WHITE
	if h < 19.5:
		return Color.WHITE.lerp(Color(1.0, 0.8, 0.66), (h - 17.0) / 2.5)
	return Color(1.0, 0.8, 0.66).lerp(Color(0.42, 0.5, 0.78), (h - 19.5) / 1.5)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := colours(hour)
	for y in range(0, int(horizon) + 40, 2):
		draw_rect(Rect2(0, y, Nav.view().x, 2), c[0].lerp(c[1], clampf(float(y) / horizon, 0.0, 1.0)))
	if hour >= 5.0 and hour < 20.0:
		var k := (hour - 5.0) / 15.0
		var sun := Vector2(60.0 + 360.0 * k, horizon - sin(k * PI) * (horizon - 20.0))
		draw_circle(sun, 9.0, Color(1.0, 0.95, 0.75, 0.35))
		draw_circle(sun, 6.0, Color(1.0, 0.96, 0.82))
	else:
		var n := fposmod(hour - 20.0, 24.0) / 9.0
		var moon := Vector2(420.0 - 360.0 * n, horizon - sin(n * PI) * (horizon - 24.0))
		for i in 40:
			var star := Vector2(fposmod(i * 97.0, Nav.view().x), fposmod(i * 41.0, horizon - 10.0))
			draw_rect(Rect2(star, Vector2.ONE), Color(1, 1, 1, 0.5 + 0.4 * sin(Time.get_ticks_msec() / 600.0 + i)))
		draw_circle(moon, 5.0, Color(0.95, 0.95, 0.88))
