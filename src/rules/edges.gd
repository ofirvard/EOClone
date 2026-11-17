extends RefCounted
## Cell edges: the lines between grid cells, where map walls are drawn.
##
## An edge is a Vector3i(x, y, axis):
##   axis 0 (VERTICAL):   the line on the east side of cell (x, y),
##                        between (x, y) and (x + 1, y).
##   axis 1 (HORIZONTAL): the line on the south side of cell (x, y),
##                        between (x, y) and (x, y + 1).
## Outer border lines use x = -1 or y = -1 for the west and north sides.

const VERTICAL := 0
const HORIZONTAL := 1
const NONE := Vector3i(0, 0, -1)


## The edge between two neighbouring cells (NONE if they aren't neighbours).
static func between(a: Vector2i, b: Vector2i) -> Vector3i:
	match b - a:
		Vector2i.RIGHT:
			return Vector3i(a.x, a.y, VERTICAL)
		Vector2i.LEFT:
			return Vector3i(b.x, b.y, VERTICAL)
		Vector2i.DOWN:
			return Vector3i(a.x, a.y, HORIZONTAL)
		Vector2i.UP:
			return Vector3i(b.x, b.y, HORIZONTAL)
	return NONE


## The two cells on either side of an edge.
static func cells(edge: Vector3i) -> Array[Vector2i]:
	var a := Vector2i(edge.x, edge.y)
	var b := a + (Vector2i.RIGHT if edge.z == VERTICAL else Vector2i.DOWN)
	return [a, b]


static func in_bounds(edge: Vector3i, width: int, height: int) -> bool:
	if edge.z == VERTICAL:
		return edge.x >= -1 and edge.x < width and edge.y >= 0 and edge.y < height
	if edge.z == HORIZONTAL:
		return edge.x >= 0 and edge.x < width and edge.y >= -1 and edge.y < height
	return false


## Start and end of the edge's line, in grid units (cell corners).
static func segment(edge: Vector3i) -> PackedVector2Array:
	if edge.z == VERTICAL:
		return PackedVector2Array([Vector2(edge.x + 1, edge.y), Vector2(edge.x + 1, edge.y + 1)])
	return PackedVector2Array([Vector2(edge.x, edge.y + 1), Vector2(edge.x + 1, edge.y + 1)])


## Dots are the grid corners where lines meet: dot (x, y) is the top-left
## corner of cell (x, y). Walls are drawn by connecting two dots.
const NO_DOT := Vector2i(-1, -1)


## The dot within `reach` of point `g` (in grid units), or NO_DOT.
static func dot_near(g: Vector2, reach: float = 0.3) -> Vector2i:
	var dot := Vector2i(roundi(g.x), roundi(g.y))
	return dot if g.distance_to(Vector2(dot)) <= reach else NO_DOT


## Every edge whose line passes within `reach` of point `g` (in grid units).
## Used by the eraser, which rubs out whatever the pointer passes over.
const ERASER_REACH := 0.25


static func near(g: Vector2, reach: float = ERASER_REACH) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var base := Vector2i(floori(g.x), floori(g.y))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := base + Vector2i(dx, dy)
			for axis in [VERTICAL, HORIZONTAL]:
				var edge := Vector3i(c.x, c.y, axis)
				var seg := segment(edge)
				var closest := Geometry2D.get_closest_point_to_segment(g, seg[0], seg[1])
				if g.distance_to(closest) <= reach:
					result.append(edge)
	return result


## The edges along the straight line from dot `a` to dot `b`. Empty if the
## dots are the same or not in the same row or column.
static func between_dots(a: Vector2i, b: Vector2i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if a.y == b.y:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x)):
			result.append(Vector3i(x, a.y - 1, HORIZONTAL))
	elif a.x == b.x:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y)):
			result.append(Vector3i(a.x - 1, y, VERTICAL))
	return result
