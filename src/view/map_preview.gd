extends Control
## The dungeon screen: the player's map next to a first-person 3D view, with
## the party's cards under it. Footsteps fill in on their own; walls are drawn
## by hand with the Pencil by connecting the dots at cell corners. Monsters
## may appear as you walk (see Encounters), and a fight plays out in a log
## over the map. The seed bar and "True layout" are testing tools from
## Phase 1.

const FloorGenerator = preload("res://src/rules/floor_generator.gd")
const FloorGrid = preload("res://src/rules/floor_grid.gd")
const PlayerMap = preload("res://src/rules/player_map.gd")
const Edges = preload("res://src/rules/edges.gd")
const Coords = preload("res://src/rules/coords.gd")
const DungeonView3D = preload("res://src/view/dungeon_view_3d.gd")
const Hero = preload("res://src/rules/hero.gd")
const Motion = preload("res://src/view/motion.gd")
const Monster = preload("res://src/rules/monster.gd")
const Encounters = preload("res://src/rules/encounters.gd")
const Battle = preload("res://src/rules/battle.gd")
const MonsterCards = preload("res://src/view/monster_cards.gd")
const PartyBar = preload("res://src/view/party_bar.gd")

const SETTINGS_PATH := "res://data/generation/floor.json"
const TOWN_SCENE := "res://scenes/main_menu.tscn"

const PAPER := Color("efe4c8")
const INK := Color("3b2f22")
const ROCK := Color("cbbb96")
const WALL_LINE := Color("2a2118")
const FLOOR := Color("f7efd9")
const UNKNOWN := Color("e3d5b2")
const GRID_LINE := Color(0.23, 0.18, 0.13, 0.15)
const VIEWER := Color("2d5fa8")
const WRONG := Color("d0452f")
const TRACE := Color(0.23, 0.18, 0.13, 0.45)
const STAIRS_UP := Color("2f7a5a")
const STAIRS_DOWN := Color("a33b2b")

## W/S forward/back, Q/E strafe, A/D turn.
const MOVE_KEYS: Array[Key] = [KEY_W, KEY_S, KEY_Q, KEY_E, KEY_A, KEY_D]
const HOLD_DELAY := 0.3          ## Pause before a held key starts repeating.
const REPEAT_INTERVAL := 0.2     ## Time between steps while held.
const MOVE_DELAY := 0.6          ## Seconds between moves as the battle log plays.

const LABEL_BAND := Vector2(28, 20)   ## Left strip for row numbers, top strip for column letters.
const MAX_ZOOM := 8.0            ## Zoom 1 fits the whole floor.
const WHEEL_ZOOM := 1.2
const DRAG_THRESHOLD := 8.0      ## Pixels a Move-tool press must travel to pan.

enum Tool { MOVE, PENCIL, ERASER }

var _held_key: Key = KEY_NONE
var _hold_timer := 0.0

var _settings: Dictionary
var _delve_seed := 0                 ## Seed of the delve's first floor; deeper floors derive from it.
var _depth := 1                      ## Which floor of the delve you're on (1 = top, shown as -1).
var _maps := {}                      ## Depth -> PlayerMap: each floor keeps the map you drew.
var _grid: FloorGrid
var _map: PlayerMap
var _show_truth := false
var _view_cell := Vector2i.ZERO
var _facing := 0

var _tool := Tool.PENCIL
var _drawing := false
var _anchor := Edges.NO_DOT          ## Dot the trace line starts from.
var _pointer := Vector2.ZERO         ## Last pointer position, in grid units.
var _trail := PackedVector2Array()   ## Pointer path since the last dot, in grid units.

# Zoom and pan. _pan is the map's offset in pixels from centred.
var _zoom := 1.0
var _pan := Vector2.ZERO
var _panning := false                ## Right/middle drag, or a Move-tool drag.
var _press_pos := Vector2.ZERO       ## Where a Move-tool press started.
var _move_press := false             ## A Move-tool press that may still be a tap.
var _touches := {}                   ## Touch index -> position, for pinch zoom.
var _pinching := false               ## Set while two fingers are (or were) down.

var _panes: BoxContainer
var _canvas: Control
var _view_3d: DungeonView3D
var _seed_edit: LineEdit
var _seed_buttons: Array[Button] = []   ## Go and New floor; off during a fight.
var _info: Label
var _truth_toggle: CheckButton
var _tool_buttons: Array[Button] = []
var _undo_button: Button
var _prompt: Control                 ## Yes/no pop-up over the 3D view ("Go deeper?", "Go up?").
var _prompt_text: Label
var _prompt_yes := Callable()        ## What Yes does.
var _deeper_button: Button           ## Hovers over the 3D view while you stand on the trapdoor.
var _up_button: Button               ## Hovers over the 3D view while you stand at the stairs up.

# Where the map was last drawn, for turning taps into cells.
var _map_origin := Vector2.ZERO
var _map_cell := 0.0

var _party: Array = []               ## Heroes on this delve.
var _party_bar: PartyBar

var _encounter_settings: Dictionary
var _monster_types := {}             ## Type id -> monster type data.
var _encounter_rng := RandomNumberGenerator.new()   ## Seeded per floor.
var _monsters: Array = []            ## The monsters met, while the encounter is waiting for Battle.
var _encounter: MonsterCards         ## The monster cards over the 3D view.
var _battle_log: Control             ## Over the map: every round and move of the last fight.
var _battle_log_title: Label
var _battle_log_text: RichTextLabel
var _battle_log_button: Button
var _party_fell := false             ## The last fight was lost: closing the log goes to town.
var _battle_playing := false         ## The log is still adding moves.
var _battle_skip := false            ## Skip pressed: add the rest at once.
var _battle_playback := 0            ## Bumped per fight and per floor, so an old playback stops.


func _ready() -> void:
	_settings = FloorGenerator.load_settings(SETTINGS_PATH)
	_encounter_settings = Encounters.load_settings()
	_monster_types = Monster.load_types()
	_build_ui()
	_start_party()
	_generate(randi())


## The party for this delve: everyone in the guild's party who isn't down
## (picked in Manage party). With no heroes there are no encounters.
func _start_party() -> void:
	_party = Game.guild.delve_party()
	_party_bar.show_party(_party, Hero.load_classes())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	var key: Key = event.keycode
	if not event.pressed:
		if key == _held_key:
			_held_key = KEY_NONE
		return

	if _battle_log.visible:
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			_close_battle_log()
		return

	if _encounter.visible:
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_start_battle()
		return

	if _prompt.visible:
		match key:
			KEY_ENTER, KEY_KP_ENTER, KEY_Y:
				_answer(true)
			KEY_ESCAPE, KEY_N:
				_answer(false)
		return

	if key == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
		_undo()
		return
	match key:
		KEY_SPACE, KEY_R:
			_generate(randi())
		KEY_RIGHT:
			_generate(_delve_seed + 1)
		KEY_LEFT:
			_generate(_delve_seed - 1)
		KEY_M:
			_truth_toggle.button_pressed = not _truth_toggle.button_pressed
		KEY_1:
			_select_tool(Tool.MOVE)
		KEY_2:
			_select_tool(Tool.PENCIL)
		KEY_3:
			_select_tool(Tool.ERASER)
		_:
			if MOVE_KEYS.has(key):
				_move_key(key)
				# Holding the key keeps moving after a short pause.
				_held_key = key
				_hold_timer = HOLD_DELAY


func _process(delta: float) -> void:
	if _held_key == KEY_NONE:
		return
	_hold_timer -= delta
	if _hold_timer <= 0.0:
		_hold_timer += REPEAT_INTERVAL
		_move_key(_held_key)


func _notification(what: int) -> void:
	# Don't keep walking if the window loses focus mid-hold.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_held_key = KEY_NONE


func _move_key(key: Key) -> void:
	match key:
		KEY_W:
			_step(_facing)
		KEY_S:
			_step((_facing + 2) % 4)
		KEY_Q:
			_step((_facing + 3) % 4)
		KEY_E:
			_step((_facing + 1) % 4)
		KEY_A:
			_turn(-1)
		KEY_D:
			_turn(1)


## Starts a new delve from `seed_value`, on its first floor, with blank maps.
func _generate(seed_value: int) -> void:
	_delve_seed = seed_value
	_maps.clear()
	_load_floor(1)


## Builds floor `depth` of the current delve. Coming down, you arrive in front
## of its stairs up; coming up from below, on its trapdoor. Each floor keeps
## the map you drew there.
func _load_floor(depth: int, from_below: bool = false) -> void:
	_end_stroke()
	_depth = depth
	_grid = FloorGenerator.generate(FloorGenerator.floor_seed(_delve_seed, depth), _settings)
	_drawing = false
	_held_key = KEY_NONE
	if not _maps.has(depth):
		_maps[depth] = PlayerMap.new(_grid.width, _grid.height)
	_map = _maps[depth]
	_seed_edit.text = str(_delve_seed)
	_prompt.hide()
	_encounter.hide()
	_battle_log.hide()
	_battle_playback += 1
	_battle_playing = false
	_party_bar.refresh()
	_monsters = []
	_encounter_rng.seed = Encounters.floor_seed(_grid.seed_value)
	_view_3d.build(_grid)
	if from_below and _grid.in_bounds(_grid.stairs_down):
		_view_cell = _grid.stairs_down
		_facing = _open_facing(_view_cell, 0)
	else:
		_view_cell = _grid.start
		_facing = _open_facing(_view_cell, _grid.start_facing)
	_map.visit(_view_cell)
	_view_3d.set_viewpoint(_view_cell, _facing, false)
	_zoom = 1.0
	_pan = Vector2.ZERO
	_update_floor_buttons()
	_map_changed()


func _map_changed() -> void:
	_info.text = "Floor %s  ·  %d rooms  ·  explored %d / %d cells" % [
		Coords.floor_name(_depth), _grid.rooms.size(), _map.visited_count, _grid.walkable_cells().size()]
	_undo_button.disabled = not _map.can_undo()
	_canvas.queue_redraw()


func _on_seed_submitted(text: String) -> void:
	if _in_fight():
		return
	text = text.strip_edges()
	# Any text works as a seed; numbers are used as-is.
	_generate(int(text) if text.is_valid_int() else text.hash())


# --- Viewpoint ---------------------------------------------------------------

func _turn(amount: int) -> void:
	_facing = posmod(_facing + amount, 4)
	_update_viewpoint()


func _step(direction: int) -> void:
	if _in_fight():
		return
	var next := _view_cell + FloorGrid.DIRECTIONS[direction]
	if next == _grid.stairs_up and _at_stairs_up():
		_ask_up()
	elif _grid.is_walkable(next):
		_map.walk(_view_cell, next)
		_view_cell = next
		_update_viewpoint()
		# No monsters on the trapdoor, so its pop-up always shows.
		if _view_cell == _grid.stairs_down or not _try_encounter():
			_arrived()


func _update_viewpoint() -> void:
	_view_3d.set_viewpoint(_view_cell, _facing)
	_keep_in_view(_view_cell)
	_map_changed()


# --- Encounters -------------------------------------------------------------

## Rolls for monsters after a step. If some appear (one type, maybe a
## group), shows them and returns true.
func _try_encounter() -> bool:
	if _party.is_empty():
		return false
	var type_id := Encounters.roll(_encounter_settings, _encounter_rng)
	if type_id == "" or not _monster_types.has(type_id):
		return false
	var type_data: Dictionary = _monster_types[type_id]
	var count := Encounters.roll_group_size(_encounter_settings, _encounter_rng)
	_monsters = Encounters.spawn_group(type_data, count, _encounter_rng)
	var pictures := {}
	for monster in _monsters:
		pictures[monster] = type_data.get("picture", "")
	_held_key = KEY_NONE
	_prompt.hide()
	_encounter.show()
	_encounter.show_monsters(_monsters, pictures)
	_update_floor_buttons()
	return true


## Battle pressed: the fight is worked out at once, then its log opens over
## the map and plays it back move by move.
func _start_battle() -> void:
	if _monsters.is_empty():
		return
	var start_hp := {}
	for hero in _party:
		start_hp[hero] = hero.hp
	# The monsters stay in view through the fight; only the heading and the
	# button go.
	_encounter.start_fight()
	var battle = Battle.fight(_party, _monsters, _encounter_rng)
	var levels: Dictionary = battle.award_xp()
	_monsters = []
	_play_battle_log(battle, levels, start_hp)


## Opens the log and adds one move every MOVE_DELAY seconds. A hero's card
## hops forward as they attack, and HP bars drop as hits land. The log's
## button skips to the end while it plays.
func _play_battle_log(battle, levels: Dictionary, start_hp: Dictionary) -> void:
	_battle_playback += 1
	var playback := _battle_playback
	_battle_skip = false
	_battle_playing = true
	var names := " & ".join(battle.heroes.map(func(f): return f.name))
	# A group is named by count ("3 Skeletons") to keep the title short.
	var foes: String = battle.monsters[0].name if battle.monsters.size() == 1 			else "%d %ss" % [battle.monsters.size(), battle.monsters[0].name.rsplit(" ", true, 1)[0]]
	_battle_log_title.text = "Battle: %s vs %s" % [names, foes]
	_battle_log_text.text = ""
	_battle_log_button.text = "Skip"
	_held_key = KEY_NONE
	_battle_log.show()
	_update_floor_buttons()
	for hero in start_hp:
		_party_bar.show_hp(hero, start_hp[hero])

	for r in battle.rounds.size():
		_battle_log_text.append_text("[b]Round %d[/b]\n" % (r + 1))
		for move in battle.rounds[r]:
			var by_hero: bool = battle.heroes.has(move["actor"])
			_battle_log_text.append_text(_move_line(move, by_hero) + "\n")
			if battle.heroes.has(move["target"]):
				_party_bar.show_hp(move["target"], move["target_hp"])
			else:
				_encounter.show_hp(move["target"], move["target_hp"])
			if not _battle_skip:
				# The attacker hops toward the other side; whoever is hit shakes.
				if by_hero:
					_party_bar.nudge(move["actor"])
					if move["downed"]:
						_encounter.fade(move["target"])
					elif move["damage"] > 0:
						_encounter.shake(move["target"])
				else:
					_encounter.hop(move["actor"])
					if move["damage"] > 0:
						_party_bar.shake(move["target"])
				var waited := 0.0
				while waited < MOVE_DELAY and not _battle_skip:
					await get_tree().process_frame
					waited += get_process_delta_time()
				if playback != _battle_playback:
					return                  # The log was closed by a new floor.
		_battle_log_text.append_text("\n")

	_battle_log_text.append_text(_battle_result(battle, levels))
	_party_bar.refresh()
	# After a skip, the cards jump straight to how the fight left them.
	_encounter.settle()
	_party_fell = battle.outcome == Battle.Outcome.MONSTERS_WIN
	_battle_log_button.text = "Return to town" if _party_fell else "Continue"
	_battle_playing = false


## The closing lines of the log: who won, XP and level-ups.
func _battle_result(battle, levels: Dictionary) -> String:
	var lines := PackedStringArray()
	match battle.outcome:
		Battle.Outcome.HEROES_WIN:
			var xp: int = battle.rewards()["xp"]
			lines.append("[b]Victory![/b]")
			for hero in battle.heroes:
				if hero.is_down():
					continue
				lines.append("%s gains %d XP." % [hero.name, xp])
				if levels.get(hero, 0) > 0:
					lines.append("[b]%s reaches level %d![/b]" % [hero.name, hero.level])
		Battle.Outcome.MONSTERS_WIN:
			lines.append("[b][color=#%s]The party has fallen.[/color][/b]" % WRONG.to_html(false))
			lines.append("They are carried back to town with 1 HP each.")
		_:
			lines.append("[b]Neither side can win. Both back away.[/b]")
	return "\n".join(lines)


## One log line: who hit whom, for how much, and the HP left. Heroes' moves
## in ink, monsters' in red.
func _move_line(move: Dictionary, by_hero: bool) -> String:
	var actor = move["actor"]
	var target = move["target"]
	var line := "%s attacks %s for %d." % [actor.name, target.name, move["damage"]]
	if move["damage"] == 0:
		line = "%s attacks %s but does no damage." % [actor.name, target.name]
	line += "   %s HP %d/%d" % [target.name, move["target_hp"], target.max_hp]
	if move["downed"]:
		line += "   [b]%s is down![/b]" % target.name
	return line if by_hero else "[color=#%s]%s[/color]" % [WRONG.to_html(false), line]


## The log's button: skips to the end while the fight plays, then closes the
## log, back to walking, or to town if the party fell.
func _close_battle_log() -> void:
	if _battle_playing:
		_battle_skip = true
		return
	_battle_log.hide()
	_encounter.hide()
	if _party_fell:
		Game.guild.carry_back(_party)
		get_tree().change_scene_to_file(TOWN_SCENE)
		return
	_arrived()


# --- Going up and down ------------------------------------------------------

## After moving: stepping onto the trapdoor asks whether to go down.
func _arrived() -> void:
	if _view_cell == _grid.stairs_down:
		var text := "A trapdoor leads down to floor %s.\nGo deeper?" % Coords.floor_name(_depth + 1)
		if _depth >= _delve_floors():
			text = "This is the deepest floor.\nGo down and return to town?"
		_ask(text, _go_deeper)
	else:
		_prompt.hide()
		_update_floor_buttons()


## Walking into the stairs up asks whether to climb them.
func _ask_up() -> void:
	var text := "Stairs lead up to floor %s.\nGo up?" % Coords.floor_name(_depth - 1)
	if _depth <= 1:
		text = "Stairs lead up to town.\nLeave the dungeon?"
	_ask(text, _go_up)


## Shows the yes/no pop-up; Yes runs `on_yes`. Movement stops while it's open.
func _ask(text: String, on_yes: Callable) -> void:
	_held_key = KEY_NONE
	_prompt_text.text = text
	_prompt_yes = on_yes
	_prompt.show()
	_update_floor_buttons()


func _answer(yes: bool) -> void:
	_prompt.hide()
	if yes:
		_prompt_yes.call()
	else:
		_update_floor_buttons()


## The hovering buttons: "Delve deeper" on the trapdoor, "Go up" in front of
## the stairs up. Hidden while the pop-up is open.
func _update_floor_buttons() -> void:
	var free := not _prompt.visible and not _in_fight()
	_deeper_button.visible = free and _view_cell == _grid.stairs_down
	_up_button.visible = free and _at_stairs_up()
	# A new floor mid-fight would skip it (or, after a loss, leave the party
	# down in the dungeon), so the seed bar is off until the log is closed.
	_seed_edit.editable = not _in_fight()
	for button in _seed_buttons:
		button.disabled = _in_fight()


## True while monsters are showing or the battle log is open.
func _in_fight() -> bool:
	return _encounter.visible or _battle_log.visible


## True when you stand on the cell the stairs up open onto.
func _at_stairs_up() -> bool:
	return _grid.in_bounds(_grid.stairs_up) \
		and _view_cell == _grid.stairs_up + FloorGrid.DIRECTIONS[_grid.stairs_up_side]


## Down to the next floor, or back to town after the last one.
func _go_deeper() -> void:
	if _depth >= _delve_floors():
		get_tree().change_scene_to_file(TOWN_SCENE)
		return
	_load_floor(_depth + 1)


## Up to the floor above (arriving on its trapdoor), or out to town from -1.
func _go_up() -> void:
	if _depth <= 1:
		get_tree().change_scene_to_file(TOWN_SCENE)
		return
	_load_floor(_depth - 1, true)


func _delve_floors() -> int:
	return maxi(1, int(_settings.get("delve_floors", 3)))


## First direction from `preferred` (clockwise) that isn't a wall.
func _open_facing(cell: Vector2i, preferred: int) -> int:
	for i in 4:
		var dir := (preferred + i) % 4
		if _grid.is_walkable(cell + FloorGrid.DIRECTIONS[dir]):
			return dir
	return preferred


# --- Map input ---------------------------------------------------------------

func _on_canvas_input(event: InputEvent) -> void:
	if _grid == null:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_on_touch(event)
		return
	if event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
		return
	if event is InputEventPanGesture:
		_pan_by(-event.delta * 12.0)
		return
	if _map_cell <= 0.0:
		return

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(event.position, WHEEL_ZOOM)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1.0 / WHEEL_ZOOM)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
			MOUSE_BUTTON_LEFT:
				_on_left_button(event)
	elif event is InputEventMouseMotion:
		if _panning:
			_pan_by(event.relative)
		elif _move_press and event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			# A Move-tool drag pans the map instead of jumping.
			_move_press = false
			_panning = true
			_pan_by(event.position - _press_pos)
		elif _drawing:
			_continue_stroke(_grid_pos(event.position))


func _on_left_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		if _pinching:
			return
		if _tool == Tool.MOVE:
			_move_press = true
			_press_pos = event.position
		else:
			_start_stroke(_grid_pos(event.position))
	else:
		if _move_press:
			_jump_to(Vector2i(_grid_pos(event.position).floor()))
		_move_press = false
		if _tool == Tool.MOVE:
			_panning = false
		_end_stroke()


## Two fingers pinch to zoom and drag to pan. The first finger also arrives
## as a mouse press, so its stroke (if any) is dropped when the second lands.
func _on_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() >= 2:
				_pinching = true
				_move_press = false
				_cancel_stroke()
		else:
			_touches.erase(event.index)
			if _touches.is_empty():
				_pinching = false
				_panning = false
		return
	if not _touches.has(event.index):
		return
	if _touches.size() < 2:
		_touches[event.index] = event.position
		return
	var keys := _touches.keys()
	var a: Vector2 = _touches[keys[0]]
	var b: Vector2 = _touches[keys[1]]
	var old_mid := (a + b) / 2.0
	var old_dist := a.distance_to(b)
	_touches[event.index] = event.position
	a = _touches[keys[0]]
	b = _touches[keys[1]]
	var mid := (a + b) / 2.0
	_pan_by(mid - old_mid)
	if old_dist > 1.0:
		_zoom_at(mid, a.distance_to(b) / old_dist)


## Canvas position to grid units (1.0 = one cell).
func _grid_pos(pos: Vector2) -> Vector2:
	return (pos - _map_origin) / _map_cell


## Move tool: tap a cell you've walked to jump back there; tap your own cell
## to turn. With the true layout showing, any floor cell works.
func _jump_to(cell: Vector2i) -> void:
	if _in_fight() or not _grid.is_walkable(cell):
		return
	if not _show_truth and not _map.is_visited(cell):
		return
	if cell == _view_cell:
		_turn(1)
	else:
		_view_cell = cell
		_facing = _open_facing(cell, _facing)
		_map.visit(cell)
		_update_viewpoint()
		_arrived()


## Pencil: press to start a trace from the nearest dot, then drag. A wall is
## placed only when the trace reaches another dot in the same row or column;
## the trace then carries on from that dot.
## Eraser: drag over walls to rub them out; the trace shows the whole path.
func _start_stroke(g: Vector2) -> void:
	var dot := Vector2i(roundi(g.x), roundi(g.y))
	if dot.x < 0 or dot.y < 0 or dot.x > _grid.width or dot.y > _grid.height:
		return
	_drawing = true
	_map.begin_stroke()
	_anchor = dot
	_pointer = g
	if _tool == Tool.ERASER:
		_trail = PackedVector2Array([g])
		_erase_at(g)
	else:
		_trail = PackedVector2Array([Vector2(dot), g])
	_canvas.queue_redraw()


## Samples the path since the last pointer position, so a fast drag still
## passes through every dot (or wall) it crosses.
func _continue_stroke(g: Vector2) -> void:
	var steps := maxi(1, ceili(g.distance_to(_pointer) / 0.1))
	for i in range(1, steps + 1):
		var q := _pointer.lerp(g, float(i) / steps)
		if _tool == Tool.ERASER:
			_erase_at(q)
		elif _reach_dot(Edges.dot_near(q)):
			_trail = PackedVector2Array([Vector2(_anchor)])
	if _tool != Tool.ERASER:
		_trail.append(g)
	_pointer = g
	_canvas.queue_redraw()


func _erase_at(g: Vector2) -> void:
	for edge in Edges.near(g):
		if _map.has_wall(edge):
			_map.set_wall(edge, false)


## Connects the anchor to `dot` if they share a row or column. Returns true
## when the anchor moved to `dot`.
func _reach_dot(dot: Vector2i) -> bool:
	if dot == Edges.NO_DOT or dot == _anchor:
		return false
	var edges := Edges.between_dots(_anchor, dot)
	if edges.is_empty():
		return false   # Diagonal: keep tracing from the same dot.
	for edge in edges:
		if _map.can_draw(edge):
			_map.set_wall(edge, true)
	_anchor = dot
	return true


func _end_stroke() -> void:
	if not _drawing:
		return
	_drawing = false
	_map.end_stroke()
	_map_changed()


func _cancel_stroke() -> void:
	if not _drawing:
		return
	_drawing = false
	_map.cancel_stroke()
	_map_changed()


# --- Zoom and pan ------------------------------------------------------------

## Works out the map's cell size and top-left corner on the canvas.
func _update_layout() -> void:
	var area := _canvas.size - LABEL_BAND
	var fit := minf(area.x / _grid.width, area.y / _grid.height)
	_map_cell = floorf(fit * _zoom)
	if _map_cell < 2.0:
		_map_cell = 0.0
		return
	var full := Vector2(_grid.width, _grid.height) * _map_cell
	# Keep the map on screen: no panning on an axis where it fits.
	var slack := ((full - area) / 2.0).max(Vector2.ZERO)
	_pan = _pan.clamp(-slack, slack)
	_map_origin = (LABEL_BAND + (area - full) / 2.0 + _pan).floor()


## Zooms by `factor`, keeping the point under `pos` (canvas pixels) still.
func _zoom_at(pos: Vector2, factor: float) -> void:
	_update_layout()
	if _map_cell <= 0.0:
		return
	var g := _grid_pos(pos)
	_zoom = clampf(_zoom * factor, 1.0, MAX_ZOOM)
	_update_layout()
	_pan += pos - (_map_origin + g * _map_cell)
	_canvas.queue_redraw()


func _pan_by(delta: Vector2) -> void:
	_pan += delta
	_canvas.queue_redraw()


## Zoom buttons: a factor, or 0 to fit the whole floor.
func _zoom_button(factor: float) -> void:
	if factor == 0.0:
		_zoom = 1.0
		_pan = Vector2.ZERO
		_canvas.queue_redraw()
	else:
		_zoom_at(_canvas.size / 2.0, factor)


## When zoomed in, pans so `cell` stays clear of the map's edge.
func _keep_in_view(cell: Vector2i) -> void:
	_update_layout()
	if _map_cell <= 0.0:
		return
	var margin := _map_cell * 1.5
	var p := _map_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _map_cell
	var lo := LABEL_BAND + Vector2(margin, margin)
	var hi := _canvas.size - Vector2(margin, margin)
	_pan += p.clamp(lo, hi) - p


func _undo() -> void:
	_end_stroke()
	if _map.undo():
		_map_changed()


func _select_tool(which: Tool) -> void:
	_tool = which
	_tool_buttons[which].button_pressed = true


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	column.add_child(bar)

	bar.add_child(_label("Seed"))
	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size.x = 160
	_seed_edit.text_submitted.connect(_on_seed_submitted)
	bar.add_child(_seed_edit)

	var go := Button.new()
	go.text = "Go"
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func(): _on_seed_submitted(_seed_edit.text))
	bar.add_child(go)

	var reroll := Button.new()
	reroll.text = "New floor"
	reroll.focus_mode = Control.FOCUS_NONE
	reroll.pressed.connect(func():
		if not _in_fight():
			_generate(randi()))
	bar.add_child(reroll)
	_seed_buttons = [go, reroll]

	_truth_toggle = CheckButton.new()
	_truth_toggle.text = "True layout"
	_truth_toggle.focus_mode = Control.FOCUS_NONE
	_truth_toggle.add_theme_color_override("font_color", INK)
	_truth_toggle.add_theme_color_override("font_pressed_color", INK)
	_truth_toggle.add_theme_color_override("font_hover_color", INK)
	_truth_toggle.toggled.connect(_on_truth_toggled)
	bar.add_child(_truth_toggle)

	_info = _label("")
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.clip_text = true
	bar.add_child(_info)

	# Map and 3D side by side; stacked when the screen is taller than wide.
	_panes = BoxContainer.new()
	_panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panes.add_theme_constant_override("separation", 16)
	_panes.resized.connect(func(): _panes.vertical = _panes.size.y > _panes.size.x)
	column.add_child(_panes)

	var map_pane := VBoxContainer.new()
	map_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_pane.add_theme_constant_override("separation", 8)
	_panes.add_child(map_pane)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	map_pane.add_child(tools)
	var group := ButtonGroup.new()
	tools.add_child(_tool_button(Tool.MOVE, "Move", group))

	_undo_button = Button.new()
	_undo_button.text = "Undo"
	_undo_button.focus_mode = Control.FOCUS_NONE
	_undo_button.custom_minimum_size = Vector2(72, 36)
	_undo_button.pressed.connect(_undo)
	tools.add_child(_undo_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	for entry in [["−", 1.0 / 1.5], ["+", 1.5], ["Fit", 0.0]]:
		var zoom_button := Button.new()
		zoom_button.text = entry[0]
		zoom_button.focus_mode = Control.FOCUS_NONE
		zoom_button.custom_minimum_size = Vector2(44, 36)
		var factor: float = entry[1]
		zoom_button.pressed.connect(func(): _zoom_button(factor))
		tools.add_child(zoom_button)

	var map_row := HBoxContainer.new()
	map_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_row.add_theme_constant_override("separation", 8)
	map_pane.add_child(map_row)

	# Toolbox: a box left of the map with the drawing tools. Map icons will
	# join it as the things they mark are added.
	var toolbox := PanelContainer.new()
	var toolbox_style := StyleBoxFlat.new()
	toolbox_style.bg_color = UNKNOWN
	toolbox_style.border_color = INK
	toolbox_style.set_border_width_all(2)
	toolbox_style.set_corner_radius_all(4)
	toolbox_style.set_content_margin_all(8)
	toolbox.add_theme_stylebox_override("panel", toolbox_style)
	map_row.add_child(toolbox)
	var draw_tools := VBoxContainer.new()
	draw_tools.add_theme_constant_override("separation", 6)
	toolbox.add_child(draw_tools)
	draw_tools.add_child(_tool_button(Tool.PENCIL, "Pencil", group))
	draw_tools.add_child(_tool_button(Tool.ERASER, "Eraser", group))
	_tool_buttons[_tool].button_pressed = true

	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_map)
	_canvas.resized.connect(_canvas.queue_redraw)
	_canvas.gui_input.connect(_on_canvas_input)
	map_row.add_child(_canvas)
	_canvas.add_child(_build_battle_log())

	# 3D view with the party bar under it.
	var view_pane := VBoxContainer.new()
	view_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_pane.add_theme_constant_override("separation", 8)
	_panes.add_child(view_pane)

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = INK
	frame_style.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", frame_style)
	view_pane.add_child(frame)

	_party_bar = PartyBar.new()
	view_pane.add_child(_party_bar)

	var container := SubViewportContainer.new()
	container.stretch = true
	frame.add_child(container)
	var viewport := SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	_view_3d = DungeonView3D.new()
	viewport.add_child(_view_3d)
	frame.add_child(_build_floor_overlay())

	var legend := _label("W/S move · Q/E strafe · A/D turn (hold to repeat)   ·   1 Move tool: tap a walked cell to jump   ·   2 Pencil: drag from dot to dot to draw walls   ·   3 Eraser: drag over walls to rub them out   ·   wheel or pinch to zoom, right-drag (or drag with Move) to pan   ·   Ctrl+Z undo   ·   M true layout   ·   Space new floor")
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(legend)


## Sits over the 3D view: the yes/no pop-up in the middle, and the
## "Delve deeper" and "Go up" buttons near the bottom. All start hidden.
func _build_floor_overlay() -> Control:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(centre)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", style)
	centre.add_child(box)
	_prompt = box

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	box.add_child(column)
	_prompt_text = _label("")
	_prompt_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_text.add_theme_font_size_override("font_size", 22)
	column.add_child(_prompt_text)

	var answers := HBoxContainer.new()
	answers.alignment = BoxContainer.ALIGNMENT_CENTER
	answers.add_theme_constant_override("separation", 12)
	column.add_child(answers)
	for entry in [["Yes", true], ["No", false]]:
		var answer := Button.new()
		answer.text = entry[0]
		answer.focus_mode = Control.FOCUS_NONE
		answer.custom_minimum_size = Vector2(110, 44)
		var yes: bool = entry[1]
		answer.pressed.connect(func(): _answer(yes))
		answers.add_child(answer)

	# The two never show at once (the trapdoor is in another room), so they
	# share a spot.
	_deeper_button = _hover_button("Delve deeper", _go_deeper)
	overlay.add_child(_deeper_button)
	_up_button = _hover_button("Go up", _go_up)
	overlay.add_child(_up_button)

	_encounter = MonsterCards.new()
	_encounter.battle_pressed.connect(_start_battle)
	_encounter.hide()
	overlay.add_child(_encounter)

	_prompt.hide()
	return overlay


## The battle log, covering the map: a title, the rounds (scrolls if long)
## and a button to close it. Hidden at first.
func _build_battle_log() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP     # The map underneath can't be drawn on.
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	_battle_log_title = _label("")
	_battle_log_title.add_theme_font_size_override("font_size", 22)
	_battle_log_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # Never widens the log.
	column.add_child(_battle_log_title)

	_battle_log_text = RichTextLabel.new()
	_battle_log_text.bbcode_enabled = true
	_battle_log_text.scroll_active = true
	_battle_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_log_text.add_theme_color_override("default_color", INK)
	_battle_log_text.add_theme_font_size_override("normal_font_size", 16)
	_battle_log_text.add_theme_font_size_override("bold_font_size", 16)
	column.add_child(_battle_log_text)

	_battle_log_button = Button.new()
	_battle_log_button.text = "Continue"
	_battle_log_button.focus_mode = Control.FOCUS_NONE
	_battle_log_button.custom_minimum_size = Vector2(160, 44)
	_battle_log_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_battle_log_button.pressed.connect(_close_battle_log)
	column.add_child(_battle_log_button)

	_battle_log = panel
	_battle_log.hide()
	return panel


## A button floating near the bottom middle of the 3D view, hidden at first.
func _hover_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -90
	button.offset_right = 90
	button.offset_top = -72
	button.offset_bottom = -24
	button.pressed.connect(action)
	button.hide()
	return button


## A toggle button for `which`, stored in _tool_buttons at index `which`.
func _tool_button(which: Tool, text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(72, 36)
	button.pressed.connect(func(): _tool = which)
	if _tool_buttons.size() <= which:
		_tool_buttons.resize(which + 1)
	_tool_buttons[which] = button
	return button


func _on_truth_toggled(on: bool) -> void:
	_show_truth = on
	_canvas.queue_redraw()


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", INK)
	return label


# --- Map drawing -------------------------------------------------------------

func _draw_map() -> void:
	if _grid == null:
		return
	_update_layout()
	if _map_cell <= 0.0:
		return
	var origin := _map_origin
	var cell := _map_cell
	var size := Vector2(cell, cell)

	for y in _grid.height:
		for x in _grid.width:
			var p := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(p) * cell, size)
			if _show_truth:
				_draw_true_cell(p, rect)
			else:
				_draw_player_cell(p, rect)

	# Graph-paper lines.
	var full := Vector2(_grid.width, _grid.height) * cell
	for x in _grid.width + 1:
		var px := origin.x + x * cell
		_canvas.draw_line(Vector2(px, origin.y), Vector2(px, origin.y + full.y), GRID_LINE)
	for y in _grid.height + 1:
		var py := origin.y + y * cell
		_canvas.draw_line(Vector2(origin.x, py), Vector2(origin.x + full.x, py), GRID_LINE)
	# Frame, kept just inside the map so the label strips don't cover its top
	# and left sides.
	_canvas.draw_rect(Rect2(origin + Vector2.ONE, full - Vector2.ONE * 2.0), INK, false, 2.0)

	# Walls: bold lines on cell edges.
	var width := clampf(cell * 0.22, 3.0, 10.0)
	if _show_truth:
		for edge in _true_wall_edges():
			_draw_wall(edge, WALL_LINE, width)
		# Lines you drew where there's no real wall.
		for edge in _map.wall_edges():
			if not _grid.has_wall(edge):
				_draw_wall(edge, WRONG, width)
	else:
		for edge in _map.wall_edges():
			_draw_wall(edge, WALL_LINE, width)

	# Eraser: a circle under the pointer, the size of what it rubs out.
	if _drawing and _tool == Tool.ERASER:
		var at := origin + _pointer * cell
		var radius := maxf(4.0, cell * Edges.ERASER_REACH)
		_canvas.draw_circle(at, radius, Color(WRONG, 0.25))
		_canvas.draw_arc(at, radius, 0.0, TAU, 24, Color(WRONG, 0.8), 1.5, true)
	# Pencil: the pointer's path since the last dot, starting with a dot mark.
	elif _drawing:
		var trace_width := clampf(cell * 0.12, 2.0, 6.0)
		var points := PackedVector2Array()
		for q in _trail:
			points.append(origin + q * cell)
		if points.size() >= 2:
			_canvas.draw_polyline(points, TRACE, trace_width, true)
		_canvas.draw_circle(points[0], trace_width * 1.4, TRACE)

	# Viewpoint: a dot with an arrow toward the facing direction.
	var view_rect := Rect2(origin + Vector2(_view_cell) * cell, size)
	_canvas.draw_circle(view_rect.get_center(), cell * 0.5, Color(VIEWER, 0.25))
	_draw_arrow(view_rect, _facing, VIEWER)

	_draw_labels()


## Column letters along the top and row numbers down the left. The strips stay
## put while the map pans under them; labels thin out when cells are small.
## The viewer's column and row are highlighted.
func _draw_labels() -> void:
	var font := ThemeDB.fallback_font
	var cell := _map_cell
	var font_size := int(clampf(cell * 0.55, 9.0, 14.0))
	var area := _canvas.size
	# The strips hug the map's top and left edges, or the canvas edge once the
	# map is bigger than the view.
	var top := maxf(0.0, _map_origin.y - LABEL_BAND.y)
	var left := maxf(0.0, _map_origin.x - LABEL_BAND.x)
	_canvas.draw_rect(Rect2(0, 0, area.x, top + LABEL_BAND.y), PAPER)
	_canvas.draw_rect(Rect2(0, 0, left + LABEL_BAND.x, area.y), PAPER)
	var centre_y := (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0

	var widest := Coords.column_name(_grid.width - 1)
	var col_width := font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 1.0
	var col_step := maxi(1, ceili(col_width / cell))
	for x in range(0, _grid.width, col_step):
		var cx := _map_origin.x + (x + 0.5) * cell
		if cx < left + LABEL_BAND.x or cx > area.x:
			continue
		_draw_label(Coords.column_name(x), Vector2(cx, top + LABEL_BAND.y / 2.0 + centre_y), x == _view_cell.x, font, font_size)

	var row_step := maxi(1, ceili((font_size + 2.0) / cell))
	for y in range(0, _grid.height, row_step):
		var cy := _map_origin.y + (y + 0.5) * cell
		if cy < top + LABEL_BAND.y or cy > area.y:
			continue
		_draw_label(Coords.row_name(y), Vector2(left + LABEL_BAND.x / 2.0, cy + centre_y), y == _view_cell.y, font, font_size)


## Text centred horizontally on `at` (at.y is the baseline).
func _draw_label(text: String, at: Vector2, highlight: bool, font: Font, font_size: int) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_canvas.draw_string(font, Vector2(at.x - w / 2.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VIEWER if highlight else Color(INK, 0.75))


## The player's map: walked cells filled in, blank paper elsewhere.
func _draw_player_cell(p: Vector2i, rect: Rect2) -> void:
	if _map.is_visited(p):
		_canvas.draw_rect(rect, FLOOR)
	else:
		_canvas.draw_rect(rect, UNKNOWN)


## The real layout: open floor, solid rock shaded, stairs up as a green
## arrow and the trapdoor down as a red one.
func _draw_true_cell(p: Vector2i, rect: Rect2) -> void:
	_canvas.draw_rect(rect, FLOOR if _grid.is_walkable(p) else ROCK)
	match _grid.get_cell(p):
		FloorGrid.Cell.STAIRS_UP:
			_draw_arrow(rect, 0, STAIRS_UP)
		FloorGrid.Cell.STAIRS_DOWN:
			_draw_arrow(rect, 2, STAIRS_DOWN)


func _true_wall_edges() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for y in range(-1, _grid.height):
		for x in range(-1, _grid.width):
			for axis in [Edges.VERTICAL, Edges.HORIZONTAL]:
				var edge := Vector3i(x, y, axis)
				if Edges.in_bounds(edge, _grid.width, _grid.height) and _grid.has_wall(edge):
					result.append(edge)
	return result


## A bold line along `edge`, with round ends so corners join cleanly.
func _draw_wall(edge: Vector3i, color: Color, width: float) -> void:
	var seg := Edges.segment(edge)
	var a := _map_origin + seg[0] * _map_cell
	var b := _map_origin + seg[1] * _map_cell
	_canvas.draw_line(a, b, color, width)
	_canvas.draw_circle(a, width / 2.0, color)
	_canvas.draw_circle(b, width / 2.0, color)


## Triangle inside `rect` pointing along FloorGrid.DIRECTIONS[direction].
func _draw_arrow(rect: Rect2, direction: int, color: Color) -> void:
	var c := rect.get_center()
	var r := rect.size.x * 0.34
	var points := PackedVector2Array()
	for corner in [Vector2(0, -1), Vector2(0.85, 0.75), Vector2(-0.85, 0.75)]:
		points.append(c + (corner as Vector2).rotated(direction * PI / 2.0) * r)
	_canvas.draw_colored_polygon(points, color)
