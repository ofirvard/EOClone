import { isWalkable, type Dungeon } from './dungeon';

/** 0 = north, 1 = east, 2 = south, 3 = west. North is -y. */
export type Facing = 0 | 1 | 2 | 3;

export const FACING_NAMES = ['North', 'East', 'South', 'West'] as const;
const DX = [0, 1, 0, -1];
const DY = [-1, 0, 1, 0];

export type Player = { x: number; y: number; facing: Facing };

export type Move = 'forward' | 'back' | 'left' | 'right' | 'turnLeft' | 'turnRight';

export function forwardVec(f: Facing) {
  return { x: DX[f], y: DY[f] };
}

export function rightVec(f: Facing) {
  const r = ((f + 1) % 4) as Facing;
  return { x: DX[r], y: DY[r] };
}

/** Grid cell that sits `depth` steps ahead and `lateral` steps to the right. */
export function relativeCell(p: Player, depth: number, lateral: number) {
  const f = forwardVec(p.facing);
  const r = rightVec(p.facing);
  return { x: p.x + f.x * depth + r.x * lateral, y: p.y + f.y * depth + r.y * lateral };
}

/** Applies a move. Returns false when the party bumps into a wall. */
export function applyMove(d: Dungeon, p: Player, move: Move): boolean {
  if (move === 'turnLeft') {
    p.facing = ((p.facing + 3) % 4) as Facing;
    return true;
  }
  if (move === 'turnRight') {
    p.facing = ((p.facing + 1) % 4) as Facing;
    return true;
  }
  const step = { forward: [1, 0], back: [-1, 0], left: [0, -1], right: [0, 1] }[move];
  const target = relativeCell(p, step[0], step[1]);
  if (!isWalkable(d, target.x, target.y)) return false;
  p.x = target.x;
  p.y = target.y;
  return true;
}
