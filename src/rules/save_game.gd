extends RefCounted
## The save file: the guild (every hero and who's in the party), written as
## JSON. One save; Save in town overwrites it and the game loads it at start.
## A delve in progress isn't saved: a delve always starts fresh from town.

const Guild = preload("res://src/rules/guild.gd")

const VERSION := 1
const PATH := "user://save.json"


## The save as text.
static func to_text(guild) -> String:
	return JSON.stringify({"version": VERSION, "guild": guild.to_dict()}, "\t")


## The guild from saved text, or null if the text isn't a save we can read.
static func guild_from_text(text: String):
	var data = JSON.parse_string(text)
	if not (data is Dictionary) or not (data.get("guild") is Dictionary):
		return null
	return Guild.from_dict(data["guild"])


## Writes the save to `path`. False if it couldn't be written.
static func write(guild, path := PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save to %s (error %d)." % [path, FileAccess.get_open_error()])
		return false
	file.store_string(to_text(guild))
	file.close()
	return true


## The saved guild at `path`, or null if there's no save or it can't be read.
static func read(path := PATH):
	if not FileAccess.file_exists(path):
		return null
	var guild = guild_from_text(FileAccess.get_file_as_string(path))
	if guild == null:
		push_warning("Could not read the save at %s; starting fresh." % path)
	return guild
