extends Control
## Town menu: the places in town as a list on the left, over a plain backdrop.
## The places come from data/town/places.json. A place with a "scene" opens
## it; the rest do nothing yet.

const PLACES_PATH := "res://data/town/places.json"

const PAPER := Color("efe4c8")
const INK := Color("3b2f22")
const PANEL := Color("2a2118")

const LIST_WIDTH := 300.0
const BUTTON_HEIGHT := 54.0      ## Big enough to tap on a phone.
const FONT_SIZE := 22

## Parchment strip behind each button, drawn at SCROLL_SCALE so its pixels
## stay square. The curled ends and torn edges (in source pixels) don't stretch.
const SCROLL_TEXTURE := "res://assets/ui/scroll_button.png"
const SCROLL_SCALE := 2
const SCROLL_EDGES := {"left": 10, "right": 10, "top": 5, "bottom": 9}
## Room the text keeps from the edges (scaled pixels), so it sits on the paper
## and not on the curls underneath.
const TEXT_MARGINS := {"left": 24, "right": 24, "top": 4, "bottom": 14}


func _ready() -> void:
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
	for place in _load_places(PLACES_PATH):
		var button := Button.new()
		button.text = place.get("name", "?")
		button.custom_minimum_size.y = BUTTON_HEIGHT
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		_style_as_scroll(button, scroll)
		var scene: String = place.get("scene", "")
		if scene != "":
			button.pressed.connect(func(): get_tree().change_scene_to_file(scene))
		list.add_child(button)


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
		for side in TEXT_MARGINS:
			box.set("content_margin_" + side, TEXT_MARGINS[side])
		box.modulate_color = tints[state]
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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


func _load_places(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("No town places at %s." % path)
		return []
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary and data.get("places") is Array:
		return data["places"]
	push_warning("Could not read town places from %s." % path)
	return []
