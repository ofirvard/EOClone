extends Node3D
## First-person 3D view of a floor. Walls come from a GridMap built from the
## rules grid. A torch light rides on the camera and fog hides the distance,
## so only nearby walls read clearly. Textures come from a theme file in
## data/themes/. Stairs up are a picture on one face of a wall block; the
## trapdoor down is a picture lying on the floor. Wall torches are animated
## pictures, each with a flickering light.
##
## Floor and ceiling are tiled per cell (in their own GridMap) rather than one
## big plane: the Mobile renderer lights each mesh with at most 8 lights, and
## small chunks keep that to the torches nearby.

const FloorGrid = preload("res://src/rules/floor_grid.gd")

const CELL := 2.0            ## Width of one grid cell in metres.
const WALL_HEIGHT := 2.0     ## Same as CELL, so square wall textures aren't stretched.
const EYE_HEIGHT := 1.1
const TURN_TIME := 0.15
const THEME_PATH := "res://data/themes/basement.json"
const DECAL_LIFT := 0.01     ## Gap that keeps a picture from flickering into the surface under it.
const TRAPDOOR_SIZE := 0.9   ## Share of the cell the trapdoor picture spans.
const TORCH_SIZE := 1.0      ## Torch picture width and height, in metres.
const TORCH_HEIGHT := 1.25   ## Height of the torch picture's centre.
const FLAME_HEIGHT := 1.45   ## Where the torch's light sits.
const FLAME_OUT := 0.3       ## How far the light sits out from the wall.
const CHUNK := 4             ## GridMap octant size in cells (see the note above).


var _gridmap: GridMap
var _floor_map: GridMap      ## One floor-and-ceiling tile per open cell.
var _camera: Camera3D
var _tween: Tween
var _floor_mat: StandardMaterial3D
var _ceiling_mat: StandardMaterial3D
var _wall_weights: Array[int] = []
var _stairs_up_mat: StandardMaterial3D
var _stairs_down_mat: StandardMaterial3D
var _props: Node3D           ## Stairs, trapdoor and torches; rebuilt with each floor.
var _torch_frames: Array[StandardMaterial3D] = []
var _torch_fps := 7.0
var _torch_light := {}
var _torches: Array[MeshInstance3D] = []
var _torch_lights: Array[OmniLight3D] = []
var _clock := 0.0


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
	if theme.has("torch"):
		for path in theme["torch"].get("frames", []):
			_torch_frames.append(_glow_material(path))
		_torch_fps = float(theme["torch"].get("fps", 7))
		_torch_light = theme["torch"].get("light", {})

	_gridmap = GridMap.new()
	_gridmap.cell_size = Vector3(CELL, WALL_HEIGHT, CELL)
	_gridmap.mesh_library = _build_library(wall_mats)
	_gridmap.cell_octant_size = CHUNK
	add_child(_gridmap)

	_floor_map = GridMap.new()
	_floor_map.cell_size = Vector3(CELL, WALL_HEIGHT, CELL)
	_floor_map.cell_octant_size = CHUNK
	_floor_map.mesh_library = _floor_library()
	add_child(_floor_map)

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

	_floor_map.clear()
	for p in grid.walkable_cells():
		_floor_map.set_cell_item(Vector3i(p.x, 0, p.y), 0)

	_build_props(grid)
	_build_torches(grid)


## Swaps torch frames and flickers their lights.
func _process(delta: float) -> void:
	if _torches.is_empty():
		return
	_clock += delta
	var frame := int(_clock * _torch_fps)
	var base := float(_torch_light.get("energy", 1.6))
	for i in _torches.size():
		# Each torch starts on its own frame and flickers on its own rhythm.
		_torches[i].material_override = _torch_frames[(frame + i) % _torch_frames.size()]
		var t := _clock * 9.0 + i * 1.7
		_torch_lights[i].light_energy = base * (0.85 + 0.1 * sin(t) + 0.05 * sin(t * 2.3))


## A torch picture on the wall behind each torch spot, with a warm light just
## in front of its flame.
func _build_torches(grid: FloorGrid) -> void:
	_torches.clear()
	_torch_lights.clear()
	if _torch_frames.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(TORCH_SIZE, TORCH_SIZE)
	for spot in grid.torches:
		var side := FloorGrid.DIRECTIONS[spot.z]
		var toward_wall := Vector3(side.x, 0, side.y)
		var cell := Vector2i(spot.x, spot.y)

		var torch := MeshInstance3D.new()
		torch.mesh = quad
		torch.material_override = _torch_frames[0]
		torch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Face back into the cell, flat on the wall.
		torch.rotation.y = atan2(-side.x, -side.y)
		torch.position = _cell_centre(cell, TORCH_HEIGHT) + toward_wall * (CELL / 2.0 - DECAL_LIFT)
		_props.add_child(torch)
		_torches.append(torch)

		var light := OmniLight3D.new()
		light.light_color = Color(_torch_light.get("color", "ffad5c"))
		light.light_energy = float(_torch_light.get("energy", 1.6))
		light.omni_range = float(_torch_light.get("range", 5.0))
		light.omni_attenuation = 1.4
		# Shadows stop the light at walls instead of shining through into the
		# room behind. The scene never moves, so each shadow is drawn once.
		light.shadow_enabled = true
		light.position = _cell_centre(cell, FLAME_HEIGHT) + toward_wall * (CELL / 2.0 - FLAME_OUT)
		_props.add_child(light)
		_torch_lights.append(light)


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
		stairs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		trapdoor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


## One tile: a floor square and the ceiling square above it, each with the
## texture once. Items sit at the cell's middle height, hence the offsets.
func _floor_library() -> MeshLibrary:
	var tile := ArrayMesh.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(CELL, CELL)
	floor_plane.center_offset = Vector3(0, -WALL_HEIGHT / 2.0, 0)
	var ceiling_plane := PlaneMesh.new()
	ceiling_plane.size = Vector2(CELL, CELL)
	ceiling_plane.flip_faces = true
	ceiling_plane.center_offset = Vector3(0, WALL_HEIGHT / 2.0, 0)
	for part in [[floor_plane, _floor_mat], [ceiling_plane, _ceiling_mat]]:
		tile.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part[0].get_mesh_arrays())
		var mat: StandardMaterial3D = part[1]
		if not (mat.albedo_texture is NoiseTexture2D):
			mat.uv1_scale = Vector3.ONE
		tile.surface_set_material(tile.get_surface_count() - 1, mat)
	var lib := MeshLibrary.new()
	lib.create_item(0)
	lib.set_item_mesh(0, tile)
	return lib


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


## A torch frame: unlit (the flame is its own light), with its soft glow
## halo blended over the wall behind it.
func _glow_material(path: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
