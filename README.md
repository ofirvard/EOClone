# EOClone

A cartography-focused dungeon crawler inspired by Etrian Odyssey. You run a cartographers' guild, hire a party of adventurers, and draw maps by hand while exploring randomly generated dungeons. Combat is light: you give orders at the start of each fight and it resolves on its own.

Targets phone and PC.

## Docs

- [Design doc](docs/design.md)

## Status

Prototype, step 1: seeded floor generation with a top-down debug view. Engine: Godot 4.7.

## Running

Open the folder in Godot 4.7 (Import → select `project.godot`) and press F5. The map on the left fills in only the cells you've stepped on; the 3D window on the right looks from the blue marker. Turn on **True layout** (or press M) to see the whole generated floor.

- Type a seed and press Go to view that floor. Space generates a new floor; ←/→ step to the previous or next seed.
- W/S move, Q/E strafe, A/D turn. Hold a key to keep going, one step at a time.
- **Wall tool** (2, the default): walls are bold lines on the edges between cells. Press and drag: a trace follows the pointer's path from the nearest grid dot (cell corner), and a wall is placed only when the line reaches another dot in the same row or column. Keep dragging to chain walls. A stroke whose first wall is already drawn erases instead. You can't draw a wall across a step you've walked.
- **Move tool** (1): tap or click a cell you've walked on to jump back there; tap your own cell to turn. Drag to pan the map.
- **Zoom:** mouse wheel, trackpad or two-finger pinch, or the −, + and Fit buttons. Right- or middle-drag pans (two fingers on touch). When zoomed in, the map follows you as you walk.
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
- `data/`: content and tuning (`data/generation/floor.json` sets floor size, room counts).
- `tests/`: headless checks.
