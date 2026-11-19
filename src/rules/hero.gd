extends "res://src/rules/fighter.gd"
## One hero's sheet. The bars, fight numbers, combat skills and level come
## from Fighter; a hero adds gender, class, exploration skills, XP, gear and
## traits. The design is under "Heroes" in docs/design.md.
##
## A hero is saved and loaded as a plain Dictionary (to_dict / from_dict),
## so the guild roster and save files stay data.

const GENDERS := ["male", "female", "unspecified"]

## XP needed to go from one level to the next. The same for every level for
## now; the real curve is decided later in Phase 2.
const XP_PER_LEVEL := 100

var gender := "unspecified"
var class_id := ""                      ## Id from data/classes.

var exploration_skills: Array[String] = []  ## Skill ids used in the dungeon.

var xp := 0                             ## XP toward the next level, not lifetime XP.

var gear := {}                          ## Slot -> item id. Filled in a later phase.
var traits: Array[String] = []          ## Trait ids. Filled in a later phase.


# --- Level and XP ------------------------------------------------------------

## Adds XP and levels up as many times as it pays for. Returns levels gained.
## A level doesn't change any numbers yet; what it gives is decided later.
func gain_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained := 0
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		gained += 1
	return gained


func xp_to_next_level() -> int:
	return XP_PER_LEVEL


# --- Saving ------------------------------------------------------------------

func to_dict() -> Dictionary:
	var data := _fighter_dict()
	data.merge({
		"gender": gender,
		"class": class_id,
		"exploration_skills": exploration_skills.duplicate(),
		"xp": xp,
		"gear": gear.duplicate(),
		"traits": traits.duplicate(),
	})
	return data


## A hero from a saved Dictionary. Missing fields keep their defaults, and
## bars without a current value start full.
static func from_dict(data: Dictionary):
	var hero = new()
	hero._read_fighter(data)
	var g := str(data.get("gender", "unspecified"))
	hero.gender = g if g in GENDERS else "unspecified"
	hero.class_id = str(data.get("class", ""))
	hero.exploration_skills.assign(_strings(data.get("exploration_skills", [])))
	hero.xp = maxi(0, int(data.get("xp", 0)))
	var saved_gear = data.get("gear", {})
	hero.gear = saved_gear.duplicate() if saved_gear is Dictionary else {}
	hero.traits.assign(_strings(data.get("traits", [])))
	return hero


# --- Classes -----------------------------------------------------------------

## A new level 1 hero of class `class_data` (one file from data/classes),
## starting with the class's numbers and skills and full bars.
static func from_class(class_data: Dictionary, hero_name: String, hero_gender := "unspecified"):
	var data: Dictionary = class_data.get("start", {}).duplicate()
	data["name"] = hero_name
	data["gender"] = hero_gender
	data["class"] = class_data.get("id", "")
	data["combat_skills"] = class_data.get("combat_skills", [])
	data["exploration_skills"] = class_data.get("exploration_skills", [])
	return from_dict(data)


## A new hero of class `class_data` with a random gender and a name from
## `names` ({gender: [names]}, see data/heroes/names.json) for that gender.
static func random_from_class(class_data: Dictionary, names: Dictionary, rng: RandomNumberGenerator):
	var hero_gender: String = GENDERS[rng.randi_range(0, GENDERS.size() - 1)]
	var choices = names.get(hero_gender, [])
	if not (choices is Array) or choices.is_empty():
		choices = ["Hero"]
	return from_class(class_data, str(choices[rng.randi_range(0, choices.size() - 1)]), hero_gender)


## {gender: [names]} from a names file, or {} if it can't be read.
static func load_names(path := "res://data/heroes/names.json") -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		return data
	push_warning("Could not read hero names from %s." % path)
	return {}


## Every hero class in data/classes, keyed by id.
static func load_classes(dir := "res://data/classes") -> Dictionary:
	return load_by_id(dir)
