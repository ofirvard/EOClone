extends RefCounted
## What heroes and monsters share: the bars (HP, SP, MP), the numbers a fight
## uses, combat skills and level. Hero and Monster extend this. Pure rules,
## no drawing. The design is under "Heroes" and "Monsters" in docs/design.md.

var name := ""

var max_hp := 1
var hp := 1                             ## Red bar. At 0 the fighter is down for the fight.
var max_sp := 0
var sp := 0                             ## Green bar: stamina for physical skills.
var max_mp := 0
var mp := 0                             ## Blue bar: magicka for spells.

var defense := 0                        ## Percent cut to damage taken, 0 to 100.
var speed := 0                          ## Higher acts first.
var aggro := 1                          ## Weight for being picked as the other side's target.
var attack_min := 1                     ## Basic attack damage range, before the target's
var attack_max := 1                     ## defense. Weapons add to it in a later phase.

var combat_skills: Array[String] = []   ## Skill ids used in a fight.

var level := 1


# --- Bars --------------------------------------------------------------------

func is_down() -> bool:
	return hp <= 0


## Takes a hit of `amount` before defense. Returns the damage actually done.
func take_damage(amount: int) -> int:
	var done := mini(damage_after_defense(amount), hp)
	hp -= done
	return done


## `amount` with this fighter's defense taken off, rounded to the nearest point.
func damage_after_defense(amount: int) -> int:
	if amount <= 0:
		return 0
	var cut := clampi(defense, 0, 100)
	return roundi(amount * (100 - cut) / 100.0)


## Restores up to `amount` HP. Doesn't revive a downed fighter. Returns HP gained.
func heal(amount: int) -> int:
	if is_down() or amount <= 0:
		return 0
	var gained := mini(amount, max_hp - hp)
	hp += gained
	return gained


## Spends `cost` SP if there's enough. Returns whether it was spent.
func spend_sp(cost: int) -> bool:
	if cost > sp:
		return false
	sp -= cost
	return true


## Spends `cost` MP if there's enough. Returns whether it was spent.
func spend_mp(cost: int) -> bool:
	if cost > mp:
		return false
	mp -= cost
	return true


## Damage of one basic attack, before the target's defense. Uses `rng` so
## a fight replays the same.
func roll_attack(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(attack_min, attack_max)


## Every bar full; a downed fighter is back on their feet.
func rest() -> void:
	hp = max_hp
	sp = max_sp
	mp = max_mp


# --- Fight rules -------------------------------------------------------------

## Chance (0 to 1) that the other side picks `fighter` from `side`: its aggro
## over the aggro of everyone on `side` still standing. 0 if it's down.
static func target_chance(side: Array, fighter) -> float:
	if fighter.is_down():
		return 0.0
	var total := _standing_aggro(side)
	return float(maxi(fighter.aggro, 0)) / total if total > 0 else 0.0


## Picks a target from `side`, among those still standing, weighted by
## aggro. null if everyone is down. Uses `rng` so a fight replays the same.
static func pick_target(side: Array, rng: RandomNumberGenerator):
	var total := _standing_aggro(side)
	if total <= 0:
		# Nobody draws attention: any standing fighter, evenly.
		var standing := side.filter(func(f): return not f.is_down())
		return null if standing.is_empty() else standing[rng.randi_range(0, standing.size() - 1)]
	var roll := rng.randi_range(1, total)
	for fighter in side:
		if fighter.is_down():
			continue
		roll -= maxi(fighter.aggro, 0)
		if roll <= 0:
			return fighter
	return null


## `fighters` (heroes and monsters together) sorted fastest first. Each gets
## one seeded roll, used only to break ties in speed, so the same rng seed
## gives the same order. A placeholder: see "A better turn order" in the design.
static func turn_order(fighters: Array, rng: RandomNumberGenerator) -> Array:
	var rolled := []
	for fighter in fighters:
		rolled.append([fighter, rng.randi()])
	rolled.sort_custom(func(a, b):
		if a[0].speed != b[0].speed:
			return a[0].speed > b[0].speed
		return a[1] > b[1])
	return rolled.map(func(pair): return pair[0])


static func _standing_aggro(side: Array) -> int:
	var total := 0
	for fighter in side:
		if not fighter.is_down():
			total += maxi(fighter.aggro, 0)
	return total


# --- Saving ------------------------------------------------------------------

## The shared fields as a Dictionary; Hero and Monster add their own.
func _fighter_dict() -> Dictionary:
	return {
		"name": name,
		"max_hp": max_hp, "hp": hp,
		"max_sp": max_sp, "sp": sp,
		"max_mp": max_mp, "mp": mp,
		"defense": defense,
		"speed": speed,
		"aggro": aggro,
		"attack_min": attack_min,
		"attack_max": attack_max,
		"combat_skills": combat_skills.duplicate(),
		"level": level,
	}


## Reads the shared fields from `data`. Missing fields keep their defaults,
## bars without a current value start full, and bad values are kept in range.
func _read_fighter(data: Dictionary) -> void:
	name = str(data.get("name", ""))
	max_hp = maxi(1, int(data.get("max_hp", 1)))
	max_sp = maxi(0, int(data.get("max_sp", 0)))
	max_mp = maxi(0, int(data.get("max_mp", 0)))
	hp = clampi(int(data.get("hp", max_hp)), 0, max_hp)
	sp = clampi(int(data.get("sp", max_sp)), 0, max_sp)
	mp = clampi(int(data.get("mp", max_mp)), 0, max_mp)
	defense = clampi(int(data.get("defense", 0)), 0, 100)
	speed = int(data.get("speed", 0))
	aggro = maxi(0, int(data.get("aggro", 1)))
	attack_min = maxi(0, int(data.get("attack_min", 1)))
	attack_max = maxi(attack_min, int(data.get("attack_max", attack_min)))
	combat_skills.assign(_strings(data.get("combat_skills", [])))
	level = maxi(1, int(data.get("level", 1)))


static func _strings(list) -> Array:
	return list.map(func(v): return str(v)) if list is Array else []


## Every .json file in `dir` with an "id", keyed by id. Files that can't be
## read are skipped with a warning. Used for hero classes and monster types.
static func load_by_id(dir: String) -> Dictionary:
	var found := {}
	for file_name in DirAccess.get_files_at(dir):
		if not file_name.ends_with(".json"):
			continue
		var path := dir.path_join(file_name)
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and str(data.get("id", "")) != "":
			found[data["id"]] = data
		else:
			push_warning("Could not read %s." % path)
	return found
