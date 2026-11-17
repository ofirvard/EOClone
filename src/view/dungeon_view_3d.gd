extends Node3D
## First-person 3D view of a floor. Walls come from a GridMap built from the
## rules grid; floor and ceiling are one plane each. A torch light rides on
## the camera and fog hides the distance, so only nearby walls read clearly.
## Textures come from a theme file in data/themes/. Stairs up are a picture on
## one face of a wall block; the trapdoor down is a picture lying on the floor.

const FloorGrid = preload("res://src/rules/floor_grid.gd")

const CELL := 2.0            ## Width of one grid cell in metres.
const WALL_HEIGHT := 2.0     ## Same as CELL, so square wall textures aren't stretched.
const EYE_HEIGHT := 1.1
const TURN_TIME := 0.15
const THEME_PATH := "res://data/themes/basement.json"
const DECAL_LIFT := 0.01     ## Gap that keeps a picture from flickering into the surface under it.
const TRAPDOOR_SIZE := 0.9   ## Share of the cell the trapdoor picture spans.


var _gridmap: GridMap
var _floor: MeshInstance3D
var _ceiling: MeshInstance3D
var _camera: Camera3D
var _tween: Tween
var _floor_mat: StandardMaterial3D
var _ceiling_mat: StandardMaterial3D
var _wall_weights: Array[int] = []
var _stairs_up_mat: StandardMaterial3D
var _stairs_down_mat: StandardMaterial3D
var _props: Node3D           ## Stairs and trapdoor pictures; rebuilt with each floor.


func _init() -> void:
	var theme := _load_theme(THEME_PATH)
	var wall_mats: Array[StandardMaterial3D] = []
	for wall in theme.get("walls", []):
		wall_mats.append(_texture_material(wall))
		_wall_weights.append(int(wall.get("weight", 1)))
	if wall_mats.is_empty():
		wall_mats.append(_material(Color("8a7f70"), 0.35))
		_wall_weights.append(1)
	_floor_mat = _texture_material(theme["floor"]) if theme.has("floor") else _material(Color("5b5246"), 0.6)
	_ceiling_mat = _texture_material(theme["ceiling"]) if theme.has("ceiling") else _material(Color("3d362e"), 0.6)
	if theme.has("stairs_up"):
		_stairs_up_mat = _decal_material(theme["stairs_up"])
	if theme.has("stairs_down"):
		_stairs_down_mat = _decal_material(theme["stairs_down"])

	_gridmap = GridMap.new()
	_gridmap.cell_size = Vector3(CELL, WALL_HEIGHT, CELL)
	_gridmap.mesh_library = _build_library(wall_mats)
	add_child(_gridmap)

	_floor = MeshInstance3D.new()
	_floor.material_override = _floor_mat
	add_child(_floor)

	_ceiling = MeshInstance3D.new()
	_ceiling.material_override = _ceiling_mat
	add_child(_ceiling)

	_props = Node3D.new()
	add_child(_props)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d0b09")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6b5a45")
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color("0d0b09")
	env.fog_density = 0.09
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_camera = Camera3D.new()
	_camera.fov = 72.0
	_camera.near = 0.05
	_camera.current = true
	add_child(_camera)

	var torch := OmniLight3D.new()
	torch.light_color = Color("ffc985")
	torch.light_energy = 2.2
	torch.omni_range = 10.0
	torch.omni_attenuation = 1.2
	torch.position = Vector3(0.3, 0.2, 0.0)
	_camera.add_child(torch)


## Rebuilds the level geometry for a new floor.
func build(grid: FloorGrid) -> void:
	_gridmap.clear()
	for y in grid.height:
		for x in grid.width:
			if not grid.is_walkable(Vector2i(x, y)):
				_gridmap.set_cell_item(Vector3i(x, 0, y), _wall_variant(x, y, grid.seed_value))

	var extent := Vector2(grid.width, grid.height) * CELL
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = extent
	_floor.mesh = floor_mesh
	_floor.position = Vector3(extent.x / 2, 0, extent.y / 2)
	# Plane UVs run 0..1 across the whole floor; repeat the texture once per cell.
	if not (_floor_mat.albedo_texture is NoiseTexture2D):
		_floor_mat.uv1_scale = Vector3(grid.width, grid.height, 1)
	if not (_ceiling_mat.albedo_texture is NoiseTexture2D):
		_ceiling_mat.uv1_scale = Vector3(grid.width, grid.height, 1)

	var ceiling_mesh := PlaneMesh.new()
	ceiling_mesh.size = extent
	ceiling_mesh.flip_faces = true
	_ceiling.mesh = ceiling_mesh
	_ceiling.position = Vector3(extent.x / 2, WALL_HEIGHT, extent.y / 2)

	_build_props(grid)


## The stairs picture on the wall face toward the room, and the trapdoor
## picture on the floor. Each keeps its texture's proportions.
func _build_props(grid: FloorGrid) -> void:
	for child in _props.get_children():
		child.queue_free()

	if _stairs_up_mat and grid.in_bounds(grid.stairs_up):
		var side := FloorGrid.DIRECTIONS[grid.stairs_up_side]
		var quad := QuadMesh.new()
		quad.size = Vector2(WALL_HEIGHT * _aspect(_stairs_up_mat), WALL_HEIGHT)
		var stairs := MeshInstance3D.new()
		stairs.mesh = quad
		stairs.material_override = _stairs_up_mat
		# A quad faces +Z; turn it to face the open cell, on the wall's surface.
		stairs.rotation.y = atan2(side.x, side.y)
		stairs.position = _cell_centre(grid.stairs_up, WALL_HEIGHT / 2.0) 			+ Vector3(side.x, 0, side.y) * (CELL / 2.0 + DECAL_LIFT)
		_props.add_child(stairs)

	if _stairs_down_mat and grid.in_bounds(grid.stairs_down):
		var plane := PlaneMesh.new()
		var aspect := _aspect(_stairs_down_mat)
		var span := CELL * TRAPDOOR_SIZE
		plane.size = Vector2(span, span / aspect) if aspect >= 1.0 else Vector2(span * aspect, span)
		var trapdoor := MeshInstance3D.new()
		trapdoor.mesh = plane
		trapdoor.material_override = _stairs_down_mat
		trapdoor.position = _cell_centre(grid.stairs_down, DECAL_LIFT)
		_props.add_child(trapdoor)


func _cell_centre(cell: Vector2i, height: float) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL, height, (cell.y + 0.5) * CELL)


## Width over height of a material's texture.
func _aspect(mat: StandardMaterial3D) -> float:
	var size := mat.albedo_texture.get_size()
	return size.x / size.y


## Puts the camera in `cell` looking along FloorGrid.DIRECTIONS[facing]
## (0 north, 1 east, 2 south, 3 west).
func set_viewpoint(cell: Vector2i, facing: int, animate: bool = true) -> void:
	var target_pos := Vector3((cell.x + 0.5) * CELL, EYE_HEIGHT, (cell.y + 0.5) * CELL)
	var target_yaw := -facing * PI / 2.0
	# Turn the short way round.
	target_yaw = _camera.rotation.y + wrapf(target_yaw - _camera.rotation.y, -PI, PI)

	if _tween:
		_tween.kill()
	if not animate:
		_camera.position = target_pos
		_camera.rotation.y = target_yaw
		return
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_camera, "position", target_pos, TURN_TIME)
	_tween.tween_property(_camera, "rotation:y", target_yaw, TURN_TIME)


## Picks a wall texture for a rock cell, weighted, the same every time for
## the same floor.
func _wall_variant(x: int, y: int, seed_value: int) -> int:
	var total := 0
	for w in _wall_weights:
		total += w
	var roll := posmod(hash(Vector3i(x, y, seed_value)), total)
	for i in _wall_weights.size():
		roll -= _wall_weights[i]
		if roll < 0:
			return i
	return 0


func _build_library(wall_mats: Array[StandardMaterial3D]) -> MeshLibrary:
	var lib := MeshLibrary.new()

	for i in wall_mats.size():
		var wall := BoxMesh.new()
		wall.size = Vector3(CELL, WALL_HEIGHT, CELL)
		wall.material = wall_mats[i]
		lib.create_item(i)
		lib.set_item_mesh(i, wall)

	return lib


func _load_theme(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("No theme at %s; using plain colours." % path)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}


## A material from a theme entry: {"texture": path, "tint": "rrggbb"}.
## Pixel-art textures keep hard pixels (nearest filtering).
func _texture_material(entry: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(entry["texture"])
	if entry.has("tint"):
		mat.albedo_color = Color(entry["tint"])
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.95
	# BoxMesh packs its six faces into a 3x2 grid of the texture; this scale
	# makes each face show the whole texture once.
	mat.uv1_scale = Vector3(3, 2, 1)
	return mat


## A material for a picture shown once on a quad: hard pixels, and see-through
## where the texture is (so the trapdoor's corners show the floor).
func _decal_material(entry: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(entry["texture"])
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.roughness = 0.95
	return mat


## Plain colour with a soft noise texture so surfaces don't look flat.
func _material(color: Color, noise_strength: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 128
	tex.height = 128
	var ramp := Gradient.new()
	ramp.set_color(0, color.darkened(noise_strength))
	ramp.set_color(1, color.lightened(noise_strength * 0.3))
	tex.color_ramp = ramp

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.95
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return mat
