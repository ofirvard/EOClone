import { createRng, type Rng } from './rng';

export enum Tile {
  Wall = 0,
  Floor = 1,
}

export type Room = { x: number; y: number; w: number; h: number };

export type Dungeon = {
  seed: number;
  width: number;
  height: number;
  tiles: Tile[];
  rooms: Room[];
  start: { x: number; y: number };
};

export type GenOptions = {
  width?: number;
  height?: number;
  roomAttempts?: number;
  extraConnections?: number;
};

/** Anything outside the grid counts as solid wall. */
export function tileAt(d: Dungeon, x: number, y: number): Tile {
  if (x < 0 || y < 0 || x >= d.width || y >= d.height) return Tile.Wall;
  return d.tiles[y * d.width + x];
}

export function isWalkable(d: Dungeon, x: number, y: number): boolean {
  return tileAt(d, x, y) !== Tile.Wall;
}

/**
 * Rooms-and-corridors generator: scatter non-overlapping rooms, link them in a
 * chain with L-shaped corridors, then add a few extra links so the floor has loops.
 */
export function generateDungeon(seed: number, opts: GenOptions = {}): Dungeon {
  const width = opts.width ?? 32;
  const height = opts.height ?? 32;
  const rng = createRng(seed);
  const tiles = new Array<Tile>(width * height).fill(Tile.Wall);
  const set = (x: number, y: number) => {
    if (x > 0 && y > 0 && x < width - 1 && y < height - 1) tiles[y * width + x] = Tile.Floor;
  };

  const rooms: Room[] = [];
  const attempts = opts.roomAttempts ?? 30;
  for (let i = 0; i < attempts; i++) {
    const w = rng.int(2, 5);
    const h = rng.int(2, 5);
    const x = rng.int(1, width - w - 2);
    const y = rng.int(1, height - h - 2);
    const room = { x, y, w, h };
    // Keep at least two wall tiles between rooms so they don't merge into blobs.
    const gap = 2;
    const overlaps = rooms.some(
      (r) => x < r.x + r.w + gap && x + w + gap > r.x && y < r.y + r.h + gap && y + h + gap > r.y,
    );
    if (!overlaps) rooms.push(room);
  }

  for (const r of rooms) {
    for (let y = r.y; y < r.y + r.h; y++) for (let x = r.x; x < r.x + r.w; x++) set(x, y);
  }

  // Chain rooms left-to-right so the corridors don't cross the whole map at random.
  const ordered = [...rooms].sort((a, b) => a.x + a.y * 0.3 - (b.x + b.y * 0.3));
  for (let i = 1; i < ordered.length; i++) carveCorridor(rng, ordered[i - 1], ordered[i], set);

  const extra = opts.extraConnections ?? Math.max(1, Math.floor(rooms.length / 6));
  for (let i = 0; i < extra && rooms.length > 2; i++) {
    carveCorridor(rng, rng.pick(rooms), rng.pick(rooms), set);
  }

  const first = ordered[0] ?? { x: 1, y: 1, w: 1, h: 1 };
  if (!rooms.length) set(1, 1);
  const start = { x: first.x + Math.floor(first.w / 2), y: first.y + Math.floor(first.h / 2) };

  return { seed, width, height, tiles, rooms, start };
}

function carveCorridor(rng: Rng, a: Room, b: Room, set: (x: number, y: number) => void) {
  const ax = rng.int(a.x, a.x + a.w - 1);
  const ay = rng.int(a.y, a.y + a.h - 1);
  const bx = rng.int(b.x, b.x + b.w - 1);
  const by = rng.int(b.y, b.y + b.h - 1);
  const horizontalFirst = rng.next() < 0.5;
  const cornerX = horizontalFirst ? bx : ax;
  const cornerY = horizontalFirst ? ay : by;
  line(ax, ay, cornerX, cornerY, set);
  line(cornerX, cornerY, bx, by, set);
}

function line(x0: number, y0: number, x1: number, y1: number, set: (x: number, y: number) => void) {
  const sx = Math.sign(x1 - x0);
  const sy = Math.sign(y1 - y0);
  let x = x0;
  let y = y0;
  set(x, y);
  while (x !== x1 || y !== y1) {
    if (x !== x1) x += sx;
    else y += sy;
    set(x, y);
  }
}
