# EOClone

A cartography-focused dungeon crawler inspired by Etrian Odyssey. The player runs a cartographers' guild, explores randomly generated grid dungeons in first person, and draws the map by hand. Combat is light: orders at the start of each fight, then it resolves on its own.

The full design is in `docs/design.md`. Read it before proposing features or code.

## Decisions so far

- Engine: Godot. GDScript is the recommended language (keeps a browser build possible).
- Targets: installed apps on phone (Android, iOS) and PC; Steam later.
- Each dungeon floor is a 2D grid, shown in a 3D first-person view.
- The player draws the map by hand; there is no auto-map in the game.
- Dungeons are generated from a seed and stay the same for that seed.

## How to work in this repo

- Talk through design and tech choices with the user before writing or committing code. Don't commit or push unless the user asks.
- When a new game idea is agreed, add it to `docs/design.md`.
- Keep game rules (grid, movement, generation, map checking) separate from rendering and UI, so the rules can be tested on their own.
- Keep game content (items, enemies, room templates) in data files, not hard-coded.
