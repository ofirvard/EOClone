extends Control
## Town menu: the places in town as a list on the left, each with an icon,
## and a big picture on the right. Places and the picture come from
## data/town/places.json. A place with a "scene" opens it; the rest do
## nothing yet.

const PLACES_PATH := "res://data/town/places.json"

const PAPER := Color("efe4c8")
const INK := Color("3b2f22")
const PANEL := Color("2a2118")

const LIST_WIDTH := 440.0
const FONT_SIZE := 30
const ICON_SIZE := 42.0          ## Fits on the paper part of the scroll.
const ICON_GAP := 12.0           ## Between the icon and the text.

## Parchment strip behind each button, drawn at SCROLL_SCALE so its pixels
## stay square. The curled ends and torn edges (in source pixels) don't stretch.
const SCROLL_TEXTURE := "res://assets/ui/scroll_button.png"
const SCROLL_SCALE := 3
const SCROLL_HEIGHT := 27        ## Source pixels.
const BUTTON_HEIGHT := SCROLL_HEIGHT * SCROLL_SCALE   ## 81 px: easy to tap on a phone.
const SCROLL_EDGES := {"left": 10, "right": 10, "top": 5, "bottom": 9}
## The flat paper part of the strip, as source-pixel margins: content (icon
## and text) stays inside it, off the curls and the rolled edge underneath.
const PAPER_MARGINS := {"left": 12, "right": 12, "top": 2, "bottom": 9}


func _ready() -> void:
	var data := _load_town(PLACES_PATH)

	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.custom_minimum_size.x = LIST_WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.content_margin_left = 20
	style.content_margin_right = 20
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var list := VBoxContainer.new()
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)

	var scroll := _scaled_texture(SCROLL_TEXTURE, SCROLL_SCALE)
	for place in data.get("places", []):
		var button := Button.new()
		button.text = place.get("name", "?")
		button.custom_minimum_size.y = BUTTON_HEIGHT
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		_style_as_scroll(button, scroll)
		_add_icon(button, place.get("icon", ""))
		var scene: String = place.get("scene", "")
		if scene != "":
			button.pressed.connect(func(): get_tree().change_scene_to_file(scene))
		list.add_child(button)

	_add_picture(data.get("picture", ""))


## The big picture, filling the space right of the list. It keeps its shape
## and is cropped to fit.
func _add_picture(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var picture := TextureRect.new()
	picture.texture = load(path)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = LIST_WIDTH
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.clip_contents = true
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(picture)


## Icon at the right end of the scroll; the text starts at the left.
## It's a child picture rather than the button's own icon so it can be
## smoothed (the scroll itself keeps hard pixels).
func _add_icon(button: Button, path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _paper_margin("top")
	var paper_height := BUTTON_HEIGHT - top - _paper_margin("bottom")
	# Pinned to the right end of the paper, so the icons line up in a column.
	var right := _paper_margin("right")
	icon.anchor_left = 1.0
	icon.anchor_right = 1.0
	icon.offset_left = -right - ICON_SIZE
	icon.offset_right = -right
	icon.offset_top = top + (paper_height - ICON_SIZE) / 2.0
	icon.offset_bottom = icon.offset_top + ICON_SIZE
	button.add_child(icon)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT


## Dark ink on the parchment strip. The strip brightens under the pointer and
## darkens when pressed (the art has only one state, so it's tinted).
func _style_as_scroll(button: Button, scroll: Texture2D) -> void:
	if scroll == null:
		return
	var tints := {
		"normal": Color(0.9, 0.9, 0.9),
		"hover": Color.WHITE,
		"pressed": Color(0.72, 0.72, 0.72),
		"disabled": Color(0.6, 0.6, 0.6, 0.7),
	}
	for state in tints:
		var box := StyleBoxTexture.new()
		box.texture = scroll
		for side in SCROLL_EDGES:
			box.set("texture_margin_" + side, SCROLL_EDGES[side] * SCROLL_SCALE)
		for side in PAPER_MARGINS:
			box.set("content_margin_" + side, _paper_margin(side))
		box.modulate_color = tints[state]
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## A PAPER_MARGINS side in screen pixels.
func _paper_margin(side: String) -> float:
	return PAPER_MARGINS[side] * SCROLL_SCALE


## Loads a pixel-art texture and scales it up by a whole number with hard
## pixels, or returns null (plain buttons) if it's missing.
func _scaled_texture(path: String, factor: int) -> Texture2D:
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("No texture at %s; using plain buttons." % path)
		return null
	var image := tex.get_image()
	image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


## {"picture": path, "places": [...]} from the town file, or {} if unreadable.
func _load_town(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("No town places at %s." % path)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary and data.get("places") is Array:
		return data
	push_warning("Could not read town places from %s." % path)
	return {}
