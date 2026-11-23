extends RefCounted
## Random encounters while walking: each step has a chance of meeting a
## monster. Settings come from data/generation/encounters.json. For now it's
## one chance and one monster type; per-dungeon monster lists with their own
## odds come later. A monster may come in a group: "group_chances" gives the
## chance of each bigger group (e.g. 2 or 3), and otherwise it comes alone.

const DEFAULT_SETTINGS := {
	"chance": 0.3,           ## Chance per step, 0 to 1.
	"monster": "skeleton",   ## Monster type id from data/monsters.
	"group_chances": {},     ## Group size -> chance, e.g. {"2": 0.3, "3": 0.3}. The rest is 1.
}

const Monster = preload("res://src/rules/monster.gd")
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


## Reads encounter settings, falling back to the defaults for missing keys.
static func load_settings(path := "res://data/generation/encounters.json") -> Dictionary:
	var settings := DEFAULT_SETTINGS.duplicate()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if parsed is Dictionary:
		settings.merge(parsed, true)
	else:
		push_warning("Could not read %s, using default encounter settings." % path)
	return settings


## After one step: the monster type met, or "" if nothing. Uses `rng` so a
## delve's encounters replay the same.
static func roll(settings: Dictionary, rng: RandomNumberGenerator) -> String:
	var chance := clampf(float(settings.get("chance", 0.0)), 0.0, 1.0)
	if rng.randf() < chance:
		return str(settings.get("monster", ""))
	return ""


## Seed for the encounter rolls on one floor, kept apart from the floor's
## layout seed so walking never changes the floor.
static func floor_seed(floor_seed_value: int) -> int:
	return hash([floor_seed_value, "encounters"])


## How many monsters come together: one roll against "group_chances" (sizes
## checked smallest first, chances added up); 1 if none hits.
static func roll_group_size(settings: Dictionary, rng: RandomNumberGenerator) -> int:
	var chances = settings.get("group_chances", {})
	var roll := rng.randf()
	if not (chances is Dictionary):
		return 1
	var sizes: Array = chances.keys().map(func(k): return int(k)).filter(func(n): return n >= 2)
	sizes.sort()
	var total := 0.0
	for n in sizes:
		total += clampf(float(chances.get(str(n), chances.get(n, 0.0))), 0.0, 1.0)
		if roll < total:
			return n
	return 1


## `count` monsters of one type. With more than one, each gets a letter
## (Skeleton A, Skeleton B, ...) so the log can tell them apart.
static func spawn_group(type_data: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	var group := []
	for i in maxi(count, 1):
		var monster = Monster.from_type(type_data, rng)
		if count > 1:
			monster.name = "%s %s" % [monster.name, LETTERS[i % LETTERS.length()]]
		group.append(monster)
	return group
