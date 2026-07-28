import test from "node:test";
import assert from "node:assert/strict";
import {
  daysBetween,
  generateDailyGoals,
  initializeSaveState,
  normalizeSave,
  todayStr,
} from "../blocks/stoke_files/stoke-save.mjs";

const TODAY = "Mon Jul 27 2026";
const YESTERDAY = "Sun Jul 26 2026";
const OLD_DAY = "Fri Jul 24 2026";

function fixedRandom() {
  return 0.2;
}

test("todayStr and daysBetween use calendar-day save strings", () => {
  assert.equal(todayStr(new Date("2026-07-27T12:00:00")), TODAY);
  assert.equal(daysBetween(YESTERDAY, TODAY), 1);
  assert.equal(daysBetween(OLD_DAY, TODAY), 3);
});

test("normalizeSave migrates old muted saves before defaults hide the field", () => {
  const save = normalizeSave({ muted: true });

  assert.equal(save.sfxMuted, true);
  assert.equal(save.musicMuted, true);
});

test("normalizeSave preserves split mute settings when already present", () => {
  const save = normalizeSave({ muted: true, sfxMuted: false, musicMuted: true });

  assert.equal(save.sfxMuted, false);
  assert.equal(save.musicMuted, true);
});

test("initializeSaveState increments streak after one missed midnight", () => {
  const initialized = initializeSaveState({
    streak: 6,
    lastPlayDate: YESTERDAY,
    goalsDate: TODAY,
    dailyGoals: [{ id: "kept", type: "lines", target: 8, progress: 1 }],
  }, { today: TODAY, random: fixedRandom, now: () => 123 });

  assert.equal(initialized.streak, 7);
  assert.equal(initialized.freezeAvailable, true);
  assert.equal(initialized.initialHeat, 5);
  assert.equal(initialized.persisted.lastPlayDate, TODAY);
});

test("initializeSaveState consumes freeze instead of resetting a broken streak", () => {
  const initialized = initializeSaveState({
    streak: 9,
    lastPlayDate: OLD_DAY,
    freezeAvailable: true,
  }, { today: TODAY, random: fixedRandom, now: () => 123 });

  assert.equal(initialized.streak, 9);
  assert.equal(initialized.freezeAvailable, false);
});

test("initializeSaveState resets a broken streak without freeze", () => {
  const initialized = initializeSaveState({
    streak: 9,
    lastPlayDate: OLD_DAY,
    freezeAvailable: false,
  }, { today: TODAY, random: fixedRandom, now: () => 123 });

  assert.equal(initialized.streak, 1);
  assert.equal(initialized.freezeAvailable, false);
});

test("initializeSaveState refreshes stale daily goals", () => {
  const initialized = initializeSaveState({
    goalsDate: YESTERDAY,
    dailyGoals: [{ id: "old", type: "score", target: 500, progress: 500 }],
  }, { today: TODAY, random: fixedRandom, now: () => 123 });

  assert.equal(initialized.goalsDate, TODAY);
  assert.equal(initialized.dailyGoals.length, 3);
  assert.notEqual(initialized.dailyGoals[0].id, "old");
});

test("generateDailyGoals returns claimable goal records", () => {
  const goals = generateDailyGoals({ random: fixedRandom, now: () => 456 });

  assert.equal(goals.length, 3);
  assert.equal(goals[0].progress, 0);
  assert.equal(goals[0].claimed, false);
  assert.equal(typeof goals[0].label, "string");
  assert.ok(goals[0].id.endsWith("-456"));
});
