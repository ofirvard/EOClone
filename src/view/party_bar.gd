extends HBoxContainer
## The party along the bottom of the dungeon view: one card per hero with
## the class badge on the left, then name, class and level, and the HP (red),
## SP (green) and MP (blue) bars.
## Call show_party() with the heroes, and refresh() after their numbers change.

const Motion = preload("res://src/view/motion.gd")

const PAPER := Color("efe4c8")
const INK := Color("3b2f22")
const CARD := Color("e3d5b2")
const BAR_BACK := Color("2a2118")

const CARD_WIDTH := 280.0
const BADGE_SIZE := 64.0
const BAR_HEIGHT := 16.0
const XP_HEIGHT := 4.0
const XP_COLOR := Color("6fb3e8")    ## Lighter than the MP bar so the two don't mix up.
const BARS := [
	["HP", "hp", "max_hp", Color("c0392b")],
	["SP", "sp", "max_sp", Color("3f9b4a")],
	["MP", "mp", "max_mp", Color("2f6db5")],
]

var _party: Array = []
var _cards: Array = []            ## Per hero: {"badge": TextureRect, "title": Label, "bars": [[ProgressBar, Label], ...]}.
var _classes := {}                ## Class id -> class data (name, icon, ...).


func _init() -> void:
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_CENTER


## Shows `party` (heroes). `classes` is class id -> class data, for each
## class's display name and badge.
func show_party(party: Array, classes := {}) -> void:
	_party = party
	_classes = classes
	for child in get_children():
		child.queue_free()
	_cards.clear()
	for hero in party:
		add_child(_build_card())
	refresh()


## Redraws every card from the heroes' current numbers.
func refresh() -> void:
	for i in _party.size():
		var hero = _party[i]
		var card: Dictionary = _cards[i]
		var hero_class: Dictionary = _classes.get(hero.class_id, {})
		var class_name_text: String = hero_class.get("name", hero.class_id.capitalize())
		var icon: String = hero_class.get("icon", "")
		card["badge"].texture = load(icon) if icon != "" and ResourceLoader.exists(icon) else null
		card["title"].text = "%s  ·  %s  Lv %d" % [hero.name, class_name_text, hero.level]
		var xp_bar: ProgressBar = card["xp"]
		xp_bar.max_value = maxi(hero.xp_to_next_level(), 1)
		xp_bar.value = hero.xp
		xp_bar.tooltip_text = "XP %d/%d" % [hero.xp, hero.xp_to_next_level()]
		for b in BARS.size():
			var bar: ProgressBar = card["bars"][b][0]
			var text: Label = card["bars"][b][1]
			var current: int = hero.get(BARS[b][1])
			var most: int = hero.get(BARS[b][2])
			bar.max_value = maxi(most, 1)
			bar.value = current if most > 0 else 0
			text.text = "%s %d/%d" % [BARS[b][0], current, most]


## Shows `hp` on `hero`'s HP bar without touching the hero, so a battle can
## be replayed hit by hit. refresh() puts back the real numbers.
func show_hp(hero, hp: int) -> void:
	var i := _party.find(hero)
	if i < 0:
		return
	var bar: ProgressBar = _cards[i]["bars"][0][0]
	var text: Label = _cards[i]["bars"][0][1]
	bar.value = hp
	text.text = "%s %d/%d" % [BARS[0][0], hp, hero.max_hp]


## A quick hop forward (up, toward the view) for `hero`'s card, as it attacks.
func nudge(hero) -> void:
	var i := _party.find(hero)
	if i >= 0:
		var rest := _stop_motion(i)
		_cards[i]["tween"] = Motion.hop(_cards[i]["card"], rest, Vector2.UP)


## A side-to-side shake of `hero`'s card, as they get hit.
func shake(hero) -> void:
	var i := _party.find(hero)
	if i >= 0:
		var rest := _stop_motion(i)
		_cards[i]["tween"] = Motion.shake(_cards[i]["card"], rest)


## Stops card `i`'s running animation, puts it back where it rests and
## returns that spot, so a new animation never starts from mid-way.
func _stop_motion(i: int) -> Vector2:
	var entry: Dictionary = _cards[i]
	var tween: Tween = entry.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
		entry["card"].position = entry["rest"]
	entry["rest"] = entry["card"].position
	return entry["rest"]


func _build_card() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = CARD_WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var badge := TextureRect.new()
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(badge)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)

	var title := Label.new()
	title.add_theme_color_override("font_color", INK)
	title.clip_text = true
	column.add_child(title)

	# Thin XP line just above HP: how far to the next level.
	var xp_bar := ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size.y = XP_HEIGHT
	var xp_back := StyleBoxFlat.new()
	xp_back.bg_color = BAR_BACK
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = XP_COLOR
	xp_bar.add_theme_stylebox_override("background", xp_back)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	column.add_child(xp_bar)

	var bars := []
	for entry in BARS:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = BAR_HEIGHT
		var back := StyleBoxFlat.new()
		back.bg_color = BAR_BACK
		back.set_corner_radius_all(3)
		var fill := StyleBoxFlat.new()
		fill.bg_color = entry[3]
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", back)
		bar.add_theme_stylebox_override("fill", fill)

		var text := Label.new()
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 12)
		text.add_theme_color_override("font_color", PAPER)
		bar.add_child(text)
		column.add_child(bar)
		bars.append([bar, text])

	_cards.append({"card": card, "badge": badge, "title": title, "xp": xp_bar, "bars": bars})
	return card
