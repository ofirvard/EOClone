extends RefCounted
## One fight between the party and some monsters, played out on its own.
## Each round everyone still standing acts once, fastest first (see
## Fighter.turn_order); for now every action is a basic attack on a target
## from the other side, picked by aggro. The fight ends when one side is
## all down. Every move is recorded so the view can show a log.
##
## Pure rules: uses the rng it's given, so the same seed replays the same fight.

const Fighter = preload("res://src/rules/fighter.gd")

## A fight that hasn't ended by now stops as a draw (e.g. nobody can do damage).
const MAX_ROUNDS := 50

enum Outcome { HEROES_WIN, MONSTERS_WIN, DRAW }

var heroes: Array = []
var monsters: Array = []
var outcome := Outcome.DRAW
## One entry per round, each an Array of moves:
## {"actor", "target", "damage", "target_hp", "downed"} (fighters and numbers).
var rounds: Array = []


## Plays out a whole fight and returns it.
static func fight(party: Array, foes: Array, rng: RandomNumberGenerator):
	var battle = new()
	battle.heroes = party
	battle.monsters = foes
	battle._play(rng)
	return battle


func _play(rng: RandomNumberGenerator) -> void:
	while rounds.size() < MAX_ROUNDS:
		if _all_down(monsters):
			outcome = Outcome.HEROES_WIN
			return
		if _all_down(heroes):
			outcome = Outcome.MONSTERS_WIN
			return
		var moves := []
		var standing := (heroes + monsters).filter(func(f): return not f.is_down())
		for actor in Fighter.turn_order(standing, rng):
			if actor.is_down():
				continue                       # Downed earlier this round.
			var foes := monsters if heroes.has(actor) else heroes
			var target = Fighter.pick_target(foes, rng)
			if target == null:
				break                          # The other side is all down.
			var damage: int = target.take_damage(actor.roll_attack(rng))
			moves.append({
				"actor": actor,
				"target": target,
				"damage": damage,
				"target_hp": target.hp,
				"downed": target.is_down(),
			})
		rounds.append(moves)
	outcome = Outcome.HEROES_WIN if _all_down(monsters) \
		else Outcome.MONSTERS_WIN if _all_down(heroes) else Outcome.DRAW


static func _all_down(side: Array) -> bool:
	return side.all(func(f): return f.is_down())


## XP and loot from every monster beaten: {"xp": int, "loot": [item ids]}.
## Nothing unless the heroes won.
func rewards() -> Dictionary:
	var total := {"xp": 0, "loot": []}
	if outcome != Outcome.HEROES_WIN:
		return total
	for monster in monsters:
		var r: Dictionary = monster.rewards()
		total["xp"] += r["xp"]
		total["loot"].append_array(r["loot"])
	return total


## Gives the fight's XP to every hero still standing (each gets all of it;
## how XP is shared is still open). Returns {hero: levels gained}.
func award_xp() -> Dictionary:
	var gained := {}
	var xp: int = rewards()["xp"]
	if xp <= 0:
		return gained
	for hero in heroes:
		if not hero.is_down():
			gained[hero] = hero.gain_xp(xp)
	return gained
