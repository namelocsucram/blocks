import test from "node:test";
import assert from "node:assert/strict";
import {
  SIZE,
  MAX_HEAT,
  emptyGrid,
  canPlace,
  anyPlacement,
  placePiece,
  findFullLines,
  clearLines,
  clearingKeysForLines,
  calculatePlacementOutcome,
  drawPiece,
} from "../blocks/stoke_files/stoke-core.mjs";

function filledCell(colorIdx = 0) {
  return { colorIdx, gold: false };
}

test("canPlace rejects out-of-bounds and occupied placements", () => {
  const grid = emptyGrid();
  grid[0][0] = filledCell();

  assert.equal(canPlace(grid, [[0, 0]], 0, 0), false);
  assert.equal(canPlace(grid, [[0, 0]], -1, 0), false);
  assert.equal(canPlace(grid, [[0, 0], [0, 1]], 0, SIZE - 1), false);
  assert.equal(canPlace(grid, [[0, 0], [0, 1]], 1, 1), true);
});

test("anyPlacement detects a blocked board", () => {
  const grid = Array.from({ length: SIZE }, () => Array.from({ length: SIZE }, () => filledCell()));

  assert.equal(anyPlacement(grid, [[0, 0]]), false);
});

test("drawPiece falls back to a single block when sampled shapes cannot fit", () => {
  const grid = Array.from({ length: SIZE }, () => Array.from({ length: SIZE }, () => filledCell()));
  grid[SIZE - 1][SIZE - 1] = null;
  const random = () => 0.99;

  const piece = drawPiece(grid, 1, 42, random);

  assert.deepEqual(piece.shape, [[0, 0]]);
  assert.equal(piece.id, 42);
});

test("placing a piece returns a new grid and leaves the original untouched", () => {
  const grid = emptyGrid();
  const piece = { shape: [[0, 0], [0, 1]], colorIdx: 3, gold: false };

  const nextGrid = placePiece(grid, piece, 2, 2);

  assert.equal(grid[2][2], null);
  assert.deepEqual(nextGrid[2][2], { colorIdx: 3, gold: false });
  assert.deepEqual(nextGrid[2][3], { colorIdx: 3, gold: false });
});

test("findFullLines detects completed rows and columns", () => {
  const grid = emptyGrid();
  for (let c = 0; c < SIZE; c++) grid[0][c] = filledCell();
  for (let r = 0; r < SIZE; r++) grid[r][2] = filledCell();

  const result = findFullLines(grid);

  assert.deepEqual(result.fullRows, [0]);
  assert.deepEqual(result.fullCols, [2]);
  assert.equal(result.linesCleared, 2);
});

test("clearLines removes all cells in completed rows and columns", () => {
  const grid = emptyGrid();
  for (let c = 0; c < SIZE; c++) grid[0][c] = filledCell();
  for (let r = 0; r < SIZE; r++) grid[r][2] = filledCell();

  const cleared = clearLines(grid, [0], [2]);

  assert.equal(cleared[0].every((cell) => cell === null), true);
  assert.equal(cleared.every((row) => row[2] === null), true);
});

test("clearingKeysForLines creates row and column animation keys", () => {
  const keys = clearingKeysForLines([1], [3]);

  assert.equal(keys.includes("1-0"), true);
  assert.equal(keys.includes("1-7"), true);
  assert.equal(keys.includes("0-3"), true);
  assert.equal(keys.includes("7-3"), true);
  assert.equal(keys.length, SIZE * 2);
});

test("calculatePlacementOutcome scores combo and burst clears", () => {
  const grid = emptyGrid();
  for (let c = 0; c < SIZE; c++) grid[0][c] = filledCell();
  const piece = { shape: [[0, 0]], gold: false };

  const outcome = calculatePlacementOutcome({
    grid,
    piece,
    heat: 4,
    combo: 2,
    score: 100,
  });

  assert.equal(outcome.linesCleared, 1);
  assert.equal(outcome.comboNext, 3);
  assert.equal(outcome.newHeat, 6);
  assert.equal(outcome.placementPts, 2);
  assert.equal(outcome.clearPts, 203);
  assert.equal(outcome.approxScore, 305);
  assert.equal(outcome.coinBonus, 2);
});

test("calculatePlacementOutcome decays heat and resets combo when no line clears", () => {
  const grid = emptyGrid();
  const piece = { shape: [[0, 0], [0, 1], [1, 0]], gold: false };

  const outcome = calculatePlacementOutcome({
    grid,
    piece,
    heat: 12,
    combo: 4,
    score: 500,
  });

  assert.equal(outcome.linesCleared, 0);
  assert.equal(outcome.comboNext, 0);
  assert.equal(outcome.newHeat, 11);
  assert.equal(outcome.placementPts, 6);
  assert.equal(outcome.clearPts, 0);
  assert.equal(outcome.approxScore, 506);
});

test("gold pieces add bonus placement points and heat without exceeding max", () => {
  const grid = emptyGrid();
  const piece = { shape: [[0, 0], [0, 1]], gold: true };

  const outcome = calculatePlacementOutcome({
    grid,
    piece,
    heat: MAX_HEAT - 1,
    combo: 0,
    score: 0,
  });

  assert.equal(outcome.newHeat, MAX_HEAT);
  assert.equal(outcome.placementPts, 12);
});
