extends "res://src/view/main_menu.gd"
## Manage party: two lists side by side, the guild's other heroes on the
## left and the party on the right, with arrow buttons between them. Click a
## hero to pick them, then an arrow to move them across. Dragging a hero to
## the other list, or double-clicking, moves them straight away.

const GUILD_SCENE := "res://scenes/guild.tscn"
const TEXT_SIZE := 22
const CARD := Color("e3d5b2")
const PICKED := Color("c9b98f")

var _classes := {}
var _reserve_list: ItemList
var _party_list: ItemList
var _join_button: Button
var _leave_button: Button
var _party_heading: Label


func _fill() -> void:
	_classes = Hero.load_classes()
	_add_entry("Back to guild", "", func(): get_tree().change_scene_to_file(GUILD_SCENE))
	_build_lists()
	_show_lists()


func _build_lists() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = LIST_WIDTH + 30
	row.offset_right = -30
	row.offset_top = 30
	row.offset_bottom = -30
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	_reserve_list = _hero_list(row, "Guild")

	var arrows := VBoxContainer.new()
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	arrows.add_theme_constant_override("separation", 16)
	row.add_child(arrows)
	_join_button = _arrow_button(arrows, "→", "Move the picked hero into the party", _join)
	_leave_button = _arrow_button(arrows, "←", "Move the picked hero out of the party", _leave)

	_party_list = _hero_list(row, "Party")
	_party_heading = _party_list.get_parent().get_child(0)

	_reserve_list.item_selected.connect(func(_i): _party_list.deselect_all(); _update_arrows())
	_party_list.item_selected.connect(func(_i): _reserve_list.deselect_all(); _update_arrows())
	_reserve_list.item_activated.connect(func(_i): _join())
	_party_list.item_activated.connect(func(_i): _leave())
	for list in [_reserve_list, _party_list]:
		list.set_drag_forwarding(_drag_hero.bind(list), _can_drop_hero.bind(list), _drop_hero.bind(list))


## A titled list of heroes filling its half of the row.
func _hero_list(parent: Control, title: String) -> ItemList:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", FONT_SIZE)
	heading.add_theme_color_override("font_color", INK)
	column.add_child(heading)

	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_font_size_override("font_size", TEXT_SIZE)
	list.add_theme_color_override("font_color", INK)
	list.add_theme_color_override("font_selected_color", INK)
	list.add_theme_color_override("font_hovered_color", INK)
	list.add_theme_color_override("font_hovered_selected_color", INK)
	list.add_theme_constant_override("v_separation", 10)
	list.add_theme_constant_override("icon_margin", 10)
	list.fixed_icon_size = Vector2i(40, 40)
	var back := StyleBoxFlat.new()
	back.bg_color = CARD
	back.border_color = INK
	back.set_border_width_all(2)
	back.set_corner_radius_all(4)
	back.set_content_margin_all(10)
	list.add_theme_stylebox_override("panel", back)
	list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var picked := StyleBoxFlat.new()
	picked.bg_color = PICKED
	picked.set_corner_radius_all(4)
	for state in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus"]:
		list.add_theme_stylebox_override(state, picked)
	column.add_child(list)
	return list


func _arrow_button(parent: Control, text: String, tip: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(72, 72)
	button.add_theme_font_size_override("font_size", 36)
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button


## Refills both lists from the guild. `pick` stays selected if given.
func _show_lists(pick = null) -> void:
	_fill_list(_reserve_list, Game.guild.reserves(), pick)
	_fill_list(_party_list, Game.guild.party, pick)
	_party_heading.text = "Party (%d/%d)" % [Game.guild.party.size(), Game.guild.MAX_PARTY]
	_update_arrows()


func _fill_list(list: ItemList, heroes: Array, pick) -> void:
	list.clear()
	for hero in heroes:
		var hero_class: Dictionary = _classes.get(hero.class_id, {})
		var icon_path: String = hero_class.get("icon", "")
		var icon: Texture2D = load(icon_path) if icon_path != "" and ResourceLoader.exists(icon_path) else null
		# The badge shows the class; the name goes in the tooltip to keep lines short.
		var text := "%s  Lv %d  HP %d/%d" % [hero.name, hero.level, hero.hp, hero.max_hp]
		var i := list.add_item(text, icon)
		list.set_item_tooltip(i, "%s, %s" % [hero.name, hero_class.get("name", hero.class_id.capitalize())])
		list.set_item_metadata(i, hero)
		if hero == pick:
			list.select(i)


func _picked(list: ItemList):
	var picks := list.get_selected_items()
	return list.get_item_metadata(picks[0]) if not picks.is_empty() else null


func _join() -> void:
	var hero = _picked(_reserve_list)
	if hero != null and Game.guild.add_to_party(hero):
		_show_lists(hero)


func _leave() -> void:
	var hero = _picked(_party_list)
	if hero != null and Game.guild.remove_from_party(hero):
		_show_lists(hero)


# --- Drag and drop ----------------------------------------------------------

## Starts dragging the hero under the pointer in `list`, with their line as
## the preview.
func _drag_hero(at: Vector2, list: ItemList):
	var i := list.get_item_at_position(at, true)
	if i < 0:
		return null
	list.select(i)
	list.item_selected.emit(i)
	var preview := Label.new()
	preview.text = list.get_item_text(i)
	preview.add_theme_font_size_override("font_size", TEXT_SIZE)
	preview.add_theme_color_override("font_color", INK)
	list.set_drag_preview(preview)
	return {"hero": list.get_item_metadata(i), "from": list}


## A hero can be dropped on the other list, not back on their own, and not
## into a full party.
func _can_drop_hero(_at: Vector2, data, list: ItemList) -> bool:
	if list == _party_list and Game.guild.party_full():
		return false
	return data is Dictionary and data.has("hero") and data.get("from") != list


func _drop_hero(_at: Vector2, data, list: ItemList) -> void:
	var hero = data["hero"]
	var moved: bool = Game.guild.add_to_party(hero) if list == _party_list else Game.guild.remove_from_party(hero)
	if moved:
		_show_lists(hero)


func _update_arrows() -> void:
	_join_button.disabled = _picked(_reserve_list) == null or Game.guild.party_full()
	_leave_button.disabled = _picked(_party_list) == null
