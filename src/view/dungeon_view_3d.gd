extends Node3D
## First-person 3D view of a floor. Walls come from a GridMap built from the
## rules grid; floor and ceiling are one plane each. A torch light rides on
## the camera and fog hides the distance, so only nearby walls read clearly.

const FloorGrid = preload("res://src/rules/floor_grid.gd")

const CELL := 2.0            ## Width of one grid cell in metres.
const WALL_HEIGHT := 2.6
const EYE_HEIGHT := 1.5
const TURN_TIME := 0.15

enum Item { WALL, STAIRS_UP, STAIRS_DOWN }

var _gridmap: GridMap
var _floor: MeshInstance3D
var _ceiling: MeshInstance3D
var _camera: Camera3D
var _tween: Tween


func _init() -> void:
	var stone := _material(Color("8a7f70"), 0.35)
	var floor_mat := _material(Color("5b5246"), 0.6)
	var ceiling_mat := _material(Color("3d362e"), 0.6)

	_gridmap = GridMap.new()
	_gridmap.cell_size = Vector3(CELL, WALL_HEIGHT, CELL)
	_gridmap.mesh_library = _build_library(stone)
	add_child(_gridmap)

	_floor = MeshInstance3D.new()
	_floor.material_override = floor_mat
	add_child(_floor)

	_ceiling = MeshInstance3D.new()
	_ceiling.material_override = ceiling_mat
	add_child(_ceiling)

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
			var item := -1
			match grid.get_cell(Vector2i(x, y)):
				FloorGrid.Cell.WALL:
					item = Item.WALL
				FloorGrid.Cell.STAIRS_UP:
					item = Item.STAIRS_UP
				FloorGrid.Cell.STAIRS_DOWN:
					item = Item.STAIRS_DOWN
			if item >= 0:
				_gridmap.set_cell_item(Vector3i(x, 0, y), item)

	var extent := Vector2(grid.width, grid.height) * CELL
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = extent
	_floor.mesh = floor_mesh
	_floor.position = Vector3(extent.x / 2, 0, extent.y / 2)

	var ceiling_mesh := PlaneMesh.new()
	ceiling_mesh.size = extent
	ceiling_mesh.flip_faces = true
	_ceiling.mesh = ceiling_mesh
	_ceiling.position = Vector3(extent.x / 2, WALL_HEIGHT, extent.y / 2)


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


func _build_library(stone: StandardMaterial3D) -> MeshLibrary:
	var lib := MeshLibrary.new()

	var wall := BoxMesh.new()
	wall.size = Vector3(CELL, WALL_HEIGHT, CELL)
	wall.material = stone
	lib.create_item(Item.WALL)
	lib.set_item_mesh(Item.WALL, wall)

	# Item meshes are centred in the cell, so shift them down to the floor.
	var to_floor := Transform3D(Basis(), Vector3(0, -WALL_HEIGHT / 2, 0))

	lib.create_item(Item.STAIRS_UP)
	lib.set_item_mesh(Item.STAIRS_UP, _stairs_up_mesh(_material(Color("6f8f6a"), 0.4)))
	lib.set_item_mesh_transform(Item.STAIRS_UP, to_floor)

	lib.create_item(Item.STAIRS_DOWN)
	lib.set_item_mesh(Item.STAIRS_DOWN, _stairs_down_mesh(_material(Color("a3533f"), 0.4)))
	lib.set_item_mesh_transform(Item.STAIRS_DOWN, to_floor)
	return lib


## Four steps climbing toward the back of the cell.
func _stairs_up_mesh(mat: StandardMaterial3D) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 4
	var depth := 1.4 / steps
	for i in steps:
		var box := BoxMesh.new()
		var h := 0.25 * (i + 1)
		box.size = Vector3(1.2, h, depth)
		st.append_from(box, 0, Transform3D(Basis(), Vector3(0, h / 2, 0.7 - depth * (i + 0.5))))
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## A dark pit with a low rim, so it reads as "the way down" from a distance.
func _stairs_down_mesh(rim_mat: StandardMaterial3D) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := 0.12
	var outer := 1.5
	for side in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var box := BoxMesh.new()
		var along_x: bool = side.x == 0
		box.size = Vector3(outer if along_x else rim, 0.15, rim if along_x else outer)
		var offset: Vector3 = side * (outer - rim) / 2.0
		st.append_from(box, 0, Transform3D(Basis(), offset + Vector3(0, 0.075, 0)))
	var mesh := st.commit()
	mesh.surface_set_material(0, rim_mat)

	var pit := PlaneMesh.new()
	pit.size = Vector2(outer - rim * 2, outer - rim * 2)
	var pit_mat := StandardMaterial3D.new()
	pit_mat.albedo_color = Color.BLACK
	pit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var arrays := pit.get_mesh_arrays()
	# Lift the pit just above the floor plane to avoid z-fighting.
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i].y = 0.01
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(1, pit_mat)
	return mesh


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
