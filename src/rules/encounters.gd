extends RefCounted
## Random encounters while walking: each step has a chance of meeting a
## monster. Settings come from data/generation/encounters.json. For now it's
## one chance and one monster type; per-dungeon monster lists with their own
## odds come later.

const DEFAULT_SETTINGS := {
	"chance": 0.3,           ## Chance per step, 0 to 1.
	"monster": "skeleton",   ## Monster type id from data/monsters.
}


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
