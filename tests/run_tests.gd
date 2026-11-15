extends SceneTree
## Headless rule checks. Run from the project root:
##   godot --headless --script res://tests/run_tests.gd

const FloorGenerator = preload("res://src/rules/floor_generator.gd")
const FloorGrid = preload("res://src/rules/floor_grid.gd")
const PlayerMap = preload("res://src/rules/player_map.gd")
const Edges = preload("res://src/rules/edges.gd")

const SEEDS := 300

var _failures := 0
var _checks := 0


func _init() -> void:
	var settings := FloorGenerator.load_settings("res://data/generation/floor.json")
	test_same_seed_same_floor(settings)
	test_different_seeds_differ(settings)
	for seed_value in SEEDS:
		check_floor(FloorGenerator.generate(seed_value, settings))
	test_edges()
	test_true_walls()
	test_footsteps()
	test_drawing_walls()
	test_undo()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func test_same_seed_same_floor(settings: Dictionary) -> void:
	for seed_value in [0, 1, 42, 123456789, -7]:
		var a := FloorGenerator.generate(seed_value, settings)
		var b := FloorGenerator.generate(seed_value, settings)
		expect(a.cells == b.cells, "seed %d gives the same floor twice" % seed_value)


func test_different_seeds_differ(settings: Dictionary) -> void:
	var a := FloorGenerator.generate(1, settings)
	var b := FloorGenerator.generate(2, settings)
	expect(a.cells != b.cells, "seeds 1 and 2 give different floors")


func check_floor(grid: FloorGrid) -> void:
	var tag := "seed %d" % grid.seed_value
	expect(grid.rooms.size() >= 2, "%s has at least 2 rooms" % tag)

	var border_ok := true
	for x in grid.width:
		border_ok = border_ok and grid.get_cell(Vector2i(x, 0)) == FloorGrid.Cell.WALL
		border_ok = border_ok and grid.get_cell(Vector2i(x, grid.height - 1)) == FloorGrid.Cell.WALL
	for y in grid.height:
		border_ok = border_ok and grid.get_cell(Vector2i(0, y)) == FloorGrid.Cell.WALL
		border_ok = border_ok and grid.get_cell(Vector2i(grid.width - 1, y)) == FloorGrid.Cell.WALL
	expect(border_ok, "%s has a solid outer wall" % tag)

	var ups := 0
	var downs := 0
	for v in grid.cells:
		ups += int(v == FloorGrid.Cell.STAIRS_UP)
		downs += int(v == FloorGrid.Cell.STAIRS_DOWN)
	expect(ups == 1 and downs == 1, "%s has one stairs up and one down" % tag)
	expect(grid.stairs_up != grid.stairs_down, "%s stairs are in different cells" % tag)

	var reach := grid.distances_from(grid.stairs_up)
	expect(reach.size() == grid.walkable_cells().size(), "%s every open cell is reachable" % tag)


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
	var seg := Edges.segment(e)
	expect(seg[0] == Vector2(3, 3) and seg[1] == Vector2(3, 4), "a line's ends are its two dots")


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


func expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)
