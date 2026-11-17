extends RefCounted
## Builds a floor from a seed: rooms joined by corridors. The party starts in
## a random room, in front of the stairs up set into its wall; a trapdoor down
## sits in another random room.
## The same seed and settings always give the same floor.
##
## This is the first pass. Later passes will swap plain rectangles for
## hand-made room templates and set pieces (see docs/design.md).

const FloorGrid = preload("res://src/rules/floor_grid.gd")

## Largest floor side: columns are lettered A to Z on the map.
const MAX_SIZE := 26

const DEFAULT_SETTINGS := {
	"width": 26,
	"height": 26,
	"room_attempts": 60,
	"max_rooms": 10,
	"room_min_size": 3,
	"room_max_size": 7,
	"extra_connections": 2,
}


## Reads generation settings from a JSON file, falling back to the defaults
## for any missing key (or the whole file, if it can't be read).
static func load_settings(path: String) -> Dictionary:
	var settings := DEFAULT_SETTINGS.duplicate()
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for key in parsed:
				settings[key] = parsed[key]
		else:
			push_warning("Could not parse %s, using default floor settings" % path)
	return settings


static func generate(seed_value: int, settings: Dictionary = DEFAULT_SETTINGS) -> FloorGrid:
	var width: int = mini(int(settings["width"]), MAX_SIZE)
	var height: int = mini(int(settings["height"]), MAX_SIZE)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var grid := FloorGrid.new(width, height)
	grid.seed_value = seed_value

	_place_rooms(grid, rng, settings)
	_connect_rooms(grid, rng, int(settings["extra_connections"]))
	_place_stairs(grid, rng)
	return grid


static func _place_rooms(grid: FloorGrid, rng: RandomNumberGenerator, settings: Dictionary) -> void:
	var min_size: int = int(settings["room_min_size"])
	var max_size: int = int(settings["room_max_size"])
	var max_rooms: int = int(settings["max_rooms"])

	for attempt in int(settings["room_attempts"]):
		if grid.rooms.size() >= max_rooms:
			break
		var w := rng.randi_range(min_size, max_size)
		var h := rng.randi_range(min_size, max_size)
		# Keep a solid wall border around the whole floor.
		if w > grid.width - 2 or h > grid.height - 2:
			continue
		var room := Rect2i(
			rng.randi_range(1, grid.width - w - 1),
			rng.randi_range(1, grid.height - h - 1),
			w, h)
		# At least one wall cell between rooms.
		var padded := room.grow(1)
		var overlaps := false
		for other in grid.rooms:
			if padded.intersects(other):
				overlaps = true
				break
		if overlaps:
			continue
		grid.rooms.append(room)
		_carve_rect(grid, room)


## Joins every room to the nearest room already joined (a spanning tree, so
## everything is reachable), then adds a few extra links to make loops.
static func _connect_rooms(grid: FloorGrid, rng: RandomNumberGenerator, extra: int) -> void:
	var rooms := grid.rooms
	for i in range(1, rooms.size()):
		var best := 0
		var best_dist := INF
		for j in i:
			var d := Vector2(_center(rooms[i]) - _center(rooms[j])).length_squared()
			if d < best_dist:
				best_dist = d
				best = j
		_carve_corridor(grid, rng, _center(rooms[i]), _center(rooms[best]))

	if rooms.size() < 3:
		return
	for n in extra:
		var a := rng.randi_range(0, rooms.size() - 1)
		var b := rng.randi_range(0, rooms.size() - 1)
		if a != b:
			_carve_corridor(grid, rng, _center(rooms[a]), _center(rooms[b]))


## L-shaped corridor; randomly goes horizontal-first or vertical-first.
static func _carve_corridor(grid: FloorGrid, rng: RandomNumberGenerator, from: Vector2i, to: Vector2i) -> void:
	var corner := Vector2i(to.x, from.y) if rng.randi() % 2 == 0 else Vector2i(from.x, to.y)
	_carve_line(grid, from, corner)
	_carve_line(grid, corner, to)


static func _carve_line(grid: FloorGrid, from: Vector2i, to: Vector2i) -> void:
	var step := (to - from).sign()
	var p := from
	while true:
		if grid.get_cell(p) == FloorGrid.Cell.WALL:
			grid.set_cell(p, FloorGrid.Cell.FLOOR)
		if p == to:
			break
		p += step


static func _carve_rect(grid: FloorGrid, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			grid.set_cell(Vector2i(x, y), FloorGrid.Cell.FLOOR)


## Stairs up go in a wall cell beside a random room, and the party starts on
## the floor in front of them, facing into the room. The trapdoor down goes in
## the middle of a different room.
static func _place_stairs(grid: FloorGrid, rng: RandomNumberGenerator) -> void:
	if grid.rooms.is_empty():
		return
	var start_room := rng.randi_range(0, grid.rooms.size() - 1)
	var room := grid.rooms[start_room]

	# Every (room edge cell, solid neighbour outside the room) pair.
	var spots: Array[Vector3i] = []   # x, y = room cell; z = direction to the wall
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var p := Vector2i(x, y)
			for dir in 4:
				var q := p + FloorGrid.DIRECTIONS[dir]
				if not room.has_point(q) and grid.in_bounds(q) and grid.get_cell(q) == FloorGrid.Cell.WALL:
					spots.append(Vector3i(x, y, dir))
	if spots.is_empty():
		grid.start = _center(room)
	else:
		var spot := spots[rng.randi_range(0, spots.size() - 1)]
		grid.start = Vector2i(spot.x, spot.y)
		grid.stairs_up = grid.start + FloorGrid.DIRECTIONS[spot.z]
		grid.stairs_up_side = (spot.z + 2) % 4
		grid.start_facing = grid.stairs_up_side
		grid.set_cell(grid.stairs_up, FloorGrid.Cell.STAIRS_UP)

	if grid.rooms.size() < 2:
		return
	var down_room := rng.randi_range(0, grid.rooms.size() - 2)
	if down_room >= start_room:
		down_room += 1
	grid.stairs_down = _center(grid.rooms[down_room])
	grid.set_cell(grid.stairs_down, FloorGrid.Cell.STAIRS_DOWN)


static func _center(rect: Rect2i) -> Vector2i:
	return rect.position + rect.size / 2
