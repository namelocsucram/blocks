export const DEFAULT_SAVE = {
  best: 0,
  sfxMuted: false,
  musicMuted: false,
  streak: 1,
  lastPlayDate: null,
  freezeAvailable: false,
  coins: 0,
  dailyGoals: [],
  goalsDate: null,
};

export const GOAL_TEMPLATES = [
  { type: "lines", label: (t) => `Clear ${t} lines`, targets: [8, 15, 25], reward: 25 },
  { type: "score", label: (t) => `Score ${t} points`, targets: [500, 1200, 2500], reward: 30 },
  { type: "jackpot", label: (t) => `Hit ${t} Jackpot${t > 1 ? "s" : ""}`, targets: [1, 2], reward: 50 },
  { type: "heat", label: (t) => `Reach heat x${(1 + t * 0.125).toFixed(1)}`, targets: [12, 18, 24], reward: 20 },
  { type: "wildgem", label: (t) => `Place ${t} Wild Gem${t > 1 ? "s" : ""}`, targets: [2, 4], reward: 20 },
  { type: "pieces", label: (t) => `Place ${t} pieces`, targets: [30, 60], reward: 15 },
];

export function todayStr(date = new Date()) {
  return date.toDateString();
}

export function daysBetween(a, b) {
  return Math.round((new Date(b) - new Date(a)) / 86400000);
}

export function generateDailyGoals({ random = Math.random, now = Date.now } = {}) {
  const shuffled = [...GOAL_TEMPLATES].sort(() => random() - 0.5).slice(0, 3);
  return shuffled.map((tmpl, i) => {
    const target = tmpl.targets[Math.floor(random() * tmpl.targets.length)];
    return {
      id: `${tmpl.type}-${i}-${now()}`,
      type: tmpl.type,
      target,
      progress: 0,
      reward: tmpl.reward,
      claimed: false,
      label: tmpl.label(target),
    };
  });
}

export function normalizeSave(rawSave = {}) {
  const raw = rawSave && typeof rawSave === "object" ? rawSave : {};
  const normalized = { ...DEFAULT_SAVE, ...raw };

  if (raw.muted !== undefined) {
    if (raw.sfxMuted === undefined) normalized.sfxMuted = !!raw.muted;
    if (raw.musicMuted === undefined) normalized.musicMuted = !!raw.muted;
  }

  normalized.best = Number.isFinite(normalized.best) ? normalized.best : 0;
  normalized.streak = Number.isFinite(normalized.streak) && normalized.streak > 0 ? normalized.streak : 1;
  normalized.coins = Number.isFinite(normalized.coins) && normalized.coins > 0 ? normalized.coins : 0;
  normalized.dailyGoals = Array.isArray(normalized.dailyGoals) ? normalized.dailyGoals : [];
  normalized.freezeAvailable = !!normalized.freezeAvailable;
  normalized.sfxMuted = !!normalized.sfxMuted;
  normalized.musicMuted = !!normalized.musicMuted;

  return normalized;
}

export function initializeSaveState(rawSave = {}, {
  today = todayStr(),
  random = Math.random,
  now = Date.now,
} = {}) {
  const save = normalizeSave(rawSave);
  let streak = save.streak;
  let freezeAvailable = save.freezeAvailable;

  if (save.lastPlayDate && save.lastPlayDate !== today) {
    const gap = daysBetween(save.lastPlayDate, today);
    if (gap === 1) {
      streak += 1;
    } else if (gap > 1) {
      if (freezeAvailable) {
        freezeAvailable = false;
      } else {
        streak = 1;
      }
    }
  }

  if (streak > 0 && streak % 7 === 0) freezeAvailable = true;

  let dailyGoals = save.dailyGoals.length ? save.dailyGoals : generateDailyGoals({ random, now });
  let goalsDate = save.goalsDate;
  if (goalsDate !== today) {
    dailyGoals = generateDailyGoals({ random, now });
    goalsDate = today;
  }

  const state = {
    best: save.best,
    sfxMuted: save.sfxMuted,
    musicMuted: save.musicMuted,
    streak,
    lastPlayDate: today,
    freezeAvailable,
    coins: save.coins,
    dailyGoals,
    goalsDate,
  };

  return {
    ...state,
    initialHeat: Math.min(streak - 1, 5),
    persisted: state,
  };
}
