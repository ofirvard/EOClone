# EOClone

A cartography-focused dungeon crawler inspired by Etrian Odyssey. You run a cartographers' guild, hire a party of adventurers, and draw maps by hand while exploring randomly generated dungeons. Combat is light: you give orders at the start of each fight and it resolves on its own.

Targets phone and PC.

## Docs

- [Design doc](docs/design.md)
- [Plan](docs/plan.md): build order in eight phases

## Status

Phase 1 (map making) of the [plan](docs/plan.md) is done: seeded 3-floor delves, a first-person view and a hand-drawn map for each floor. Engine: Godot 4.7.

## Running

Open the folder in Godot 4.7 (Import → select `project.godot`) and press F5. The game opens on the town menu; pick **Delve** to enter a dungeon (the other places do nothing yet). The map on the left fills in only the cells you've stepped on; the 3D window on the right looks from the blue marker. Turn on **True layout** (or press M) to see the whole generated floor.

- Type a seed and press Go to start a delve from it. Space starts a new delve; ←/→ step to the previous or next seed.
- Floors are numbered -1, -2, -3. Step onto the trapdoor to go deeper, or walk into the stairs up to go up; each asks first. While you stand on the trapdoor or in front of the stairs, a **Delve deeper** or **Go up** button stays on screen. Up from -1, or down from -3, returns you to town. Each floor keeps its map while you go up and down.
- W/S move, Q/E strafe, A/D turn. Hold a key to keep going, one step at a time.
- **Pencil** (2, the default; in the toolbox left of the map): walls are bold lines on the edges between cells. Press and drag: a trace follows the pointer's path from the nearest grid dot (cell corner), and a wall is placed only when the trace reaches another dot in the same row or column. Keep dragging to chain walls. You can't draw a wall across a step you've walked.
- **Eraser** (3, in the toolbox): drag over walls to rub them out; a red circle shows what it will rub out.
- **Move tool** (1): tap or click a cell you've walked on to jump back there; tap your own cell to turn. Drag to pan the map.
- **Zoom:** mouse wheel, trackpad or two-finger pinch, or the −, + and Fit buttons. Right- or middle-drag pans (two fingers on touch). When zoomed in, the map follows you as you walk.
- **Coordinates:** columns are lettered along the top (A, B, ... Z, AA, ...) and rows numbered down the left, so the top-left cell is A1. Your current column and row are shown in blue.
- **Undo** (Ctrl+Z) takes back the last stroke.
- With **True layout** on, the real walls are drawn in black and any line you drew where there's no real wall shows in red.

Headless rule tests:

```
godot --headless --path . --script res://tests/run_tests.gd
```

## Layout

- `src/rules/`: game rules with no rendering (grid, generator, the player's map). Testable headless.
- `src/view/`: scenes' scripts that draw or display the rules.
- `scenes/`: Godot scenes.
- `data/`: content and tuning (`data/generation/floor.json` sets floor size, room counts, and how many torches there are and how far apart).
- `data/town/places.json`: the places listed on the town menu, in order, each with its icon, plus the picture on the right. A place with a `scene` opens it.
- `assets/ui/`: menu art: the parchment scroll behind the town menu buttons, the place icons (`icons/`) and the town picture.
- `data/themes/`: which textures the 3D view uses for walls (with weights), floor, ceiling, stairs up, the trapdoor down, and the torch animation and its light. `basement.json` is the demo dungeon.
- `assets/textures/`: texture images.
- `tests/`: headless checks.

## Credits

- Basement wall, stone floor, stairs and trapdoor textures: *Pixel Art Medieval Interiors* by Acasas.
- Wall torch animation: *Old Castle sprite Set* by Acasas.
- Town menu icons and picture (`assets/ui/icons/`, `assets/ui/town_picture.png`): *Strategy Game Icons* pack (author not named in the pack files).
- Scroll menu buttons (`assets/ui/scroll_button.png`): *Pixelart Medieval UI Pack* (author not named in the pack files).
