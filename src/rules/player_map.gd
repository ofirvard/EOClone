extends RefCounted
## The player's own map of one floor: footsteps that fill in automatically,
## plus walls the player draws by hand as lines on cell edges. It never
## reads the real layout. That comparison happens when the map is turned in.
##
## Edits are grouped into strokes (one press-drag-release) so undo takes
## back a whole stroke at once.

const Edges = preload("res://src/rules/edges.gd")

var width: int
var height: int
var visited_count := 0

var _visited: PackedByteArray
var _walls := {}               ## Drawn wall edges: {Vector3i: true}.
var _walked_edges := {}        ## Edges the party has walked across.
var _history: Array = []       ## Finished strokes, each an Array of [edge, had_wall].
var _stroke: Array = []        ## Changes in the stroke being drawn.
var _in_stroke := false


func _init(w: int, h: int) -> void:
	width = w
	height = h
	_visited = PackedByteArray()
	_visited.resize(w * h)


# --- Footsteps ---------------------------------------------------------------

## Marks `p` as stepped on (arriving without crossing an edge, e.g. a jump).
## Returns true the first time.
func visit(p: Vector2i) -> bool:
	if not in_bounds(p) or is_visited(p):
		return false
	_visited[p.y * width + p.x] = 1
	visited_count += 1
	return true


## Steps from one cell to its neighbour. Walking across an edge proves there's
## no wall there, so a wall drawn on it is removed and can't be drawn again.
func walk(from: Vector2i, to: Vector2i) -> bool:
	var edge := Edges.between(from, to)
	if edge != Edges.NONE:
		_walked_edges[edge] = true
		_walls.erase(edge)
	return visit(to)


func is_visited(p: Vector2i) -> bool:
	return in_bounds(p) and _visited[p.y * width + p.x] == 1


# --- Drawn walls -------------------------------------------------------------

func has_wall(edge: Vector3i) -> bool:
	return _walls.has(edge)


func wall_edges() -> Array:
	return _walls.keys()


## Walls can go on any edge inside the map except ones you've walked across.
func can_draw(edge: Vector3i) -> bool:
	return Edges.in_bounds(edge, width, height) and not _walked_edges.has(edge)


## Draws (`on`) or erases a wall, recording it in the current stroke (or as a
## one-off stroke if none is open). Returns true if anything changed.
func set_wall(edge: Vector3i, on: bool) -> bool:
	if not can_draw(edge) or has_wall(edge) == on:
		return false
	var single := not _in_stroke
	if single:
		begin_stroke()
	_stroke.append([edge, has_wall(edge)])
	_apply(edge, on)
	if single:
		end_stroke()
	return true


func begin_stroke() -> void:
	if _in_stroke:
		end_stroke()
	_in_stroke = true
	_stroke = []


func end_stroke() -> void:
	if _in_stroke and not _stroke.is_empty():
		_history.append(_stroke)
	_in_stroke = false
	_stroke = []


## Drops the stroke being drawn, reverting its changes, without adding it to
## the undo history (e.g. when a second finger turns a draw into a pinch).
func cancel_stroke() -> void:
	for i in range(_stroke.size() - 1, -1, -1):
		_apply(_stroke[i][0], _stroke[i][1])
	_in_stroke = false
	_stroke = []


func can_undo() -> bool:
	return not _history.is_empty()


## Reverts the last stroke. Returns true if there was one.
func undo() -> bool:
	end_stroke()
	if _history.is_empty():
		return false
	var stroke: Array = _history.pop_back()
	for i in range(stroke.size() - 1, -1, -1):
		var edge: Vector3i = stroke[i][0]
		if can_draw(edge):
			_apply(edge, stroke[i][1])
	return true


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func _apply(edge: Vector3i, on: bool) -> void:
	if on:
		_walls[edge] = true
	else:
		_walls.erase(edge)
