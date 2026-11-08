class_name AshoreSky
extends Node
## The coast's live sky over a screen ashore, the town or the ponds: a SkyView in Nav.sky by the hour and the weather,
## its horizon kept on the picture's own, and the light the hour and the weather cast on the picture.

const RAIN_LIGHT := Color(0.72, 0.75, 0.8)

var sky: SkyView
## The row of the screen's picture, in its own pixels, where the sky meets the sea behind it.
var horizon := SkyView.HORIZON


func _init(row: float) -> void:
	horizon = row


func _ready() -> void:
	if not Game.state.has("weather"):
		Game.state["weather"] = Weather.for_day(int(Game.state["seed"]), Clock.day_of(float(Game.state["time"])))
	sky = SkyView.new()
	sky.rise_follow = 1.0
	Nav.sky.add_child(sky)


func _exit_tree() -> void:
	if is_instance_valid(sky):
		sky.queue_free()


## Lays the sky behind a picture drawn with `stage` for the time and weather now, and gives the light on the picture.
func follow(stage: Transform2D) -> Color:
	var hour := Clock.hour(float(Game.state.get("time", 0.0)))
	var weather := str(Dev.get_arg("weather", str(Game.state.get("weather", "clear"))))
	var row := (stage * Vector2(0, horizon)).y
	sky.follow(Vector2(0, CoastCamera.HOME_Y + SkyView.HORIZON - row), hour, weather)
	var light := SkyView.light(hour)
	if weather in ["rain", "storm"]:
		light *= RAIN_LIGHT
	return Color(light, 1.0)
