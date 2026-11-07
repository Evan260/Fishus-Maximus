class_name UiTheme
## The interface's look: pixel fonts drawn without smoothing, and the painted panels and buttons from assets/art/ui
## once they exist, with warm flat boxes until then.

const DIR := "res://assets/art/ui/"
const INK := Color8(58, 38, 30)
const CREAM := Color8(242, 230, 204)
const MUTED := Color8(140, 110, 84)
const GOLD := Color8(236, 196, 96)
const SEA := Color8(52, 104, 118)
const RED := Color8(168, 52, 44)
const PARCHMENT := Color8(232, 214, 176)
const WOOD := Color8(108, 70, 44)
const TEXT := 10
const HEADING := 8
const TITLE := 16

static var _theme: Theme
static var _body: FontFile
static var _title: FontFile


static func body_font() -> FontFile:
	if _body == null:
		_body = _crisp(load("res://assets/fonts/fusion-pixel-10px-proportional-latin.ttf.woff2"))
	return _body


## Silkscreen, the blocky capitals used for headings, at 8 or 16 pixels.
static func title_font() -> FontFile:
	if _title == null:
		_title = _crisp(load("res://assets/fonts/Silkscreen-Regular.ttf"))
	return _title


static func build() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = TEXT
	t.set_color("font_color", "Label", INK)
	t.set_constant("line_spacing", "Label", 0)
	for state in [["normal", "button", WOOD], ["hover", "button_hover", WOOD.lightened(0.15)], ["pressed", "button_pressed", WOOD.darkened(0.2)], ["disabled", "button_disabled", WOOD.darkened(0.45)]]:
		t.set_stylebox(state[0], "Button", _art_or_box(state[1], 5, 4, state[2], GOLD))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# The painted buttons are pale wood, so their words are dark; the flat boxes used before the art are dark wood.
	var word := INK if ResourceLoader.exists(DIR + "button.png") else CREAM
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", word)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("panel", "PanelContainer", _art_or_box("panel", 8, 8, PARCHMENT, WOOD))
	t.set_stylebox("panel", "TooltipPanel", _art_or_box("tooltip", 4, 4, CREAM, WOOD))
	t.set_color("font_color", "TooltipLabel", INK)
	for variant in [["Heading", HEADING, INK], ["Title", TITLE, GOLD], ["LightHeading", HEADING, GOLD]]:
		t.set_type_variation(variant[0], "Label")
		t.set_font("font", variant[0], title_font())
		t.set_font_size("font_size", variant[0], variant[1])
		t.set_color("font_color", variant[0], variant[2])
	t.set_type_variation("LightLabel", "Label")
	t.set_color("font_color", "LightLabel", CREAM)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_stylebox("normal", "LineEdit", _box(CREAM, WOOD, 3))
	t.set_stylebox("focus", "LineEdit", _box(CREAM, GOLD, 3))
	_theme = t
	return t


## A painted nine-slice from assets/art/ui when there is one, otherwise a flat box in the same colours.
static func _art_or_box(name: String, margin: int, content: int, fill: Color, edge: Color) -> StyleBox:
	var path := DIR + name + ".png"
	if not ResourceLoader.exists(path):
		return _box(fill, edge, content)
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = content
	s.content_margin_right = content
	s.content_margin_top = content
	s.content_margin_bottom = content
	return s


static func _box(fill: Color, edge: Color, content: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.anti_aliasing = false
	s.set_content_margin_all(content)
	return s


static func _crisp(source: FontFile) -> FontFile:
	var font: FontFile = source.duplicate()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font
