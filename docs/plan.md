# Plan

_Last updated: 2026-11-15_

The build order for the game, in eight phases. Each phase ends with something playable that tests one part of the [design](design.md). Mapping comes first because it's the core of the game and the riskiest part to get right.

| Phase | Focus | Playable at the end |
|---|---|---|
| 1 | Map making | Explore a floor and chart it by hand |
| 2 | Combat and monsters (basic) | Fights with pre-fight orders while exploring |
| 3 | Loot and crafting | Bring back materials and unlock gear |
| 4 | Map making (advanced) | Survey tools, secrets, map checking that matters |
| 5 | Combat (advanced) | Classes, traits, skill paths, relationships |
| 6 | Biomes | Distinct locations with their own hazards |
| 7 | City building | Grow the guild's town between expeditions |
| 8 | Phone | The full game on Android and iOS, built for touch |

## Phase 1: Map making

Walk a generated floor in first person and draw the map by hand. Built and tested on PC first; phone comes in phase 8, but the map code keeps touch in mind (big targets, pinch zoom).

- [x] Seeded floor generator (rooms and corridors, at most 26 × 26 so columns run A–Z)
- [x] First-person 3D view; W/S move, Q/E strafe, A/D turn, hold to repeat
- [x] Footsteps fill in on the map
- [x] Walls drawn dot to dot on cell edges, with trace, erase and undo
- [x] Zoom and pan (wheel, pinch, buttons, drag)
- [x] True layout view that marks wrong walls
- [ ] Map icons: stairs, treasure, trap, camp, gather point, enemy, note (defined in a data file)
- [x] Stairs on each floor: stairs up set into a wall beside the start, a trapdoor down in another random room (scenery only so far)
- [x] Trapdoor takes you down a floor (asks first); a delve is 3 floors, then back to town
- [ ] Each floor keeps its own map, and stairs up take you back up
- [ ] Basic accuracy score when you leave a floor
- [ ] Save and load a run (seed plus your map)

**Done when:** you can chart a few floors on PC, and the score says how good your map is.

## Phase 2: Combat and monsters (basic)

Encounters while exploring, settled by orders you give before the fight.

- A small party with fixed roles (no classes yet), no row
- Enemies defined in data files, placed by the generator, some seen roaming
- Pre-fight screen: see the enemies, pick orders (focus a target, big skill, defend, flee)
- The fight resolves on its own and shows what happened
- HP, fatigue and supplies that carry through a run, so going deeper is a risk
- Return to town to heal; a wiped party loses the run's map
- Marked enemies on the map tell you what you'll face

**Done when:** a run is a tense trip down and back, and orders matter.

## Phase 3: Loot and crafting

A reason to explore every corner and come back.

- Treasure chests and gathering spots placed by the generator
- Materials from monsters and gathering
- Shop where selling materials unlocks new gear (Etrian style, no recipe menus)
- Weapons, armour and consumables in data files
- Contracts from the guild: map a floor, find a route, gather something
- Map turn-in pays based on accuracy

**Done when:** the core loop (contract, prepare, expedition, return) works end to end.

## Phase 4: Map making (advanced)

Mapping gets deeper and starts to change how runs play.

- Edge-based generator: thin walls between open cells, doors and one-way doors
- Locked and breakable doors and chests
- Hand-made room templates and set pieces mixed into generation
- Survey tools you upgrade: lantern range, compass, rope
- Ping items that briefly reveal secrets
- Breakable walls that open shortcuts and change the map
- Notes that change play: the party avoids marked traps, rests at marked camps
- Wrong maps hurt: penalties, or danger for the next party that uses them
- Map layers (walls, notes) and a floor-notes list
- Camp where you can heal (randomly found and also you can make)
- Traps (damage, move, teleport, status effects)

**Done when:** a good map is clearly worth more than a rough one, in pay and in play.

## Phase 5: Combat (advanced)

Heroes become people you care about.

- Hiring from a roster; classes with stats and starting traits
- Skill paths chosen at key levels (e.g. ice or fire mage)
- Skills that change what you can reach on the map (freeze water, burn vines)
- Traits gained from events on runs
- Relationships between heroes that unlock pair bonuses
- Injuries and permadeath rules (open question in the design)

**Done when:** losing or swapping a veteran is a real decision.

## Phase 6: Biomes

Different places to chart, each with its own look and rules.

- Location framework: tiles, enemies, materials and hazards per biome, all in data
- Ice cave: slippery floors that slide the party until it hits a wall
- Desert: quicksand that drops the party to the floor below
- More biomes as the framework allows
- Shifting zones that change between runs (maybe)

**Done when:** at least three biomes play and map differently.

## Phase 7: City building

The guild's home town grows with your success. Still to design. A first town menu already exists: Delve, Smith, Inn, Tavern, Shop, Alchemist and Guild hall, listed on the left; only Delve works so far.

- Spend income on buildings that unlock services (shop tiers, inn, training, cartographers' hall)
- Town upgrades feed back into expeditions: better gear, more heroes, better survey tools
- Ties to the contract board and story, if there is one

**Done when:** to be decided once the earlier phases are in.

## Phase 8: Phone

Bring the full game to Android and iOS, with controls and layout made for touch.

- Phone layout: view on top, party bar, small map, tool row (see the UI mockups in the design)
- Touch controls: on-screen movement pad, full-screen map mode with an icon picker
- Drawing tuned for fingers: dot snapping range, trace, pinch zoom and two-finger pan on real devices
- Portrait and landscape, different screen sizes and notches
- Performance on mid-range phones (3D view, map drawing)
- Android and iOS export (iOS needs a Mac with Xcode), then store builds

**Done when:** a full run plays well on a phone, start to finish.
