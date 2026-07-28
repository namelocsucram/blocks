export const SIZE = 8;
export const MAX_HEAT = 24;
export const GOLD_CHANCE = 0.08;

export const SHAPES = [
  [[0, 0]],
  [[0, 0], [0, 1]],
  [[0, 0], [1, 0]],
  [[0, 0], [0, 1], [0, 2]],
  [[0, 0], [1, 0], [2, 0]],
  [[0, 0], [0, 1], [0, 2], [0, 3]],
  [[0, 0], [1, 0], [2, 0], [3, 0]],
  [[0, 0], [0, 1], [1, 0], [1, 1]],
  [[0, 0], [0, 1], [0, 2], [1, 0]],
  [[0, 0], [0, 1], [0, 2], [1, 2]],
  [[1, 0], [1, 1], [1, 2], [0, 0]],
  [[1, 0], [1, 1], [1, 2], [0, 2]],
  [[0, 0], [1, 0], [1, 1], [2, 1]],
  [[0, 1], [1, 0], [1, 1], [2, 0]],
  [[0, 0], [0, 1], [0, 2], [1, 1]],
  [[0, 1], [1, 0], [1, 1], [1, 2]],
  [[0, 0], [0, 1], [1, 0], [1, 1], [2, 0], [2, 1]],
];

export const SIMPLE_SHAPES = SHAPES.filter((shape) => shape.length <= 3);
export const COMPLEX_SHAPES = SHAPES.filter((shape) => shape.length >= 4);

export function emptyGrid() {
  return Array.from({ length: SIZE }, () => Array(SIZE).fill(null));
}

export function canPlace(grid, shape, r0, c0) {
  for (const [dr, dc] of shape) {
    const r = r0 + dr;
    const c = c0 + dc;
    if (r < 0 || r >= SIZE || c < 0 || c >= SIZE) return false;
    if (grid[r][c]) return false;
  }
  return true;
}

export function anyPlacement(grid, shape) {
  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      if (canPlace(grid, shape, r, c)) return true;
    }
  }
  return false;
}

export function pickShape(difficultyLevel, random = Math.random) {
  const complexChance = 0.22 + 0.5 * difficultyLevel;
  const pool = random() < complexChance ? COMPLEX_SHAPES : SIMPLE_SHAPES;
  return pool[Math.floor(random() * pool.length)];
}

export function drawPiece(grid, difficultyLevel, id, random = Math.random) {
  let shape = pickShape(difficultyLevel, random);
  let tries = 0;
  while (!anyPlacement(grid, shape) && tries < 6) {
    shape = pickShape(difficultyLevel, random);
    tries++;
  }
  if (!anyPlacement(grid, shape)) shape = [[0, 0]];
  const gold = random() < GOLD_CHANCE;
  const colorIdx = Math.floor(random() * 7);
  return { id, shape, gold, colorIdx, bomb: false };
}

export function bombPiece(id) {
  return { id, shape: [[0, 0]], gold: false, colorIdx: 0, bomb: true };
}

export function placePiece(grid, piece, r0, c0) {
  if (!canPlace(grid, piece.shape, r0, c0)) return null;
  const nextGrid = grid.map((row) => row.slice());
  piece.shape.forEach(([dr, dc]) => {
    nextGrid[r0 + dr][c0 + dc] = { colorIdx: piece.colorIdx, gold: piece.gold };
  });
  return nextGrid;
}

export function findFullLines(grid) {
  const fullRows = [];
  for (let r = 0; r < SIZE; r++) {
    if (grid[r].every((cell) => cell)) fullRows.push(r);
  }

  const fullCols = [];
  for (let c = 0; c < SIZE; c++) {
    if (grid.every((row) => row[c])) fullCols.push(c);
  }

  return { fullRows, fullCols, linesCleared: fullRows.length + fullCols.length };
}

export function clearingKeysForLines(fullRows, fullCols) {
  const keys = [];
  fullRows.forEach((r) => {
    for (let c = 0; c < SIZE; c++) keys.push(`${r}-${c}`);
  });
  fullCols.forEach((c) => {
    for (let r = 0; r < SIZE; r++) keys.push(`${r}-${c}`);
  });
  return keys;
}

export function clearLines(grid, fullRows, fullCols) {
  const cleared = grid.map((row) => row.slice());
  fullRows.forEach((r) => {
    for (let c = 0; c < SIZE; c++) cleared[r][c] = null;
  });
  fullCols.forEach((c) => {
    for (let r = 0; r < SIZE; r++) cleared[r][c] = null;
  });
  return cleared;
}

export function calculatePlacementOutcome({ grid, piece, heat, combo, score }) {
  const { fullRows, fullCols, linesCleared } = findFullLines(grid);

  let newHeat;
  if (linesCleared > 0) {
    const gain = linesCleared * (linesCleared + 1);
    newHeat = Math.min(heat + gain + (piece.gold ? 3 : 0), MAX_HEAT);
  } else {
    newHeat = Math.max(heat - Math.max(1, Math.round(heat / 12)), 0);
    if (piece.gold) newHeat = Math.min(newHeat + 3, MAX_HEAT);
  }

  const comboNext = linesCleared > 0 ? combo + 1 : 0;
  const comboMultiplier = 1 + Math.min(comboNext, 8) * 0.15;
  const lineBurstMultiplier = linesCleared > 1 ? 1 + (linesCleared - 1) * 0.35 : 1;
  const multiplier = 1 + newHeat * 0.125;
  const placementPts = piece.shape.length * (piece.gold ? 6 : 2);
  const clearPts = linesCleared > 0
    ? Math.round(linesCleared * SIZE * 10 * multiplier * comboMultiplier * lineBurstMultiplier)
    : 0;

  return {
    fullRows,
    fullCols,
    linesCleared,
    newHeat,
    comboNext,
    placementPts,
    clearPts,
    approxScore: score + placementPts + clearPts,
    coinBonus: linesCleared > 0 ? linesCleared + Math.floor(comboNext / 3) : 0,
  };
}
