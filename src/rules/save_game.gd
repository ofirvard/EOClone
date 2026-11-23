extends RefCounted
## The save file: the guild (every hero and who's in the party), written as
## JSON. One save; Save in town overwrites it and the game loads it at start.
## A delve in progress isn't saved: a delve always starts fresh from town.
##
## Writing is safe against being cut off (a crash, a phone battery dying):
## the save is written to a temporary file first and only then swapped in,
## so the old save stays whole until the new one is. A save that can't be
## read is copied aside (save.broken.json) before anything can overwrite it.

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


## Writes the save to `path`. False if it couldn't be written, in which case
## the save that was there before is left as it was.
static func write(guild, path := PATH) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save to %s (error %d)." % [temp, FileAccess.get_open_error()])
		return false
	file.store_string(to_text(guild))
	var error := file.get_error()
	file.close()
	if error != OK:
		push_warning("Could not write the save (error %d)." % error)
		DirAccess.remove_absolute(temp)
		return false
	error = DirAccess.rename_absolute(temp, path)
	if error != OK:
		push_warning("Could not move the new save into place (error %d)." % error)
		DirAccess.remove_absolute(temp)
		return false
	return true


## The saved guild at `path`, or null if there's no save or it can't be read.
## An unreadable save is copied to `<name>.broken.json` first, so a later Save
## can't wipe out the only copy.
static func read(path := PATH):
	if not FileAccess.file_exists(path):
		return null
	var guild = guild_from_text(FileAccess.get_file_as_string(path))
	if guild == null:
		var broken := broken_path(path)
		DirAccess.copy_absolute(path, broken)
		push_warning("Could not read the save at %s; starting fresh. It was kept as %s." % [path, broken])
	return guild


## Where an unreadable save at `path` is kept.
static func broken_path(path := PATH) -> String:
	return path.get_basename() + ".broken." + path.get_extension()
