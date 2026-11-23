extends SceneTree
## Headless rule checks. Run from the project root:
##   godot --headless --script res://tests/run_tests.gd

const FloorGenerator = preload("res://src/rules/floor_generator.gd")
const FloorGrid = preload("res://src/rules/floor_grid.gd")
const PlayerMap = preload("res://src/rules/player_map.gd")
const Edges = preload("res://src/rules/edges.gd")
const Coords = preload("res://src/rules/coords.gd")
const Fighter = preload("res://src/rules/fighter.gd")
const Hero = preload("res://src/rules/hero.gd")
const Monster = preload("res://src/rules/monster.gd")
const Encounters = preload("res://src/rules/encounters.gd")
const Battle = preload("res://src/rules/battle.gd")
const Guild = preload("res://src/rules/guild.gd")
const SaveGame = preload("res://src/rules/save_game.gd")

const SEEDS := 300

var _failures := 0
var _checks := 0


func _init() -> void:
	var settings := FloorGenerator.load_settings("res://data/generation/floor.json")
	test_same_seed_same_floor(settings)
	test_different_seeds_differ(settings)
	test_max_size(settings)
	test_floor_seeds()
	for seed_value in SEEDS:
		check_floor(FloorGenerator.generate(seed_value, settings))
	test_edges()
	test_coords()
	test_true_walls()
	test_footsteps()
	test_drawing_walls()
	test_undo()
	test_hero_bars()
	test_hero_xp()
	test_targeting()
	test_turn_order()
	test_hero_save()
	test_classes()
	test_monsters()
	test_skeleton()
	test_encounters()
	test_battles()
	test_guild()
	test_save_game()
	test_party_falls()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func test_same_seed_same_floor(settings: Dictionary) -> void:
	for seed_value in [0, 1, 42, 123456789, -7]:
		var a := FloorGenerator.generate(seed_value, settings)
		var b := FloorGenerator.generate(seed_value, settings)
		expect(a.cells == b.cells, "seed %d gives the same floor twice" % seed_value)
		expect(a.torches == b.torches, "seed %d gives the same torches twice" % seed_value)


func test_max_size(settings: Dictionary) -> void:
	var big := settings.duplicate()
	big["width"] = 40
	big["height"] = 99
	var grid := FloorGenerator.generate(5, big)
	expect(grid.width == FloorGenerator.MAX_SIZE and grid.height == FloorGenerator.MAX_SIZE, "floors are never bigger than 26 x 26")


func test_floor_seeds() -> void:
	expect(FloorGenerator.floor_seed(42, 1) == 42, "a delve's first floor uses the delve seed")
	expect(FloorGenerator.floor_seed(42, 2) == FloorGenerator.floor_seed(42, 2), "deeper floor seeds repeat")
	var seen := {}
	for depth in range(1, 4):
		seen[FloorGenerator.floor_seed(42, depth)] = true
	expect(seen.size() == 3, "each floor of a delve has its own seed")
	expect(FloorGenerator.floor_seed(42, 2) != FloorGenerator.floor_seed(43, 2), "different delves get different deeper floors")


func test_different_seeds_differ(settings: Dictionary) -> void:
	var a := FloorGenerator.generate(1, settings)
	var b := FloorGenerator.generate(2, settings)
	expect(a.cells != b.cells, "seeds 1 and 2 give different floors")


func check_floor(grid: FloorGrid) -> void:
	var tag := "seed %d" % grid.seed_value
	expect(grid.rooms.size() >= 2, "%s has at least 2 rooms" % tag)

	var border_ok := true
	for x in grid.width:
		border_ok = border_ok and not grid.is_walkable(Vector2i(x, 0))
		border_ok = border_ok and not grid.is_walkable(Vector2i(x, grid.height - 1))
	for y in grid.height:
		border_ok = border_ok and not grid.is_walkable(Vector2i(0, y))
		border_ok = border_ok and not grid.is_walkable(Vector2i(grid.width - 1, y))
	expect(border_ok, "%s has a solid outer wall" % tag)

	var in_room := false
	for room in grid.rooms:
		in_room = in_room or room.has_point(grid.start)
	expect(grid.is_walkable(grid.start) and in_room, "%s starts on open floor in a room" % tag)

	var reach := grid.distances_from(grid.start)
	expect(reach.size() == grid.walkable_cells().size(), "%s every open cell is reachable" % tag)

	# Stairs up: solid, right behind the start, the party facing away from them.
	expect(grid.get_cell(grid.stairs_up) == FloorGrid.Cell.STAIRS_UP and not grid.is_walkable(grid.stairs_up),
		"%s has solid stairs up" % tag)
	expect(grid.stairs_up + FloorGrid.DIRECTIONS[grid.stairs_up_side] == grid.start,
		"%s starts in front of the stairs up" % tag)
	expect(grid.start_facing == grid.stairs_up_side, "%s starts facing away from the stairs" % tag)

	# Trapdoor down: walkable, reachable, in a different room from the start.
	expect(grid.get_cell(grid.stairs_down) == FloorGrid.Cell.STAIRS_DOWN and reach.has(grid.stairs_down),
		"%s has a reachable trapdoor down" % tag)
	var same_room := false
	for room in grid.rooms:
		same_room = same_room or (room.has_point(grid.start) and room.has_point(grid.stairs_down))
	expect(not same_room, "%s trapdoor is in a different room from the start" % tag)

	var counts := {}
	for c in grid.cells:
		counts[c] = counts.get(c, 0) + 1
	expect(counts.get(FloorGrid.Cell.STAIRS_UP, 0) == 1 and counts.get(FloorGrid.Cell.STAIRS_DOWN, 0) == 1,
		"%s has exactly one of each stairs" % tag)

	# Torches: on open floor, against plain rock, spread out, and some exist.
	var torches_ok := grid.torches.size() > 0
	for i in grid.torches.size():
		var t := grid.torches[i]
		var cell := Vector2i(t.x, t.y)
		var behind := cell + FloorGrid.DIRECTIONS[t.z]
		torches_ok = torches_ok and grid.is_walkable(cell) and grid.in_bounds(behind) 			and grid.get_cell(behind) == FloorGrid.Cell.WALL
		for j in i:
			var o := grid.torches[j]
			torches_ok = torches_ok and maxi(absi(t.x - o.x), absi(t.y - o.y)) >= 4
	expect(torches_ok, "%s has torches on rock walls, spread out" % tag)


func test_footsteps() -> void:
	var map := PlayerMap.new(4, 3)
	expect(not map.is_visited(Vector2i(1, 1)), "player map starts empty")
	expect(map.visit(Vector2i(1, 1)), "first visit counts as new")
	expect(not map.visit(Vector2i(1, 1)), "second visit to the same cell isn't new")
	expect(map.is_visited(Vector2i(1, 1)) and not map.is_visited(Vector2i(2, 1)), "only the stepped cell is marked")
	expect(map.visited_count == 1, "visited count ignores repeats")
	expect(not map.visit(Vector2i(4, 0)) and not map.is_visited(Vector2i(-1, 0)), "out-of-bounds cells are ignored")


func test_edges() -> void:
	var a := Vector2i(2, 3)
	expect(Edges.between(a, a + Vector2i.RIGHT) == Edges.between(a + Vector2i.RIGHT, a), "edge between two cells is the same both ways")
	expect(Edges.between(a, a + Vector2i.DOWN) == Edges.between(a + Vector2i.DOWN, a), "vertical neighbours share one edge")
	expect(Edges.between(a, a + Vector2i(1, 1)) == Edges.NONE, "diagonal cells have no edge")
	var e := Edges.between(a, a + Vector2i.RIGHT)
	expect(Edges.cells(e) == [a, a + Vector2i.RIGHT], "an edge knows its two cells")
	expect(Edges.in_bounds(Vector3i(-1, 0, Edges.VERTICAL), 4, 4), "west border line is in bounds")
	expect(not Edges.in_bounds(Vector3i(4, 0, Edges.VERTICAL), 4, 4), "lines past the east border are out")
	# Dots are cell corners: dot (3, 3) is the top-left corner of cell (3, 3).
	expect(Edges.dot_near(Vector2(3.1, 2.9)) == Vector2i(3, 3), "pointer near a corner picks that dot")
	expect(Edges.dot_near(Vector2(2.5, 3.5)) == Edges.NO_DOT, "pointer in mid-cell picks no dot")
	# The line between cells (2,3) and (3,3) runs from dot (3,3) to dot (3,4).
	expect(Edges.between_dots(Vector2i(3, 3), Vector2i(3, 4)) == [e], "two dots in a column give the line between them")
	expect(Edges.between_dots(Vector2i(3, 4), Vector2i(3, 3)) == [e], "connecting dots works both ways")
	var below := Edges.between(a, a + Vector2i.DOWN)
	expect(Edges.between_dots(Vector2i(2, 4), Vector2i(3, 4)) == [below], "two dots in a row give the horizontal line")
	var run := Edges.between_dots(Vector2i(0, 4), Vector2i(3, 4))
	expect(run.size() == 3 and run.has(below), "dots further apart give every line in between")
	expect(Edges.between_dots(Vector2i(0, 0), Vector2i(1, 1)).is_empty(), "diagonal dots give no line")
	expect(Edges.between_dots(Vector2i(2, 2), Vector2i(2, 2)).is_empty(), "a dot to itself gives no line")
	expect(Edges.near(Vector2(3.1, 3.5)) == [e], "eraser near a line finds that line")
	expect(Edges.near(Vector2(2.5, 3.5)).is_empty(), "eraser in mid-cell finds nothing")
	var at_corner := Edges.near(Vector2(3.0, 3.0))
	expect(at_corner.size() == 4, "eraser on a dot finds the four lines that meet there")
	var seg := Edges.segment(e)
	expect(seg[0] == Vector2(3, 3) and seg[1] == Vector2(3, 4), "a line's ends are its two dots")


func test_coords() -> void:
	expect(Coords.column_name(0) == "A" and Coords.column_name(25) == "Z", "columns A to Z")
	expect(Coords.column_name(26) == "AA" and Coords.column_name(31) == "AF", "columns after Z are AA, AB, ...")
	expect(Coords.column_name(701) == "ZZ" and Coords.column_name(702) == "AAA", "columns roll over like a spreadsheet")
	expect(Coords.row_name(0) == "1" and Coords.row_name(31) == "32", "rows are numbered from 1")
	expect(Coords.cell_name(Vector2i(2, 4)) == "C5", "a cell reads as column then row")
	expect(Coords.floor_name(1) == "-1" and Coords.floor_name(3) == "-3", "floors are numbered -1, -2, -3")


func test_true_walls() -> void:
	var grid := FloorGrid.new(3, 3)
	grid.set_cell(Vector2i(1, 1), FloorGrid.Cell.FLOOR)
	grid.set_cell(Vector2i(2, 1), FloorGrid.Cell.FLOOR)
	expect(grid.has_wall(Edges.between(Vector2i(1, 1), Vector2i(1, 0))), "floor next to rock has a wall")
	expect(not grid.has_wall(Edges.between(Vector2i(1, 1), Vector2i(2, 1))), "two floor cells have no wall between")
	expect(not grid.has_wall(Edges.between(Vector2i(0, 0), Vector2i(1, 0))), "two rock cells have no wall between")
	expect(grid.has_wall(Vector3i(2, 1, Edges.VERTICAL)), "floor at the map edge has a wall on the border")


func test_drawing_walls() -> void:
	var map := PlayerMap.new(4, 3)
	var e1 := Edges.between(Vector2i(0, 0), Vector2i(1, 0))
	var e2 := Edges.between(Vector2i(1, 1), Vector2i(1, 2))
	expect(map.set_wall(e1, true), "can draw a wall line")
	expect(map.has_wall(e1) and map.wall_edges().size() == 1, "drawn wall is stored")
	expect(not map.set_wall(e1, true), "drawing the same wall twice changes nothing")
	expect(map.set_wall(e1, false) and not map.has_wall(e1), "can erase a drawn wall")
	map.set_wall(e2, true)
	map.visit(Vector2i(1, 1))
	map.visit(Vector2i(1, 2))
	expect(map.has_wall(e2), "jumping onto cells doesn't touch walls between them")
	map.walk(Vector2i(1, 1), Vector2i(1, 2))
	expect(not map.has_wall(e2), "walking across a drawn wall removes it")
	expect(not map.set_wall(e2, true), "can't draw a wall where you've walked across")
	expect(not map.set_wall(Vector3i(9, 9, Edges.VERTICAL), true), "can't draw out of bounds")


func test_undo() -> void:
	var map := PlayerMap.new(5, 5)
	expect(not map.can_undo(), "nothing to undo at first")
	map.begin_stroke()
	for x in 3:
		map.set_wall(Vector3i(x, 0, Edges.HORIZONTAL), true)
	map.end_stroke()
	var single := Vector3i(0, 2, Edges.VERTICAL)
	map.set_wall(single, true)
	expect(map.undo(), "undo works after a single line")
	expect(not map.has_wall(single), "undo takes back the last line")
	expect(map.has_wall(Vector3i(2, 0, Edges.HORIZONTAL)), "undo leaves the earlier stroke alone")
	expect(map.undo(), "undo works for a stroke")
	var cleared := true
	for x in 3:
		cleared = cleared and not map.has_wall(Vector3i(x, 0, Edges.HORIZONTAL))
	expect(cleared, "undo takes back a whole stroke at once")
	expect(not map.can_undo() and not map.undo(), "history is empty after undoing everything")

	var e := Edges.between(Vector2i(3, 3), Vector2i(4, 3))
	map.set_wall(e, true)
	map.set_wall(e, false)
	map.walk(Vector2i(3, 3), Vector2i(4, 3))
	map.undo()
	expect(not map.has_wall(e), "undo never puts a wall back where you've walked across")

	var kept := Vector3i(0, 0, Edges.VERTICAL)
	map.set_wall(kept, true)
	map.begin_stroke()
	map.set_wall(kept, false)
	map.set_wall(Vector3i(1, 1, Edges.HORIZONTAL), true)
	map.cancel_stroke()
	expect(map.has_wall(kept) and not map.has_wall(Vector3i(1, 1, Edges.HORIZONTAL)), "cancelling a stroke reverts its changes")
	map.undo()
	expect(not map.has_wall(kept), "a cancelled stroke isn't in the undo history")

	var fresh := PlayerMap.new(3, 3)
	fresh.begin_stroke()
	fresh.end_stroke()
	expect(not fresh.can_undo(), "an empty stroke isn't added to history")

func make_hero(hp: int, aggro := 1, speed := 0):
	return Hero.from_dict({"name": "Test", "max_hp": hp, "max_sp": 10, "max_mp": 5, "aggro": aggro, "speed": speed})


func test_hero_bars() -> void:
	var hero = make_hero(40)
	expect(hero.hp == 40 and hero.sp == 10 and hero.mp == 5, "a new hero starts with full bars")
	hero.defense = 20
	expect(hero.take_damage(10) == 8, "DEF 20 cuts a 10 damage hit to 8")
	expect(hero.hp == 32, "damage comes off HP")
	hero.defense = 0
	expect(hero.take_damage(100) == 32 and hero.hp == 0, "damage stops at 0 HP")
	expect(hero.is_down(), "a hero at 0 HP is down")
	expect(hero.heal(10) == 0 and hero.hp == 0, "healing doesn't wake a downed hero")
	hero.defense = 100
	expect(hero.damage_after_defense(50) == 0, "DEF 100 blocks everything")
	hero.defense = 250
	expect(hero.damage_after_defense(50) == 0, "DEF above 100 counts as 100")
	expect(hero.damage_after_defense(-5) == 0, "negative damage does nothing")

	expect(hero.spend_sp(4) and hero.sp == 6, "spending SP takes it off")
	expect(not hero.spend_sp(7) and hero.sp == 6, "can't spend more SP than you have")
	expect(hero.spend_mp(5) and not hero.spend_mp(1), "MP runs out")
	hero.rest()
	expect(hero.hp == 40 and hero.sp == 10 and hero.mp == 5 and not hero.is_down(), "resting fills every bar")
	hero.defense = 0
	hero.take_damage(15)
	expect(hero.heal(100) == 15 and hero.hp == 40, "healing stops at max HP")


func test_hero_xp() -> void:
	var hero = make_hero(10)
	expect(hero.level == 1 and hero.xp == 0, "heroes start at level 1 with no XP")
	expect(hero.gain_xp(99) == 0 and hero.level == 1, "99 XP isn't a level")
	expect(hero.gain_xp(1) == 1 and hero.level == 2 and hero.xp == 0, "100 XP takes level 1 to 2")
	expect(hero.gain_xp(250) == 2 and hero.level == 4 and hero.xp == 50, "every level costs 100 XP; extra XP carries over")
	expect(hero.gain_xp(-10) == 0 and hero.xp == 50, "negative XP does nothing")


func test_targeting() -> void:
	var guard = make_hero(10, 8)
	var mage = make_hero(10, 2)
	var party := [guard, mage]
	expect(is_equal_approx(Hero.target_chance(party, guard), 0.8), "aggro 8 of 10 is an 80% chance")
	expect(is_equal_approx(Hero.target_chance(party, mage), 0.2), "aggro 2 of 10 is a 20% chance")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var guard_hits := 0
	for i in 1000:
		if Hero.pick_target(party, rng) == guard:
			guard_hits += 1
	expect(guard_hits > 740 and guard_hits < 860, "picks follow aggro (guard hit %d of 1000)" % guard_hits)

	guard.take_damage(100)
	expect(Hero.target_chance(party, guard) == 0.0, "a downed hero can't be targeted")
	expect(is_equal_approx(Hero.target_chance(party, mage), 1.0), "the last one standing takes every hit")
	var only_mage := true
	for i in 50:
		only_mage = only_mage and Hero.pick_target(party, rng) == mage
	expect(only_mage, "enemies never pick a downed hero")
	mage.take_damage(100)
	expect(Hero.pick_target(party, rng) == null, "no target when everyone is down")

	var quiet := [make_hero(10, 0), make_hero(10, 0)]
	expect(Hero.pick_target(quiet, rng) != null, "a party with no aggro can still be targeted")


func test_turn_order() -> void:
	var slow = make_hero(10, 1, 2)
	var fast = make_hero(10, 1, 9)
	var mid_a = make_hero(10, 1, 5)
	var mid_b = make_hero(10, 1, 5)
	var fighters := [slow, mid_a, fast, mid_b]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var order := Hero.turn_order(fighters, rng)
	expect(order[0] == fast and order[3] == slow, "fastest acts first, slowest last")
	expect(order.has(mid_a) and order.has(mid_b), "nobody is left out of the turn order")

	var same := true
	for i in 20:
		var a := RandomNumberGenerator.new()
		a.seed = i
		var b := RandomNumberGenerator.new()
		b.seed = i
		same = same and Hero.turn_order(fighters, a) == Hero.turn_order(fighters, b)
	expect(same, "the same seed breaks ties the same way")
	var both_orders := {}
	for i in 40:
		var r := RandomNumberGenerator.new()
		r.seed = i
		both_orders[Hero.turn_order(fighters, r)[1] == mid_a] = true
	expect(both_orders.size() == 2, "ties in speed go either way across seeds")


func test_hero_save() -> void:
	var hero = make_hero(40, 8, 4)
	hero.name = "Mara"
	hero.gender = "female"
	hero.defense = 20
	hero.combat_skills.assign(["shield_wall", "taunt"])
	hero.exploration_skills.assign(["brace_door"])
	hero.take_damage(10)
	hero.gain_xp(130)
	var copy = Hero.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	expect(copy.to_dict() == hero.to_dict(), "a hero comes back the same after saving through JSON")
	expect(copy.hp == 32 and copy.level == 2 and copy.xp == 30, "saving keeps HP, level and XP")
	expect(copy.traits.is_empty() and copy.gear.is_empty(), "traits and gear start empty")

	var odd = Hero.from_dict({"gender": "robot", "hp": 999, "max_hp": 20, "defense": -5, "level": 0})
	expect(odd.gender == "unspecified", "an unknown gender reads as unspecified")
	expect(odd.hp == 20, "HP is never above max")
	expect(odd.defense == 0 and odd.level == 1, "bad values are kept in range")
	var backwards = Hero.from_dict({"attack_min": 6, "attack_max": 2})
	expect(backwards.attack_max >= backwards.attack_min, "attack max is never below min")


func test_classes() -> void:
	var classes := Hero.load_classes()
	expect(classes.has("warrior"), "the warrior class loads from data/classes")
	if not classes.has("warrior"):
		return
	var warrior = Hero.from_class(classes["warrior"], "Bram", "male")
	expect(warrior.name == "Bram" and warrior.gender == "male" and warrior.class_id == "warrior", "a class hero keeps its name, gender and class")
	expect(warrior.max_hp == 20 and warrior.hp == 20, "a warrior starts with 20 HP")
	expect(warrior.max_sp == 10 and warrior.sp == 10 and warrior.max_mp == 0, "a warrior starts with 10 SP and no MP")
	expect(warrior.speed == 5 and warrior.aggro == 10 and warrior.defense == 5, "a warrior has speed 5, aggro 10 and DEF 5")
	expect(warrior.level == 1 and warrior.xp == 0, "a class hero starts at level 1")

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen := {}
	for i in 300:
		seen[warrior.roll_attack(rng)] = true
	expect(seen.keys().all(func(d): return d >= 4 and d <= 6), "a warrior's attack does 4 to 6")
	expect(seen.size() == 3, "a warrior's attack can roll 4, 5 and 6")

	var before: Dictionary = warrior.to_dict()
	warrior.gain_xp(100)
	var after: Dictionary = warrior.to_dict()
	before.erase("level")
	before.erase("xp")
	after.erase("level")
	after.erase("xp")
	expect(warrior.level == 2 and before == after, "levelling up changes nothing else yet")

	var names := Hero.load_names()
	expect(Hero.GENDERS.all(func(g): return names.get(g, []).size() > 0), "the names file has names for every gender")
	var genders := {}
	var named_right := true
	for i in 60:
		var hero = Hero.random_from_class(classes["warrior"], names, rng)
		genders[hero.gender] = true
		named_right = named_right and hero.name in names[hero.gender] and hero.class_id == "warrior" and hero.hp == 20
	expect(named_right, "a random warrior gets a name for its gender and the warrior's numbers")
	expect(genders.size() == 3, "random heroes can be any gender")
	expect(Hero.random_from_class(classes["warrior"], {}, rng).name != "", "a hero still gets a name without a names file")


func test_monsters() -> void:
	var rat_type := {
		"id": "rat", "name": "Rat",
		"start": {"max_hp": 8, "max_sp": 4, "max_mp": 0, "defense": 10, "speed": 7, "aggro": 3,
			"attack_min": 1, "attack_max": 3, "level": 2},
		"combat_skills": ["bite"],
		"rewards": {"xp": 3, "loot": ["rat_tail"]},
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var rat = Monster.from_type(rat_type, rng)
	expect(rat.name == "Rat" and rat.type_id == "rat", "a monster takes its type's name and id")
	expect(rat.hp == 8 and rat.sp == 4 and rat.mp == 0, "a monster starts with full bars")
	expect(rat.defense == 10 and rat.speed == 7 and rat.aggro == 3 and rat.level == 2, "a monster takes its type's numbers")
	expect(rat.combat_skills == ["bite"], "a monster takes its type's skills")
	expect(rat.rewards() == {"xp": 3, "loot": ["rat_tail"]}, "a monster gives its type's XP and loot")
	expect(Monster.from_type(rat_type, rng, "Big Rat").name == "Big Rat", "a monster can be given its own name")
	expect(rat.damage_after_defense(10) == 9, "monsters take damage through DEF like heroes")
	expect(rat.take_damage(10) == 8 and rat.hp == 0 and rat.is_down(), "a monster at 0 HP is down")

	var copy = Monster.from_dict(JSON.parse_string(JSON.stringify(rat.to_dict())))
	expect(copy.to_dict() == rat.to_dict(), "a monster comes back the same after saving through JSON")

	# Heroes pick monsters by aggro too, and both sides share one turn order.
	var a = Monster.from_type(rat_type, rng)
	var b = Monster.from_type(rat_type, rng)
	b.aggro = 9
	expect(is_equal_approx(Monster.target_chance([a, b], b), 0.75), "heroes target monsters by aggro")
	var classes := Hero.load_classes()
	var warrior = Hero.from_class(classes["warrior"], "Bram")
	var order := Fighter.turn_order([warrior, a, b], rng)
	expect(order.size() == 3 and order[2] == warrior, "a speed 5 warrior acts after speed 7 rats")

func test_skeleton() -> void:
	var types := Monster.load_types()
	expect(types.has("skeleton"), "the skeleton loads from data/monsters")
	if not types.has("skeleton"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var hp_seen := {}
	var all_right := true
	for i in 300:
		var skeleton = Monster.from_type(types["skeleton"], rng)
		hp_seen[skeleton.max_hp] = true
		all_right = all_right and skeleton.hp == skeleton.max_hp and skeleton.level == 1 			and skeleton.name == "Skeleton" and skeleton.combat_skills.is_empty() 			and skeleton.rewards() == {"xp": 5, "loot": []}
	expect(all_right, "a skeleton is level 1, has no skills, starts at full HP and gives 5 XP")
	expect(hp_seen.keys().all(func(v): return v >= 5 and v <= 10), "a skeleton has 5 to 10 HP")
	expect(hp_seen.size() == 6, "skeleton HP can be any of 5 to 10")
	var skeleton = Monster.from_type(types["skeleton"], rng)
	var damage := {}
	for i in 300:
		damage[skeleton.roll_attack(rng)] = true
	expect(damage.keys().all(func(d): return d >= 1 and d <= 3) and damage.size() == 3, "a skeleton's attack does 1 to 3")
	var picture: String = types["skeleton"].get("picture", "")
	expect(ResourceLoader.exists(picture), "the skeleton's picture exists")

	var a := RandomNumberGenerator.new()
	a.seed = 21
	var b := RandomNumberGenerator.new()
	b.seed = 21
	expect(Monster.from_type(types["skeleton"], a).max_hp == Monster.from_type(types["skeleton"], b).max_hp, "the same seed rolls the same skeleton")

	var warrior = Hero.from_class(Hero.load_classes()["warrior"], "Bram")
	expect(warrior.gain_xp(skeleton.rewards()["xp"]) == 0 and warrior.xp == 5, "beating a skeleton gives a hero 5 XP")


func test_encounters() -> void:
	var settings := Encounters.load_settings()
	# The odds are tuned in data/generation/encounters.json; these checks
	# follow whatever it says.
	var chance: float = settings["chance"]
	expect(chance > 0.0 and chance <= 1.0 and settings["monster"] == "skeleton", "walking can meet a skeleton")
	expect(Monster.load_types().has(settings["monster"]), "the encounter monster is a real monster type")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var met := 0
	var only_skeletons := true
	for i in 5000:
		var found := Encounters.roll(settings, rng)
		if found != "":
			met += 1
			only_skeletons = only_skeletons and found == "skeleton"
	expect(absf(met / 5000.0 - chance) < 0.02, "about %d%% of steps meet a monster (%d of 5000)" % [roundi(chance * 100), met])
	expect(only_skeletons, "every encounter is a skeleton")
	expect(Encounters.roll({"chance": 0.0, "monster": "skeleton"}, rng) == "", "chance 0 never meets anything")
	expect(Encounters.roll({"chance": 1.0, "monster": "skeleton"}, rng) == "skeleton", "chance 1 always meets the monster")

	var a := RandomNumberGenerator.new()
	a.seed = Encounters.floor_seed(77)
	var b := RandomNumberGenerator.new()
	b.seed = Encounters.floor_seed(77)
	var same := true
	for i in 200:
		same = same and Encounters.roll(settings, a) == Encounters.roll(settings, b)
	expect(same, "the same floor gives the same encounters")
	expect(Encounters.floor_seed(77) != 77, "encounter rolls don't share the floor's layout seed")

	var sizes := {1: 0, 2: 0, 3: 0}
	var other_size := false
	for i in 10000:
		var n := Encounters.roll_group_size(settings, rng)
		if sizes.has(n):
			sizes[n] += 1
		else:
			other_size = true
	expect(not other_size, "a skeleton group is 1, 2 or 3")
	var group_chances: Dictionary = settings["group_chances"]
	var odds := {2: float(group_chances.get("2", 0.0)), 3: float(group_chances.get("3", 0.0))}
	odds[1] = 1.0 - odds[2] - odds[3]
	for n in [1, 2, 3]:
		expect(absf(sizes[n] / 10000.0 - odds[n]) < 0.02, "a group of %d comes about %d%% of the time (%d of 10000)" % [n, roundi(odds[n] * 100), sizes[n]])
	expect(Encounters.roll_group_size({}, rng) == 1 and Encounters.roll_group_size({"group_chances": {"2": 1.0}}, rng) == 2, "no group chances means alone; chance 1 always gives the group")
	var skeleton: Dictionary = Monster.load_types()["skeleton"]
	var three := Encounters.spawn_group(skeleton, 3, rng)
	expect(three.map(func(m): return m.name) == ["Skeleton A", "Skeleton B", "Skeleton C"], "a group's monsters are lettered A, B, C")
	expect(Encounters.spawn_group(skeleton, 1, rng)[0].name == "Skeleton", "a lone monster keeps its plain name")
	var party := [Hero.from_class(Hero.load_classes()["warrior"], "Bram")]
	var battle = Battle.fight(party, three, rng)
	var hit := {}
	for round in battle.rounds:
		for move in round:
			if three.has(move["target"]):
				hit[move["target"]] = true
	expect(battle.outcome != Battle.Outcome.DRAW and (battle.outcome == Battle.Outcome.MONSTERS_WIN or three.all(func(m): return m.is_down())), "a fight against three ends with all of one side down")
	expect(battle.outcome != Battle.Outcome.HEROES_WIN or battle.rewards()["xp"] == 15, "beating three skeletons gives 15 XP")


func test_battles() -> void:
	var warrior_class: Dictionary = Hero.load_classes()["warrior"]
	var skeleton_type: Dictionary = Monster.load_types()["skeleton"]
	var wins := 0
	var moves_ok := true
	var order_ok := true
	var hp_ok := true
	for seed_value in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var warrior = Hero.from_class(warrior_class, "Bram")
		var skeleton = Monster.from_type(skeleton_type, rng)
		var battle = Battle.fight([warrior], [skeleton], rng)
		if battle.outcome == Battle.Outcome.HEROES_WIN:
			wins += 1
		hp_ok = hp_ok and (skeleton.is_down() or warrior.is_down())
		for moves in battle.rounds:
			for i in moves.size():
				var move: Dictionary = moves[i]
				moves_ok = moves_ok and move["actor"] != move["target"] and move["damage"] >= 0 					and move["target_hp"] >= 0 and move["downed"] == (move["target_hp"] == 0)
				# The warrior (speed 5) always acts before the skeleton (speed 3).
				if moves.size() == 2:
					order_ok = order_ok and moves[0]["actor"] == warrior
	expect(hp_ok, "a fight ends with one side down")
	expect(moves_ok, "every move hits someone on the other side and records the HP left")
	expect(order_ok, "the faster fighter moves first each round")
	expect(wins == 200, "a full-HP warrior always beats one skeleton (won %d of 200)" % wins)

	# A won fight gives the skeleton's XP to the warrior.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var warrior = Hero.from_class(warrior_class, "Bram")
	var battle = Battle.fight([warrior], [Monster.from_type(skeleton_type, rng)], rng)
	expect(battle.rewards() == {"xp": 5, "loot": []}, "beating a skeleton is worth 5 XP")
	battle.award_xp()
	expect(warrior.xp == 5, "the warrior gets the XP after winning")
	var last_moves: Array = battle.rounds[-1]
	expect(last_moves[-1]["downed"], "the last move of a won fight downs the last monster")

	# A hero at 1 HP against three skeletons loses, and gets nothing.
	var weak = Hero.from_class(warrior_class, "Bram")
	weak.hp = 1
	var foes := [Monster.from_type(skeleton_type, rng), Monster.from_type(skeleton_type, rng), Monster.from_type(skeleton_type, rng)]
	var lost = Battle.fight([weak], foes, rng)
	expect(lost.outcome == Battle.Outcome.MONSTERS_WIN and weak.is_down(), "a beaten party loses the fight")
	expect(lost.rewards()["xp"] == 0 and lost.award_xp().is_empty(), "a lost fight gives no XP")

	# Same seed, same fight.
	var a := RandomNumberGenerator.new()
	a.seed = 33
	var b := RandomNumberGenerator.new()
	b.seed = 33
	var fight_a = Battle.fight([Hero.from_class(warrior_class, "A")], [Monster.from_type(skeleton_type, a)], a)
	var fight_b = Battle.fight([Hero.from_class(warrior_class, "A")], [Monster.from_type(skeleton_type, b)], b)
	var damage_a := []
	var damage_b := []
	for moves in fight_a.rounds:
		damage_a.append(moves.map(func(m): return m["damage"]))
	for moves in fight_b.rounds:
		damage_b.append(moves.map(func(m): return m["damage"]))
	expect(damage_a == damage_b, "the same seed replays the same fight")

	# Nobody can do damage: the fight stops as a draw.
	var pacifist = Hero.from_dict({"max_hp": 5, "attack_min": 0, "attack_max": 0})
	var wall = Monster.from_dict({"max_hp": 5, "attack_min": 0, "attack_max": 0})
	var stuck = Battle.fight([pacifist], [wall], rng)
	expect(stuck.outcome == Battle.Outcome.DRAW and stuck.rounds.size() == Battle.MAX_ROUNDS, "a fight nobody can win stops as a draw")


func expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func test_guild() -> void:
	var guild = Guild.new()
	expect(guild.heroes.is_empty() and guild.delve_party().is_empty(), "a new guild has no heroes")
	var warrior_data: Dictionary = Hero.load_classes().get("warrior", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bram = guild.recruit(warrior_data, Hero.load_names(), rng)
	expect(guild.heroes == [bram], "a recruit joins the roster")
	expect(guild.party.is_empty() and guild.reserves() == [bram], "a recruit isn't in the party until picked")
	expect(bram.class_id == "warrior" and bram.level == 1 and bram.xp == 0, "a recruit is a level 1 hero of the class picked")
	expect(bram.hp == bram.max_hp and bram.max_hp == 20, "a recruit starts with full HP from the class")
	var second = guild.recruit(warrior_data, Hero.load_names(), rng)
	expect(guild.add_to_party(second) and guild.add_to_party(bram), "guild heroes can join the party")
	expect(not guild.add_to_party(bram), "a hero can't join the party twice")
	expect(not guild.add_to_party(Hero.new()), "only guild heroes can join the party")
	expect(guild.party == [second, bram] and guild.reserves().is_empty(), "the party keeps the order heroes joined")
	expect(guild.delve_party() == [second, bram], "every standing party hero goes on a delve")
	second.take_damage(999)
	expect(guild.delve_party() == [bram], "a downed hero stays behind")
	var copy = Guild.from_dict(guild.to_dict())
	expect(copy.heroes.size() == 2 and copy.heroes[0].name == bram.name and copy.heroes[1].is_down(), "the roster saves and loads")
	expect(copy.party == [copy.heroes[1], copy.heroes[0]], "the party saves and loads in order")
	expect(guild.remove_from_party(second) and guild.party == [bram] and guild.reserves() == [second], "a hero can leave the party and stays in the guild")
	expect(not guild.remove_from_party(second), "a hero not in the party can't leave it")
	var full = Guild.new()
	for i in 7:
		full.recruit(warrior_data, Hero.load_names(), rng)
	for hero in full.heroes:
		full.add_to_party(hero)
	expect(full.party.size() == Guild.MAX_PARTY and Guild.MAX_PARTY == 5 and full.party_full(), "the party holds at most 5 heroes")
	expect(not full.add_to_party(full.heroes[6]) and full.reserves().size() == 2, "a full party takes no one else")
	full.remove_from_party(full.party[0])
	expect(not full.party_full() and full.add_to_party(full.heroes[6]), "a hero can join once there's room")


func test_save_game() -> void:
	var guild = Guild.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var warrior_data: Dictionary = Hero.load_classes().get("warrior", {})
	for i in 3:
		guild.recruit(warrior_data, Hero.load_names(), rng)
	guild.add_to_party(guild.heroes[2])
	guild.add_to_party(guild.heroes[0])
	guild.heroes[0].take_damage(6)
	guild.heroes[0].gain_xp(130)
	var path := "user://test_save.json"
	expect(SaveGame.write(guild, path), "the save writes")
	var loaded = SaveGame.read(path)
	expect(loaded != null and loaded.heroes.size() == 3, "the save loads every hero")
	if loaded != null:
		var a = guild.heroes[0]
		var b = loaded.heroes[0]
		expect(b.name == a.name and b.hp == a.hp and b.level == a.level and b.xp == a.xp and b.class_id == a.class_id and b.gender == a.gender, "a loaded hero keeps name, HP, level, XP, class and gender")
		expect(loaded.party == [loaded.heroes[2], loaded.heroes[0]], "the loaded party has the same heroes in order")
	guild.heroes[1].gain_xp(40)
	expect(SaveGame.write(guild, path), "saving again over an old save works")
	var again = SaveGame.read(path)
	expect(again != null and again.heroes[1].xp == guild.heroes[1].xp, "the newer save replaces the old one")
	expect(not FileAccess.file_exists(path + ".tmp"), "no temporary file is left behind")

	# A broken save is kept aside before anything can overwrite it.
	var broken_file := FileAccess.open(path, FileAccess.WRITE)
	broken_file.store_string("{\"guild\": ")
	broken_file.close()
	var broken_copy := SaveGame.broken_path(path)
	expect(broken_copy == "user://test_save.broken.json", "a broken save is kept next to it as .broken.json")
	expect(SaveGame.read(path) == null, "a broken save file loads nothing")
	expect(FileAccess.file_exists(broken_copy) and FileAccess.get_file_as_string(broken_copy) == "{\"guild\": ", "the broken save is copied aside unchanged")
	DirAccess.remove_absolute(broken_copy)

	DirAccess.remove_absolute(path)
	expect(SaveGame.read(path) == null, "no save file loads nothing")
	expect(SaveGame.guild_from_text("not json") == null and SaveGame.guild_from_text("[1]") == null and SaveGame.guild_from_text("{}") == null, "a broken save loads nothing")


func test_party_falls() -> void:
	var guild = Guild.new()
	expect(not guild.can_delve(), "an empty party can't delve")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var warrior_data: Dictionary = Hero.load_classes().get("warrior", {})
	for i in 2:
		guild.add_to_party(guild.recruit(warrior_data, Hero.load_names(), rng))
	expect(guild.can_delve(), "a party with a standing hero can delve")
	for hero in guild.party:
		hero.take_damage(999)
	expect(not guild.can_delve(), "a party that's all down can't delve")
	expect(guild.party[0].revive(0) and guild.party[0].hp == 1, "revive gives at least 1 HP")
	guild.party[0].take_damage(999)
	Guild.carry_back(guild.party)
	expect(guild.party.all(func(h): return h.hp == 1), "a fallen party comes back with 1 HP each")
	expect(not guild.party[0].revive(5) and guild.party[0].hp == 1, "revive does nothing to a standing hero")
	expect(guild.can_delve(), "after being carried back the party can delve again")
