class_name UiTheme
## The interface's look: pixel fonts drawn without smoothing, the painted panels and buttons from assets/art/ui (warm
## flat boxes until they exist), and tick boxes, sliders and scroll bars drawn here in the same colours.

const DIR := "res://assets/art/ui/"
const INK := Color8(58, 38, 30)
const CREAM := Color8(242, 230, 204)
const MUTED := Color8(140, 110, 84)
const GOLD := Color8(236, 196, 96)
const SEA := Color8(52, 104, 118)
const RED := Color8(168, 52, 44)
const PARCHMENT := Color8(232, 214, 176)
const WOOD := Color8(108, 70, 44)
## Languages Silkscreen has every letter for; the rest draw their headings in the body font.
const SILKSCREEN := ["en", "fr", "de", "es", "it", "pt"]
## Languages drawn in Fusion Pixel's 8-pixel Chinese, Japanese and Korean fonts, whose Latin letters match them.
const HAN := {"ja": "ja", "ko": "ko", "zh_CN": "zh_hans", "zh_TW": "zh_tw"}
const FONTS := "res://assets/fonts/"

static var _theme: Theme
## Each language's fonts, made once and kept, since text drawn with a font that is then thrown away shows as blocks.
static var _bodies := {}
static var _titles := {}
static var _name_font: FontFile


## The font for running text in the current language, or in the language given.
static func body_font(locale: String = "") -> FontFile:
	var loc := _locale(locale)
	if not _bodies.has(loc):
		var ten := _crisp(load(FONTS + "fusion-pixel-10px-proportional-latin.ttf.woff2"))
		if HAN.has(loc):
			var han := _crisp(load(FONTS + "fusion-pixel-8px-proportional-%s.ttf.woff2" % HAN[loc]))
			han.fallbacks = [ten]
			_bodies[loc] = han
		else:
			_bodies[loc] = ten
	return _bodies[loc]


## Silkscreen, the blocky capitals used for headings, where it has the language's letters; otherwise the body font.
static func title_font(locale: String = "") -> FontFile:
	var loc := _locale(locale)
	if not silkscreen(loc):
		return body_font(loc)
	if not _titles.has(loc):
		var f := _crisp(load(FONTS + "Silkscreen-Regular.ttf"))
		f.fallbacks = [body_font(loc)]
		_titles[loc] = f
	return _titles[loc]


## Silkscreen in every language, for the game's own name.
static func name_font() -> FontFile:
	if _name_font == null:
		_name_font = _crisp(load(FONTS + "Silkscreen-Regular.ttf"))
	return _name_font


## Whether headings in this language are drawn in Silkscreen.
static func silkscreen(locale: String = "") -> bool:
	return _locale(locale).get_slice("_", 0) in SILKSCREEN


## The pixel size running text is drawn at, which is the size its pixel font is drawn for.
static func text_size(locale: String = "") -> int:
	return 8 if HAN.has(_locale(locale)) else 10


## A heading's pixel size, or twice that for a title: Silkscreen is drawn at 8, other fonts at their own size.
static func heading_size(big: bool = false) -> int:
	var n := 8 if silkscreen() else text_size()
	return n * 2 if big else n


## The language showing now, as the game names its translations: "zh_CN" for any simplified Chinese.
static func language() -> String:
	return _locale("")


static func _locale(locale: String) -> String:
	var loc := locale if locale != "" else TranslationServer.get_locale()
	if loc.begins_with("zh"):
		return "zh_TW" if loc.contains("TW") or loc.contains("Hant") or loc.contains("HK") else "zh_CN"
	return loc


## Switches the shared theme to the current language's fonts; every control drawn with it follows.
static func use_language() -> void:
	if _theme:
		_set_fonts(_theme)


static func _set_fonts(t: Theme) -> void:
	t.default_font = body_font()
	t.default_font_size = text_size()
	for variant in [["Heading", false], ["Title", true], ["LightHeading", false]]:
		t.set_font("font", variant[0], title_font())
		t.set_font_size("font_size", variant[0], heading_size(variant[1]))


static func build() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	_set_fonts(t)
	t.set_color("font_color", "Label", INK)
	t.set_constant("line_spacing", "Label", 0)
	for state in [["normal", "button", WOOD], ["hover", "button_hover", WOOD.lightened(0.15)], ["pressed", "button_pressed", WOOD.darkened(0.2)],
			["hover_pressed", "button_pressed", WOOD.darkened(0.2)], ["disabled", "button_disabled", WOOD.darkened(0.45)]]:
		var box := _art_or_box(state[1], 5, 4, state[2], GOLD)
		# The painted frame is four pixels thick, so the words need two more on each side to clear it.
		box.content_margin_left = 6
		box.content_margin_right = 6
		t.set_stylebox(state[0], "Button", box)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# The painted buttons are pale wood, so their words are dark; the flat boxes used before the art are dark wood.
	var word := INK if ResourceLoader.exists(DIR + "button.png") else CREAM
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", word)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("panel", "PanelContainer", _art_or_box("panel", 8, 8, PARCHMENT, WOOD))
	t.set_stylebox("panel", "TooltipPanel", _art_or_box("tooltip", 4, 4, CREAM, WOOD))
	t.set_color("font_color", "TooltipLabel", INK)
	for variant in [["Heading", INK], ["Title", GOLD], ["LightHeading", GOLD]]:
		t.set_type_variation(variant[0], "Label")
		t.set_color("font_color", variant[0], variant[1])
	t.set_type_variation("LightLabel", "Label")
	t.set_color("font_color", "LightLabel", CREAM)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_stylebox("normal", "LineEdit", _box(CREAM, WOOD, 3))
	t.set_stylebox("focus", "LineEdit", _box(CREAM, GOLD, 3))
	_check_box(t)
	_slider(t)
	_scroll_bars(t)
	_theme = t
	return t


## A tick box inked on the parchment beside its words, rather than a whole wooden button.
static func _check_box(t: Theme) -> void:
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 1
	plain.content_margin_right = 2
	for state in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckBox", plain)
	for c in ["font_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", WOOD)
	t.set_color("font_hover_pressed_color", "CheckBox", WOOD)
	t.set_color("font_disabled_color", "CheckBox", MUTED)
	t.set_constant("h_separation", "CheckBox", 5)
	var box := ["ooooooooooo", "ossssssssso"]
	for i in 8:
		box.append("osffffffffo")
	box.append("ooooooooooo")
	var tick := box.duplicate()
	tick[2] = "osfffffffko"
	tick[3] = "osffffffkko"
	tick[4] = "osfffffkkfo"
	tick[5] = "oskfffkkffo"
	tick[6] = "oskkfkkfffo"
	tick[7] = "osfkkkffffo"
	tick[8] = "osffkfffffo"
	var ink := {"o": Color8(112, 74, 48), "s": Color8(222, 194, 150), "f": Color8(252, 243, 220), "k": SEA.darkened(0.25)}
	var faded := {}
	for k in ink:
		faded[k] = ink[k].lerp(PARCHMENT, 0.55)
	for kind in [["unchecked", box], ["checked", tick], ["radio_unchecked", box], ["radio_checked", tick]]:
		t.set_icon(kind[0], "CheckBox", _pixels(kind[1], ink))
		t.set_icon(kind[0] + "_disabled", "CheckBox", _pixels(kind[1], faded))


## A volume slider: a groove cut into the parchment that fills with brass, and a small wooden knob like the buttons.
static func _slider(t: Theme) -> void:
	# A pale lower edge vanishes into the parchment and the track looks cut off, so it is edged in dark brown all round.
	var groove := [".dddd.", "dssssd", "dmmmmd", "dmmmmd", ".dddd."]
	var paper := {"d": Color8(85, 53, 41), "s": Color8(122, 88, 62)}
	t.set_stylebox("slider", "HSlider", _strip(groove, paper.merged({"m": Color8(150, 112, 78)})))
	var brass := [".dddd.", "dbbbbd", "dBBBBd", "dBBBBd", ".dddd."]
	t.set_stylebox("grabber_area", "HSlider", _strip(brass, paper.merged({"b": Color8(226, 180, 98), "B": Color8(194, 139, 58)})))
	t.set_stylebox("grabber_area_highlight", "HSlider", _strip(brass, paper.merged({"b": Color8(240, 204, 128), "B": Color8(214, 160, 74)})))
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	var knob := [".dddddd.", "dhhhhhhd", "dhffffsd", "dhffffsd", "dhfggfsd", "dhffffsd", "dhfggfsd", "dhffffsd", "dhffffsd", "dssssssd", ".dddddd."]
	var wood := {"d": Color8(54, 26, 14), "h": Color8(249, 223, 182), "f": Color8(239, 204, 144), "s": Color8(207, 157, 100), "g": Color8(170, 118, 76)}
	var lit := wood.duplicate()
	lit["f"] = Color8(250, 222, 172)
	lit["s"] = Color8(226, 180, 120)
	t.set_icon("grabber", "HSlider", _pixels(knob, wood))
	t.set_icon("grabber_highlight", "HSlider", _pixels(knob, lit))
	var dull := {}
	for k in wood:
		dull[k] = wood[k].lerp(MUTED, 0.5)
	t.set_icon("grabber_disabled", "HSlider", _pixels(knob, dull))
	t.set_constant("center_grabber", "HSlider", 0)


## Thin scroll bars in the wood of the frames, so a long list does not show the engine's grey ones.
static func _scroll_bars(t: Theme) -> void:
	for bar in [["VScrollBar", SIDE_LEFT, SIDE_RIGHT], ["HScrollBar", SIDE_TOP, SIDE_BOTTOM]]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(INK, 0.16)
		track.set_content_margin(bar[1], 2)
		track.set_content_margin(bar[2], 2)
		t.set_stylebox("scroll", bar[0], track)
		t.set_stylebox("scroll_focus", bar[0], track)
		for state in [["grabber", WOOD], ["grabber_highlight", WOOD.lightened(0.18)], ["grabber_pressed", WOOD.darkened(0.2)]]:
			var g := StyleBoxFlat.new()
			g.bg_color = state[1]
			t.set_stylebox(state[0], bar[0], g)


## A small picture drawn from rows of letters, each letter standing for a colour and a dot for a clear pixel.
static func _pixels(rows: Array, colours: Dictionary) -> ImageTexture:
	var img := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in String(rows[y]).length():
			var c := String(rows[y])[x]
			if colours.has(c):
				img.set_pixel(x, y, colours[c])
	return ImageTexture.create_from_image(img)


## A strip drawn from rows of letters that stretches along its middle, keeping its rounded ends.
static func _strip(rows: Array, colours: Dictionary) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = _pixels(rows, colours)
	s.texture_margin_left = 2
	s.texture_margin_right = 2
	s.texture_margin_top = 2
	s.texture_margin_bottom = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 3
	return s


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
