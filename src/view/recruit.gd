extends "res://src/view/main_menu.gd"
## Recruit screen: one scroll per hero class (with its badge). Pressing one
## hires a random level 1 hero of that class into the guild. The right side
## says who joined and lists the guild's heroes.

const GUILD_SCENE := "res://scenes/guild.tscn"
const TEXT_SIZE := 26

var _classes := {}
var _names := {}
var _rng := RandomNumberGenerator.new()
var _message: Label
var _roster: Label


func _fill() -> void:
	_rng.randomize()
	_classes = Hero.load_classes()
	_names = Hero.load_names()
	var ids := _classes.keys()
	ids.sort()
	for id in ids:
		var class_data: Dictionary = _classes[id]
		_add_entry(class_data.get("name", str(id).capitalize()), class_data.get("icon", ""),
				_recruit.bind(class_data))
	_add_entry("Back to guild", "", func(): get_tree().change_scene_to_file(GUILD_SCENE))
	_build_info()
	_show_roster()


func _recruit(class_data: Dictionary) -> void:
	var hero = Game.guild.recruit(class_data, _names, _rng)
	_message.text = "%s the %s joins the guild." % [hero.name, class_data.get("name", hero.class_id)]
	_show_roster()


func _build_info() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = LIST_WIDTH + 40
	box.offset_top = 40
	box.offset_right = -40
	box.add_theme_constant_override("separation", 20)
	add_child(box)
	_message = _info_label(box, "Pick a class to recruit a new level 1 hero.")
	_roster = _info_label(box, "")


func _info_label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", TEXT_SIZE)
	label.add_theme_color_override("font_color", INK)
	parent.add_child(label)
	return label


func _show_roster() -> void:
	var heroes: Array = Game.guild.heroes
	if heroes.is_empty():
		_roster.text = "The guild has no heroes yet."
		return
	var lines := ["Guild heroes (%d):" % heroes.size()]
	for hero in heroes:
		var class_name_text: String = _classes.get(hero.class_id, {}).get("name", hero.class_id.capitalize())
		lines.append("  %s  ·  %s  Lv %d" % [hero.name, class_name_text, hero.level])
	_roster.text = "\n".join(lines)
