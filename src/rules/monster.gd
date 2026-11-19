extends "res://src/rules/fighter.gd"
## One monster in a fight. The bars, fight numbers, combat skills and level
## come from Fighter; a monster adds which type it is and what it gives when
## beaten. Types live in data/monsters, one file each. The design is under
## "Monsters" in docs/design.md.
##
## Saved and loaded as a plain Dictionary, so a floor's monsters can be kept
## with a run's save.

var type_id := ""                       ## Id from data/monsters.
var xp_reward := 0                      ## XP the party gets for beating it.
var loot: Array[String] = []            ## Item ids it drops. Items come in a later phase.


## A new monster of type `type_data` (one file from data/monsters), at full
## bars. A starting number written as [low, high] is rolled with `rng`, so
## two skeletons can have different HP. Its name is the type's name unless
## `monster_name` is given.
static func from_type(type_data: Dictionary, rng: RandomNumberGenerator, monster_name := ""):
	var data := {}
	var start: Dictionary = type_data.get("start", {})
	for key in start:
		data[key] = roll_value(start[key], rng)
	data["name"] = monster_name if monster_name != "" else str(type_data.get("name", type_data.get("id", "")))
	data["type"] = type_data.get("id", "")
	data["combat_skills"] = type_data.get("combat_skills", [])
	var rewards: Dictionary = type_data.get("rewards", {})
	data["xp_reward"] = rewards.get("xp", 0)
	data["loot"] = rewards.get("loot", [])
	return from_dict(data)


## A number, or a whole number rolled from a [low, high] pair (both included).
static func roll_value(value, rng: RandomNumberGenerator):
	if value is Array and value.size() == 2:
		var low := int(value[0])
		var high := int(value[1])
		return rng.randi_range(mini(low, high), maxi(low, high))
	return value


## What the party gets when this monster is beaten: {"xp": int, "loot": [item ids]}.
func rewards() -> Dictionary:
	return {"xp": xp_reward, "loot": loot.duplicate()}


func to_dict() -> Dictionary:
	var data := _fighter_dict()
	data["type"] = type_id
	data["xp_reward"] = xp_reward
	data["loot"] = loot.duplicate()
	return data


static func from_dict(data: Dictionary):
	var monster = new()
	monster._read_fighter(data)
	monster.type_id = str(data.get("type", ""))
	monster.xp_reward = maxi(0, int(data.get("xp_reward", 0)))
	monster.loot.assign(_strings(data.get("loot", [])))
	return monster


## Every monster type in data/monsters, keyed by id.
static func load_types(dir := "res://data/monsters") -> Dictionary:
	return load_by_id(dir)
