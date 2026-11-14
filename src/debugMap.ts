import { tileAt, Tile, type Dungeon } from './dungeon';
import type { Player } from './player';

/**
 * Developer-only top-down map. The real game map is drawn by the player;
 * this exists so we can check generation and movement while prototyping.
 */
export function drawDebugMap(
  ctx: CanvasRenderingContext2D,
  size: number,
  d: Dungeon,
  p: Player,
  explored: Set<number>,
  revealAll: boolean,
) {
  const cell = size / Math.max(d.width, d.height);
  ctx.fillStyle = '#EDE3CC';
  ctx.fillRect(0, 0, size, size);

  for (let y = 0; y < d.height; y++) {
    for (let x = 0; x < d.width; x++) {
      const known = revealAll || explored.has(y * d.width + x);
      if (!known) continue;
      ctx.fillStyle = tileAt(d, x, y) === Tile.Wall ? '#2B2420' : '#DCCBA5';
      ctx.fillRect(x * cell, y * cell, cell + 0.5, cell + 0.5);
    }
  }

  ctx.strokeStyle = 'rgba(43,36,32,0.12)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  for (let i = 0; i <= d.width; i++) {
    ctx.moveTo(i * cell, 0);
    ctx.lineTo(i * cell, d.height * cell);
  }
  for (let i = 0; i <= d.height; i++) {
    ctx.moveTo(0, i * cell);
    ctx.lineTo(d.width * cell, i * cell);
  }
  ctx.stroke();

  // Party arrow.
  const px = (p.x + 0.5) * cell;
  const py = (p.y + 0.5) * cell;
  ctx.save();
  ctx.translate(px, py);
  ctx.rotate((p.facing * Math.PI) / 2);
  ctx.fillStyle = '#B5462E';
  ctx.beginPath();
  ctx.moveTo(0, -cell * 0.45);
  ctx.lineTo(cell * 0.38, cell * 0.38);
  ctx.lineTo(-cell * 0.38, cell * 0.38);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

/** Marks the party's tile and its eight neighbours as explored. */
export function markExplored(d: Dungeon, p: Player, explored: Set<number>) {
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const x = p.x + dx;
      const y = p.y + dy;
      if (x >= 0 && y >= 0 && x < d.width && y < d.height) explored.add(y * d.width + x);
    }
  }
}
