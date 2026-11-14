import { generateDungeon, type Dungeon } from './dungeon';
import { applyMove, FACING_NAMES, type Move, type Player } from './player';
import { randomSeed } from './rng';
import { drawView } from './view';
import { drawDebugMap, markExplored } from './debugMap';

const viewCanvas = document.querySelector<HTMLCanvasElement>('#view')!;
const mapCanvas = document.querySelector<HTMLCanvasElement>('#map')!;
const mapPanel = document.querySelector<HTMLElement>('.map-panel')!;
const statusEl = document.querySelector<HTMLElement>('#status')!;
const revealBox = document.querySelector<HTMLInputElement>('#reveal')!;
const viewCtx = viewCanvas.getContext('2d')!;
const mapCtx = mapCanvas.getContext('2d')!;

let dungeon: Dungeon;
let player: Player;
let explored = new Set<number>();
let bumpTimer: number | undefined;

function seedFromUrl(): number | null {
  const raw = new URLSearchParams(location.search).get('seed');
  const n = raw === null ? NaN : Number(raw);
  return Number.isFinite(n) ? n : null;
}

function newDungeon(seed: number) {
  dungeon = generateDungeon(seed);
  player = { x: dungeon.start.x, y: dungeon.start.y, facing: 0 };
  explored = new Set();
  markExplored(dungeon, player, explored);
  const url = new URL(location.href);
  url.searchParams.set('seed', String(seed));
  history.replaceState(null, '', url);
  render();
}

/** Match the canvas backing store to its on-screen size for crisp lines. */
function fitCanvas(canvas: HTMLCanvasElement, ctx: CanvasRenderingContext2D) {
  const dpr = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  const w = Math.max(1, Math.round(rect.width * dpr));
  const h = Math.max(1, Math.round(rect.height * dpr));
  if (canvas.width !== w || canvas.height !== h) {
    canvas.width = w;
    canvas.height = h;
  }
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  return { w, h };
}

function render() {
  const v = fitCanvas(viewCanvas, viewCtx);
  drawView(viewCtx, v.w, v.h, dungeon, player);

  if (!mapPanel.classList.contains('hidden')) {
    const m = fitCanvas(mapCanvas, mapCtx);
    drawDebugMap(mapCtx, Math.min(m.w, m.h), dungeon, player, explored, revealBox.checked);
  }

  statusEl.textContent = `Seed ${dungeon.seed} · (${player.x}, ${player.y}) · Facing ${FACING_NAMES[player.facing]}`;
}

function move(m: Move) {
  const ok = applyMove(dungeon, player, m);
  if (!ok) {
    viewCanvas.classList.add('bump');
    window.clearTimeout(bumpTimer);
    bumpTimer = window.setTimeout(() => viewCanvas.classList.remove('bump'), 140);
    navigator.vibrate?.(20);
    return;
  }
  markExplored(dungeon, player, explored);
  render();
}

const KEYS: Record<string, Move> = {
  KeyW: 'forward',
  ArrowUp: 'forward',
  KeyS: 'back',
  ArrowDown: 'back',
  KeyA: 'left',
  KeyD: 'right',
  KeyQ: 'turnLeft',
  ArrowLeft: 'turnLeft',
  KeyE: 'turnRight',
  ArrowRight: 'turnRight',
};

window.addEventListener('keydown', (e) => {
  if (e.target instanceof HTMLInputElement) return;
  const m = KEYS[e.code];
  if (m) {
    e.preventDefault();
    move(m);
  } else if (e.code === 'KeyM') {
    mapPanel.classList.toggle('hidden');
    render();
  } else if (e.code === 'KeyN') {
    newDungeon(randomSeed());
  }
});

document.querySelectorAll<HTMLButtonElement>('[data-move]').forEach((btn) => {
  btn.addEventListener('click', () => move(btn.dataset.move as Move));
});
document.querySelector('#new-dungeon')!.addEventListener('click', () => newDungeon(randomSeed()));
revealBox.addEventListener('change', render);
window.addEventListener('resize', render);

newDungeon(seedFromUrl() ?? randomSeed());
