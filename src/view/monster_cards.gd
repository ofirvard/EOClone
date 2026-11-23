extends Control
## The monsters met, over the 3D view: a heading ("3 Skeletons appear!"), one
## card per monster side by side (picture, name, HP), and the Battle button
## under them. Cards shrink to fit the view, the more monsters the smaller.
## Cards are placed by hand rather than by a container, so a hop or shake
## is never snapped back mid-way, and nothing moves when text changes.

signal battle_pressed

const Motion = preload("res://src/view/motion.gd")

const PAPER := Color("efe4c8")
const INK := Color("3b2f22")
const DOWN := Color(1, 1, 1, 0.25)      ## A downed monster's picture fades to this.

const PICTURE_MAX := Vector2(180, 220)
const PICTURE_MIN_HEIGHT := 70.0
const PADDING := 12.0                    ## Inside each card.
const BORDER := 3.0
const GAP := 12.0                        ## Between cards, and around the row.
const MARGIN := 10.0                     ## Kept clear around the edge of the view.
const HEADING_HEIGHT := 34.0
const TEXT_HEIGHT := 56.0                ## Two lines: name and HP.
const TEXT_GAP := 8.0                    ## Between picture and text.
const BUTTON_SIZE := Vector2(140, 44)

var _monsters: Array = []
var _cards: Array = []       ## Per monster: {"card", "picture", "text", "tween", "rest"}.
var _heading: Label
var _button: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading = Label.new()
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 22)
	_heading.add_theme_color_override("font_color", INK)
	var heading_box := StyleBoxFlat.new()
	heading_box.bg_color = PAPER
	heading_box.border_color = INK
	heading_box.set_border_width_all(2)
	heading_box.set_corner_radius_all(6)
	heading_box.content_margin_left = 14
	heading_box.content_margin_right = 14
	_heading.add_theme_stylebox_override("normal", heading_box)
	add_child(_heading)
	_button = Button.new()
	_button.text = "Battle"
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", 20)
	_button.pressed.connect(func(): battle_pressed.emit())
	add_child(_button)
	resized.connect(_place)


## Shows `monsters`, each with its picture (`pictures`: monster -> texture
## path), plus the heading and the Battle button.
func show_monsters(monsters: Array, pictures: Dictionary) -> void:
	for entry in _cards:
		entry["card"].queue_free()
	_cards.clear()
	_monsters = monsters
	for monster in monsters:
		_cards.append(_build_card(pictures.get(monster, "")))
	if monsters.size() > 1:
		_heading.text = "%d %ss appear!" % [monsters.size(), _plain_name(monsters[0])]
	elif not monsters.is_empty():
		_heading.text = "A %s appears!" % _plain_name(monsters[0])
	_heading.modulate.a = 1.0
	_button.show()
	for monster in monsters:
		show_hp(monster, monster.hp)
	_place()


## The fight starts: the heading and button go (their space stays, so the
## cards don't move).
func start_fight() -> void:
	_heading.modulate.a = 0.0
	_button.hide()


func show_hp(monster, hp: int) -> void:
	var i := _monsters.find(monster)
	if i >= 0:
		_cards[i]["text"].text = "%s\nHP %d/%d" % [monster.name, hp, monster.max_hp]


## The card shakes side to side after a hit.
func shake(monster) -> void:
	var i := _monsters.find(monster)
	if i >= 0:
		_cards[i]["tween"] = Motion.shake(_cards[i]["card"], _stop_motion(i))


## The card hops down, toward the party, as the monster attacks.
func hop(monster) -> void:
	var i := _monsters.find(monster)
	if i >= 0:
		_cards[i]["tween"] = Motion.hop(_cards[i]["card"], _stop_motion(i), Vector2.DOWN)


## The monster goes down: a last shake, then its picture fades.
func fade(monster) -> void:
	var i := _monsters.find(monster)
	if i < 0:
		return
	shake(monster)
	var picture: TextureRect = _cards[i]["picture"]
	var tween := picture.create_tween()
	tween.tween_interval(Motion.SHAKE_TIME)
	tween.tween_property(picture, "modulate", DOWN, 0.4)


## After a skip or at the end: every card back in place, downed monsters
## faded.
func settle() -> void:
	for i in _cards.size():
		_stop_motion(i)
		if _monsters[i].is_down():
			_cards[i]["picture"].modulate = DOWN


## The type's name without a group letter ("Skeleton B" -> "Skeleton").
func _plain_name(monster) -> String:
	var parts: PackedStringArray = monster.name.split(" ")
	if parts.size() > 1 and parts[-1].length() == 1:
		parts.remove_at(parts.size() - 1)
	return " ".join(parts)


func _stop_motion(i: int) -> Vector2:
	var entry: Dictionary = _cards[i]
	var tween: Tween = entry.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
	entry["card"].position = entry["rest"]
	return entry["rest"]


## Sizes and places everything for the view's current size. The picture is
## the biggest that fits both the view's height and the row of cards.
func _place() -> void:
	if _cards.is_empty() or size.x <= 0:
		return
	var n := _cards.size()
	var aspect := PICTURE_MAX.x / PICTURE_MAX.y
	var extra := 2 * (PADDING + BORDER)
	var by_height := size.y - 2 * MARGIN - HEADING_HEIGHT - BUTTON_SIZE.y - 2 * GAP - TEXT_HEIGHT - TEXT_GAP - extra
	var by_width := ((size.x - 2 * MARGIN - (n - 1) * GAP) / n - extra) / aspect
	var picture_h := clampf(minf(by_height, by_width), PICTURE_MIN_HEIGHT, PICTURE_MAX.y)
	var picture := Vector2(floorf(picture_h * aspect), floorf(picture_h))
	var card_size := Vector2(picture.x + extra, picture.y + TEXT_GAP + TEXT_HEIGHT + extra)
	var row_w := n * card_size.x + (n - 1) * GAP
	var total_h := HEADING_HEIGHT + GAP + card_size.y + GAP + BUTTON_SIZE.y
	var top := floorf((size.y - total_h) / 2.0)
	var left := floorf((size.x - row_w) / 2.0)

	var heading_w := _heading.get_combined_minimum_size().x
	_heading.size = Vector2(heading_w, HEADING_HEIGHT)
	_heading.position = Vector2(floorf((size.x - heading_w) / 2.0), top)
	for i in n:
		var entry: Dictionary = _cards[i]
		entry["picture"].custom_minimum_size = picture
		entry["card"].size = card_size
		entry["rest"] = Vector2(left + i * (card_size.x + GAP), top + HEADING_HEIGHT + GAP)
		_stop_motion(i)
	_button.size = BUTTON_SIZE
	_button.position = Vector2(floorf((size.x - BUTTON_SIZE.x) / 2.0), top + HEADING_HEIGHT + GAP + card_size.y + GAP)


func _build_card(picture_path: String) -> Dictionary:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(int(BORDER))
	style.set_corner_radius_all(6)
	style.set_content_margin_all(PADDING)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	move_child(card, 0)    # Under the heading and button.

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(TEXT_GAP))
	card.add_child(column)

	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if picture_path != "" and ResourceLoader.exists(picture_path):
		picture.texture = load(picture_path)
	column.add_child(picture)

	var text := Label.new()
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size.y = TEXT_HEIGHT
	text.clip_text = true
	text.add_theme_font_size_override("font_size", 20)
	text.add_theme_color_override("font_color", INK)
	column.add_child(text)
	return {"card": card, "picture": picture, "text": text, "tween": null, "rest": Vector2.ZERO}
