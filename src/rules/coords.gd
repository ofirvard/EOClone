extends RefCounted
## Map coordinates as players read them: columns are letters (A, B, ... Z,
## AA, AB, ...) and rows are numbers starting at 1, so cell (0, 0) is "A1".


## Letter name of column `x` (0 = A, 25 = Z, 26 = AA).
static func column_name(x: int) -> String:
	var name := ""
	var n := x + 1
	while n > 0:
		n -= 1
		name = String.chr(65 + n % 26) + name
		n /= 26
	return name


## Number name of row `y` (0 = 1).
static func row_name(y: int) -> String:
	return str(y + 1)


static func cell_name(p: Vector2i) -> String:
	return column_name(p.x) + row_name(p.y)
