extends Node
## Game state that lives across scenes (autoloaded as "Game"): for now just
## the guild and its heroes. Loads the save when the game starts.

const Guild = preload("res://src/rules/guild.gd")
const SaveGame = preload("res://src/rules/save_game.gd")

var guild = Guild.new()


func _ready() -> void:
	var saved = SaveGame.read()
	if saved != null:
		guild = saved


## Saves the guild. False if it couldn't be written.
func save_game() -> bool:
	return SaveGame.write(guild)
