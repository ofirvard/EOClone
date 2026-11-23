extends Control
## A town menu: entries as a list on the left, each with an icon, and a big
## picture on the right. Entries and the picture come from a data file
## (data/town/places.json for the town, data/town/guild.json for the guild
## hall). An entry with a "scene" opens it, one with an "action" does it
## ("save" saves the game, "delve" enters the dungeon if there's a party);
## the rest do nothing yet.
## With "show_party": true the party's hero cards sit at the bottom left of
## the picture.

## The menu's data file; each scene using this script sets its own.
const DUNGEON_SCENE := "res://scenes/map_preview.tscn"
const PartyBar = preload("res://src/view/party_bar.gd")
const Hero = preload("res://src/rules/hero.gd")

@export_file("*.json") var places_path := "res://data/town/places.json"

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


var _list: VBoxContainer
var _scroll: Texture2D


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

	_list = VBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override("separation", 6)
	panel.add_child(_list)

	_scroll = _scaled_texture(SCROLL_TEXTURE, SCROLL_SCALE)
	_fill()


## Adds the entries and the picture. Menus that build their list from
## something other than a places file (like Recruit) override this.
func _fill() -> void:
	var data := _load_town(places_path)
	for place in data.get("places", []):
		var scene: String = place.get("scene", "")
		var action: String = place.get("action", "")
		var on_press := Callable()
		if scene != "":
			on_press = func(): get_tree().change_scene_to_file(scene)
		elif action != "":
			on_press = _do_action.bind(action)
		_add_entry(place.get("name", "?"), place.get("icon", ""), on_press)
	_add_picture(data.get("picture", ""))
	if data.get("show_party", false):
		_add_party()


func _do_action(action: String) -> void:
	match action:
		"delve":
			if Game.guild.can_delve():
				get_tree().change_scene_to_file(DUNGEON_SCENE)
			elif Game.guild.party.is_empty():
				_notice("Your party is empty. Pick heroes in the Guild hall first.")
			else:
				_notice("Everyone in your party is down. Pick other heroes in the Guild hall.")
		"save":
			_notice("Game saved." if Game.save_game() else "Could not save the game.")
		_:
			push_warning("Unknown town action: %s" % action)


## A short message at the top of the picture that fades away.
func _notice(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", PAPER)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(PANEL, 0.85)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(14)
	label.add_theme_stylebox_override("normal", box)
	var holder := CenterContainer.new()    # Centers it over the picture.
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_left = LIST_WIDTH
	holder.offset_top = 30
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	add_child(holder)
	var tween := holder.create_tween()
	tween.tween_interval(1.5 + text.length() / 40.0)    # Longer messages stay longer.
	tween.tween_property(holder, "modulate:a", 0.0, 0.6)
	tween.tween_callback(holder.queue_free)


## The party's hero cards, bottom left of the picture. Nothing if the party
## is empty.
func _add_party() -> void:
	if Game.guild.party.is_empty():
		return
	var bar := PartyBar.new()
	bar.align_left()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_left = LIST_WIDTH + 20
	bar.offset_right = -20
	bar.offset_bottom = -20
	bar.offset_top = -20
	add_child(bar)
	bar.show_party(Game.guild.party, Hero.load_classes())


## One scroll button in the list. `on_press` may be empty (does nothing).
func _add_entry(text: String, icon: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_as_scroll(button, _scroll)
	_add_icon(button, icon)
	if on_press.is_valid():
		button.pressed.connect(on_press)
	_list.add_child(button)
	return button


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
