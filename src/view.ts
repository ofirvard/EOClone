import { tileAt, Tile, type Dungeon } from './dungeon';
import { relativeCell, type Player } from './player';

const MAX_DEPTH = 6;
const NEAR = 0.12; // clip plane so walls beside the party don't blow up to infinity
// The party stands near the back of its tile, so the wall straight ahead doesn't fill the screen.
const CAMERA_BACK = 0.4;

type RGB = [number, number, number];
const FRONT: RGB = [128, 118, 102];
const SIDE: RGB = [96, 89, 78];
const CEILING: RGB = [34, 36, 41];
const FLOOR: RGB = [62, 58, 52];

function shade(c: RGB, z: number): string {
  const k = 1 / (1 + 0.32 * Math.max(0, z));
  return `rgb(${Math.round(c[0] * k)},${Math.round(c[1] * k)},${Math.round(c[2] * k)})`;
}

/**
 * First-person grid view, drawn back to front like a classic dungeon crawler.
 * Camera space: x to the right, z forward; each cell is 1×1 and walls are 1 tall.
 */
export function drawView(ctx: CanvasRenderingContext2D, w: number, h: number, d: Dungeon, p: Player) {
  const cx = w / 2;
  const cy = h / 2;
  const focal = Math.min(w * 0.42, h * 0.6);
  const sx = (x: number, z: number) => cx + (x / z) * focal;
  const sy = (y: number, z: number) => cy - (y / z) * focal;

  // Ceiling and floor bands, darker toward the horizon.
  for (let i = 0; i < 24; i++) {
    const t = i / 24;
    const z = 0.5 / (1 - t + 1e-3);
    ctx.fillStyle = shade(CEILING, z * 0.6);
    ctx.fillRect(0, (t * h) / 2, w, h / 2 / 24 + 1);
    ctx.fillStyle = shade(FLOOR, z * 0.6);
    ctx.fillRect(0, h - ((t + 1 / 24) * h) / 2, w, h / 2 / 24 + 1);
  }

  // Floor grid lines so each step reads as one tile.
  ctx.strokeStyle = 'rgba(0,0,0,0.35)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  for (let k = 0; k <= MAX_DEPTH; k++) {
    const z = k + 0.5 + CAMERA_BACK;
    ctx.moveTo(0, sy(-0.5, z));
    ctx.lineTo(w, sy(-0.5, z));
  }
  for (let lx = -MAX_DEPTH - 0.5; lx <= MAX_DEPTH + 0.5; lx += 1) {
    ctx.moveTo(sx(lx, NEAR * 4), sy(-0.5, NEAR * 4));
    ctx.lineTo(sx(lx, MAX_DEPTH + 0.5 + CAMERA_BACK), sy(-0.5, MAX_DEPTH + 0.5 + CAMERA_BACK));
  }
  ctx.stroke();

  const quad = (pts: [number, number][], fill: string) => {
    ctx.beginPath();
    ctx.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
    ctx.strokeStyle = 'rgba(20,18,15,0.9)';
    ctx.lineWidth = 1.5;
    ctx.stroke();
  };

  for (let depth = MAX_DEPTH; depth >= 0; depth--) {
    const reach = depth + 2;
    // Outer columns first so inner (nearer to the centre line) walls paint over them.
    const laterals: number[] = [];
    for (let l = reach; l >= 1; l--) laterals.push(-l, l);
    laterals.push(0);

    for (const l of laterals) {
      const cell = relativeCell(p, depth, l);
      if (tileAt(d, cell.x, cell.y) !== Tile.Wall) continue;

      // Side face: the face that points toward the centre line.
      if (l !== 0) {
        const x = l > 0 ? l - 0.5 : l + 0.5;
        const z0 = Math.max(NEAR, depth - 0.5 + CAMERA_BACK);
        const z1 = depth + 0.5 + CAMERA_BACK;
        if (z1 > NEAR) {
          quad(
            [
              [sx(x, z0), sy(0.5, z0)],
              [sx(x, z1), sy(0.5, z1)],
              [sx(x, z1), sy(-0.5, z1)],
              [sx(x, z0), sy(-0.5, z0)],
            ],
            shade(SIDE, (z0 + z1) / 2),
          );
        }
      }

      // Front face, facing the party.
      if (depth >= 1) {
        const z = depth - 0.5 + CAMERA_BACK;
        const x0 = sx(l - 0.5, z);
        const x1 = sx(l + 0.5, z);
        const y0 = sy(0.5, z);
        const y1 = sy(-0.5, z);
        quad(
          [
            [x0, y0],
            [x1, y0],
            [x1, y1],
            [x0, y1],
          ],
          shade(FRONT, z),
        );
        drawBricks(ctx, x0, y0, x1 - x0, y1 - y0, z);
      }
    }
  }
}

function drawBricks(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, z: number) {
  if (w < 12) return;
  ctx.strokeStyle = `rgba(30,27,23,${0.55 / (1 + 0.2 * z)})`;
  ctx.lineWidth = 1;
  ctx.beginPath();
  const rows = 4;
  for (let r = 1; r < rows; r++) {
    const ry = y + (h * r) / rows;
    ctx.moveTo(x, ry);
    ctx.lineTo(x + w, ry);
  }
  for (let r = 0; r < rows; r++) {
    const offset = r % 2 === 0 ? 0.25 : 0.5;
    for (let c = offset; c < 1; c += 0.5) {
      const bx = x + w * c;
      ctx.moveTo(bx, y + (h * r) / rows);
      ctx.lineTo(bx, y + (h * (r + 1)) / rows);
    }
  }
  ctx.stroke();
}
