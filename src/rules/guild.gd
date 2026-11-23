extends RefCounted
## The guild: every hero you've hired (the roster), and which of them are in
## the party that goes on delves. Kept for the whole session; saving comes
## later.

const Hero = preload("res://src/rules/hero.gd")

const MAX_PARTY := 5      ## Most heroes in the party at once.

var heroes: Array = []    ## Everyone in the guild, in order of hiring.
var party: Array = []     ## The heroes picked for delves, in party order (all in `heroes`).


## Hires a random level 1 hero of `class_data` into the guild (not the
## party). Returns the new hero.
func recruit(class_data: Dictionary, names: Dictionary, rng: RandomNumberGenerator):
	var hero = Hero.random_from_class(class_data, names, rng)
	heroes.append(hero)
	return hero


## Guild heroes who aren't in the party, in hiring order.
func reserves() -> Array:
	return heroes.filter(func(hero): return not party.has(hero))


## True when the party has MAX_PARTY heroes.
func party_full() -> bool:
	return party.size() >= MAX_PARTY


## Puts a guild hero at the end of the party. False if they aren't in the
## guild, are already in the party, or the party is full.
func add_to_party(hero) -> bool:
	if not heroes.has(hero) or party.has(hero) or party_full():
		return false
	party.append(hero)
	return true


## Takes a hero out of the party (they stay in the guild). False if they
## weren't in it.
func remove_from_party(hero) -> bool:
	if not party.has(hero):
		return false
	party.erase(hero)
	return true


## The heroes who go on a delve: party members who aren't down.
func delve_party() -> Array:
	return party.filter(func(hero): return not hero.is_down())


## False when no one can go on a delve: the party is empty or everyone in
## it is down.
func can_delve() -> bool:
	return not delve_party().is_empty()


## After the party falls in the dungeon: everyone in `fallen` who is down
## is carried back to town with 1 HP.
static func carry_back(fallen: Array) -> void:
	for hero in fallen:
		hero.revive(1)


func to_dict() -> Dictionary:
	return {
		"heroes": heroes.map(func(hero): return hero.to_dict()),
		"party": party.map(func(hero): return heroes.find(hero)),
	}


static func from_dict(data: Dictionary):
	var guild = new()
	var list = data.get("heroes", [])
	if list is Array:
		for entry in list:
			if entry is Dictionary:
				guild.heroes.append(Hero.from_dict(entry))
	var picks = data.get("party", [])
	if picks is Array:
		for i in picks:
			if (i is int or i is float) and int(i) >= 0 and int(i) < guild.heroes.size():
				guild.add_to_party(guild.heroes[int(i)])
	return guild
