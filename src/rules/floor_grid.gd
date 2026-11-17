extends RefCounted
## One dungeon floor as a grid of cells. Pure data: no nodes, no drawing,
## so it can be tested headless and shared by the 3D view and the map screen.

## STAIRS_UP is solid (a stairway set into a wall); STAIRS_DOWN is a trapdoor
## in the floor you can walk over.
enum Cell { WALL, FLOOR, STAIRS_UP, STAIRS_DOWN }

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var width: int
var height: int
var cells: PackedByteArray
var seed_value: int = 0
var rooms: Array[Rect2i] = []
var start := Vector2i(-1, -1)   ## Where the party enters the floor.
var start_facing := 0           ## Index into DIRECTIONS the party faces at the start.
var stairs_up := Vector2i(-1, -1)
var stairs_up_side := 0         ## DIRECTIONS index from stairs_up toward the open cell it faces.
var stairs_down := Vector2i(-1, -1)


func _init(w: int, h: int) -> void:
	width = w
	height = h
	cells = PackedByteArray()
	cells.resize(w * h)
	cells.fill(Cell.WALL)


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func get_cell(p: Vector2i) -> int:
	return cells[p.y * width + p.x]


func set_cell(p: Vector2i, value: int) -> void:
	cells[p.y * width + p.x] = value


func is_walkable(p: Vector2i) -> bool:
	if not in_bounds(p):
		return false
	var cell := get_cell(p)
	return cell == Cell.FLOOR or cell == Cell.STAIRS_DOWN


func walkable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if is_walkable(p):
				result.append(p)
	return result


## True if a map wall belongs on this edge: one side is open, the other is
## solid rock (or outside the floor).
func has_wall(edge: Vector3i) -> bool:
	if edge.z < 0:
		return false
	var a := Vector2i(edge.x, edge.y)
	var b := a + (Vector2i.RIGHT if edge.z == 0 else Vector2i.DOWN)
	return is_walkable(a) != is_walkable(b)


## Breadth-first walk from `start`. Returns {cell: steps} for every reachable cell.
func distances_from(start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	if not is_walkable(start):
		return {}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		for dir in DIRECTIONS:
			var next := current + dir
			if is_walkable(next) and not dist.has(next):
				dist[next] = dist[current] + 1
				queue.append(next)
	return dist
