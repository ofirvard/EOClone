# EOClone

A cartography-focused dungeon crawler inspired by Etrian Odyssey. You run a cartographers' guild, hire a party of adventurers, and draw maps by hand while exploring randomly generated dungeons. Combat is light: you give orders at the start of each fight and it resolves on its own.

Targets phone and PC.

## Docs

- [Design doc](docs/design.md)

## Prototype

The first prototype is a generated dungeon you walk through in first person.

- **Stack:** TypeScript, Vite, plain Canvas 2D. No game engine.
- **Controls:** W/S move, A/D step sideways, Q/E turn, M toggles the debug map, N makes a new dungeon. On a phone, use the on-screen buttons.
- **Seeds:** the URL carries `?seed=1234`, so the same link always gives the same dungeon.
- **Debug map:** an automatic top-down map for testing. In the game the player draws the map.

### Run it

```bash
npm install
npm run dev      # dev server, also reachable from your phone on the same network
npm run build    # type-check and build to dist/
```

### Code layout

| File | What it does |
| --- | --- |
| `src/rng.ts` | Seeded random numbers |
| `src/dungeon.ts` | Rooms-and-corridors generator |
| `src/player.ts` | Party position, facing, movement |
| `src/view.ts` | First-person renderer |
| `src/debugMap.ts` | Debug top-down map |
| `src/main.ts` | Input, layout, render calls |
