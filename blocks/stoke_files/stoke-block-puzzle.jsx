import { useState, useEffect, useRef, useCallback } from "react";
import { Flame, RotateCcw, Volume2, VolumeX, Snowflake, Sparkles, Bomb } from "lucide-react";

const SIZE = 8;
const MAX_HEAT = 24;
const GOLD_CHANCE = 0.08;
const INTERSTITIAL_EVERY = 3;
const REROLL_COST = 20;
const ERASER_COST = 15;

const SHAPES = [
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
const SIMPLE_SHAPES = SHAPES.filter((s) => s.length <= 3);
const COMPLEX_SHAPES = SHAPES.filter((s) => s.length >= 4);

const PALETTE = [
  [255, 59, 92], [255, 166, 48], [255, 224, 76], [46, 213, 115],
  [59, 130, 246], [168, 85, 247], [244, 114, 182],
];
const GOLD = [255, 214, 90];

function paletteRgb(idx) { return PALETTE[idx % PALETTE.length]; }
function toRgb(c) { return `rgb(${c[0]}, ${c[1]}, ${c[2]})`; }
function lighten(c, amt) { return c.map((v) => Math.round(v + (255 - v) * amt)); }
function gemGradient(c) { return `linear-gradient(135deg, ${toRgb(lighten(c, 0.45))}, ${toRgb(c)})`; }

function shapeDims(shape) {
  let w = 0, h = 0;
  shape.forEach(([r, c]) => { w = Math.max(w, c + 1); h = Math.max(h, r + 1); });
  return { w, h };
}
function emptyGrid() { return Array.from({ length: SIZE }, () => Array(SIZE).fill(null)); }
function canPlace(grid, shape, r0, c0) {
  for (const [dr, dc] of shape) {
    const r = r0 + dr, c = c0 + dc;
    if (r < 0 || r >= SIZE || c < 0 || c >= SIZE) return false;
    if (grid[r][c]) return false;
  }
  return true;
}
function anyPlacement(grid, shape) {
  for (let r = 0; r < SIZE; r++) for (let c = 0; c < SIZE; c++) if (canPlace(grid, shape, r, c)) return true;
  return false;
}

// --- dynamic difficulty: bias toward simple shapes early, and never hand out
// a piece that literally cannot fit anywhere on the current board.
function pickShape(difficultyLevel) {
  const complexChance = 0.22 + 0.5 * difficultyLevel;
  const pool = Math.random() < complexChance ? COMPLEX_SHAPES : SIMPLE_SHAPES;
  return pool[Math.floor(Math.random() * pool.length)];
}
function drawPiece(grid, difficultyLevel, id) {
  let shape = pickShape(difficultyLevel);
  let tries = 0;
  while (!anyPlacement(grid, shape) && tries < 6) { shape = pickShape(difficultyLevel); tries++; }
  if (!anyPlacement(grid, shape)) shape = [[0, 0]];
  const gold = Math.random() < GOLD_CHANCE;
  const colorIdx = Math.floor(Math.random() * PALETTE.length);
  return { id, shape, gold, colorIdx, bomb: false };
}
function bombPiece(id) { return { id, shape: [[0, 0]], gold: false, colorIdx: 0, bomb: true }; }
function todayStr() { return new Date().toDateString(); }
function daysBetween(a, b) { return Math.round((new Date(b) - new Date(a)) / 86400000); }

function useDeviceLayout() {
  const readViewport = () => ({
    width: window.visualViewport?.width || window.innerWidth || 390,
    height: window.visualViewport?.height || window.innerHeight || 780,
  });
  const [viewport, setViewport] = useState(readViewport);

  useEffect(() => {
    const update = () => setViewport(readViewport());
    window.addEventListener("resize", update);
    window.visualViewport?.addEventListener("resize", update);
    window.visualViewport?.addEventListener("scroll", update);
    update();
    return () => {
      window.removeEventListener("resize", update);
      window.visualViewport?.removeEventListener("resize", update);
      window.visualViewport?.removeEventListener("scroll", update);
    };
  }, []);

  const isTablet = viewport.width >= 700;
  const isWide = viewport.width >= 860 && viewport.width > viewport.height;
  const isCompact = viewport.width < 390 || viewport.height < 700;
  const verticalReserve = isCompact ? 460 : isTablet ? 520 : 480;
  const heightBound = Math.max(260, viewport.height - verticalReserve);
  const boardSize = Math.min(
    isTablet ? 560 : 460,
    viewport.width - (isCompact ? 20 : 32),
    isWide ? viewport.height * 0.7 : heightBound
  );

  return {
    wrap: {
      maxWidth: isWide ? 980 : isTablet ? 620 : 460,
      padding: isCompact
        ? "max(8px, env(safe-area-inset-top)) 10px max(8px, env(safe-area-inset-bottom))"
        : "max(14px, env(safe-area-inset-top)) 16px max(18px, env(safe-area-inset-bottom))",
    },
    title: { fontSize: isCompact ? 28 : isTablet ? 38 : 32 },
    tagline: { display: isCompact ? "none" : "block" },
    adBanner: { height: 50, marginBottom: isCompact ? 6 : 12 },
    statsRow: { gap: isCompact ? 6 : 8, marginBottom: isCompact ? 6 : 14 },
    statBox: { padding: isCompact ? "6px 8px" : "8px 10px" },
    statValue: { fontSize: isCompact ? 16 : 18 },
    grid: { width: boardSize, maxWidth: "100%", margin: "0 auto" },
    tray: { marginTop: isCompact ? 8 : 18, padding: isCompact ? "8px 8px" : "16px 10px", minHeight: isCompact ? 48 : 70 },
    trayCell: { size: isCompact ? 12 : 14, gap: isCompact ? 1.5 : 2 },
    boosterBar: {
      gap: isCompact ? 6 : 8,
      marginTop: isCompact ? 8 : 10,
      marginBottom: isCompact ? 72 : 56,
      position: "static",
      paddingBottom: 0,
    },
    boosterBtn: { padding: isCompact ? "7px 5px" : "9px 6px", fontSize: isCompact ? 10.5 : 11.5 },
    overlayCard: { width: isCompact ? "92%" : "84%", padding: isCompact ? "20px 18px" : "26px 28px" },
  };
}

// --- daily objectives: 3 rotating micro-goals, refreshed once per calendar day.
// Deliberately skill-agnostic accumulation goals (not authored puzzle boards) so
// they can't be "too hard" the way a hand-built level can.
const GOAL_TEMPLATES = [
  { type: "lines", label: (t) => `Clear ${t} lines`, targets: [8, 15, 25], reward: 25 },
  { type: "score", label: (t) => `Score ${t} points`, targets: [500, 1200, 2500], reward: 30 },
  { type: "jackpot", label: (t) => `Hit ${t} Jackpot${t > 1 ? "s" : ""}`, targets: [1, 2], reward: 50 },
  { type: "heat", label: (t) => `Reach heat ×${(1 + t * 0.125).toFixed(1)}`, targets: [12, 18, 24], reward: 20 },
  { type: "wildgem", label: (t) => `Place ${t} Wild Gem${t > 1 ? "s" : ""}`, targets: [2, 4], reward: 20 },
  { type: "pieces", label: (t) => `Place ${t} pieces`, targets: [30, 60], reward: 15 },
];
function generateDailyGoals() {
  const shuffled = [...GOAL_TEMPLATES].sort(() => Math.random() - 0.5).slice(0, 3);
  return shuffled.map((tmpl, i) => {
    const target = tmpl.targets[Math.floor(Math.random() * tmpl.targets.length)];
    return { id: `${tmpl.type}-${i}-${Date.now()}`, type: tmpl.type, target, progress: 0, reward: tmpl.reward, claimed: false, label: tmpl.label(target) };
  });
}

let idCounter = 1;

// --- Native monetization bridge ---------------------------------------------
// AdMob App ID (goes in Info.plist as GADApplicationIdentifier later, not here):
// ca-app-pub-7262617456411456~5433417356
// Ad unit IDs below — replace remaining XXXX placeholders once created in AdMob.
const ADMOB_BANNER_ID = "ca-app-pub-7262617456411456/9508273591";
const ADMOB_INTERSTITIAL_ID = "ca-app-pub-7262617456411456/6307395181";
const ADMOB_REWARDED_ID = "ca-app-pub-7262617456411456/7812048544";
// Matches the products/packages set up in RevenueCat: coins_100/350/800/2000.
const COIN_PACKAGES = [
  { id: "coins_100", coins: 100, price: "$0.99" },
  { id: "coins_350", coins: 350, price: "$2.99" },
  { id: "coins_800", coins: 800, price: "$4.99" },
  { id: "coins_2000", coins: 2000, price: "$9.99" },
];

function getCapPlugins() {
  return (typeof window !== "undefined" && window.Capacitor && window.Capacitor.Plugins) || null;
}
function isNative() {
  return !!(typeof window !== "undefined" && window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform());
}

function useAudio(sfxMuted, musicMuted, heatPct) {
  const ctxRef = useRef(null);
  const sfxMutedRef = useRef(sfxMuted);
  const musicMutedRef = useRef(musicMuted);
  const heatRef = useRef(heatPct);
  useEffect(() => { sfxMutedRef.current = sfxMuted; }, [sfxMuted]);
  useEffect(() => { musicMutedRef.current = musicMuted; }, [musicMuted]);
  useEffect(() => { heatRef.current = heatPct; }, [heatPct]);
  const musicTimerRef = useRef(null);
  const musicKeepAliveRef = useRef(null);
  const musicStartedRef = useRef(false);
  const musicBusRef = useRef(null);

  const ensure = () => {
    if (!ctxRef.current) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (AC) ctxRef.current = new AC();
      if (ctxRef.current) {
        ctxRef.current.onstatechange = () => {
          if (ctxRef.current?.state === "suspended" && musicStartedRef.current) {
            ctxRef.current.resume().catch(() => {});
          }
        };
      }
    }
    return ctxRef.current;
  };
  // Raw tone generator — no mute check here, callers decide which channel gates it.
  const tone = (freq, dur = 0.12, type = "sine", gain = 0.1, delay = 0) => {
    const ctx = ensure();
    if (!ctx) return;
    if (ctx.state === "suspended") ctx.resume();
    const t0 = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    g.gain.setValueAtTime(0, t0);
    g.gain.linearRampToValueAtTime(gain, t0 + 0.008);
    g.gain.exponentialRampToValueAtTime(0.001, t0 + dur);
    osc.connect(g); g.connect(ctx.destination);
    osc.start(t0); osc.stop(t0 + dur + 0.02);
  };
  const beep = (...args) => { if (!sfxMutedRef.current) tone(...args); };
  const ensureMusicBus = () => {
    const ctx = ensure();
    if (!ctx) return null;
    if (!musicBusRef.current) {
      const comp = ctx.createDynamicsCompressor();
      const lowpass = ctx.createBiquadFilter();
      const delay = ctx.createDelay(0.28);
      const feedback = ctx.createGain();
      const wet = ctx.createGain();
      const master = ctx.createGain();
      comp.threshold.value = -26;
      comp.knee.value = 20;
      comp.ratio.value = 6;
      comp.attack.value = 0.01;
      comp.release.value = 0.18;
      lowpass.type = "lowpass";
      lowpass.frequency.value = 6400;
      lowpass.Q.value = 0.42;
      delay.delayTime.value = 0.24;
      feedback.gain.value = 0.16;
      wet.gain.value = 0.18;
      master.gain.value = 0.34;
      comp.connect(lowpass);
      lowpass.connect(master);
      lowpass.connect(delay);
      delay.connect(feedback);
      feedback.connect(delay);
      delay.connect(wet);
      wet.connect(master);
      master.connect(ctx.destination);
      musicBusRef.current = { input: comp, master };
    }
    return musicBusRef.current.input;
  };
  const musicTone = (freq, dur = 0.22, type = "triangle", gain = 0.018, delay = 0, cutoff = null, detune = 0) => {
    const ctx = ensure();
    const bus = ensureMusicBus();
    if (!ctx || !bus) return;
    if (ctx.state === "suspended") ctx.resume();
    const t0 = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    const filter = ctx.createBiquadFilter();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    if (detune) osc.detune.setValueAtTime(detune, t0);
    filter.type = "lowpass";
    filter.frequency.setValueAtTime(cutoff ?? Math.min(9000, Math.max(180, freq * 6)), t0);
    filter.Q.value = 0.35;
    g.gain.setValueAtTime(0, t0);
    g.gain.linearRampToValueAtTime(gain, t0 + 0.02);
    g.gain.exponentialRampToValueAtTime(0.001, t0 + dur);
    osc.connect(filter);
    filter.connect(g);
    g.connect(bus);
    osc.start(t0);
    osc.stop(t0 + dur + 0.03);
  };

  // Procedural loop with a warmer mix and more structure:
  //  1. A small echo gives the theme space without washing out the rhythm.
  //  2. The loop follows a fixed 16-step hook so it reads like a melody instead
  //     of a pile of independent beeps.
  //  3. Heat still brightens the arrangement, but the core phrase stays clear.
  const PROGRESSION = [
    { chord: [261.6, 329.6, 392.0], bass: 130.8 }, // C
    { chord: [392.0, 493.9, 587.3], bass: 196.0 }, // G
    { chord: [220.0, 261.6, 329.6], bass: 110.0 }, // Am
    { chord: [349.2, 440.0, 523.3], bass: 174.6 }, // F
  ];
  const BRIDGE = [523.3, 587.3, 659.3, 784.0, 659.3, 587.3, 523.3, 392.0];
  const HOOK = [0, 4, 7, 9, 7, 4, 2, 4, 0, 4, 7, 9, 12, 9, 7, 4];
  const REPLY = [12, 9, 7, 4, 7, 9, 12, 14, 12, 9, 7, 4, 2, 4, 7, 9];
  const BASS_PATTERN = [0, 7, 0, 5, 0, 7, 12, 7, 0, 7, 0, 5, 0, 9, 7, 12];
  const COUNTER_PATTERN = [12, 12, 0, 7, 0, 9, 0, 7, 12, 12, 0, 7, 0, 9, 0, 7];
  const jitter = (v, amt) => v * (1 - amt + Math.random() * amt * 2);
  const heatGain = (base, heat, scale = 1) => base + Math.min(heat / 100, 1) * scale;

  function startMusic() {
    if (musicStartedRef.current) return;
    musicStartedRef.current = true;
    let step = 0;
    if (!musicMutedRef.current) {
      [261.6, 329.6, 392.0, 523.3, 659.3, 783.99].forEach((f, i) => musicTone(f, 0.18 + i * 0.02, i % 2 === 0 ? "triangle" : "square", 0.032, i * 0.06, 5200));
      musicTone(130.8, 0.34, "sine", 0.09, 0.02, 240);
      musicTone(784.0, 0.2, "square", 0.022, 0.18, 7600);
    }
    const loop = () => {
      if (!musicMutedRef.current) {
        const h = heatRef.current || 0; // 0-100
        const intensity = Math.min(1, h / 100);
        const stepInBar = step % 16;
        const phrase = Math.floor(step / 16) % PROGRESSION.length;
        const chord = PROGRESSION[phrase];
        const nextChord = PROGRESSION[(phrase + 1) % PROGRESSION.length];
        const isBridge = step > 0 && step % 32 === 31;
        const swing = stepInBar % 2 === 1 ? 0.018 : 0;
        if (isBridge) {
          BRIDGE.forEach((f, i) => musicTone(jitter(f, 0.006), 0.22 + i * 0.016, i % 2 ? "triangle" : "sine", heatGain(0.01, h, 0.008), i * 0.08, 3600 + intensity * 1800));
          musicTone(chord.bass / 2, 0.18, "sine", 0.04 + intensity * 0.014, 0, 220);
          musicTone(nextChord.chord[2] * 2, 0.16, "triangle", 0.008 + intensity * 0.003, 0.26, 6200);
          musicTone(nextChord.chord[0] * 2, 0.14, "sine", 0.007 + intensity * 0.003, 0.5, 5600);
        } else {
          const kick = stepInBar === 0 || stepInBar === 8;
          const snare = stepInBar === 4 || stepInBar === 12;
          const hat = stepInBar % 2 === 1;
          const clap = stepInBar === 4 || stepInBar === 12;
          const lift = stepInBar === 15;
          const chordHit = stepInBar === 0 || stepInBar === 8 || lift;
          const bassFreq = chord.bass * Math.pow(2, BASS_PATTERN[stepInBar] / 12);
          musicTone(jitter(bassFreq, 0.003), 0.34, "triangle", heatGain(0.018, h, 0.01), 0, 180 + intensity * 100);
          if (kick) {
            musicTone(chord.bass / 2, 0.1, "sine", 0.05 + intensity * 0.016, 0, 150);
            musicTone(64, 0.05, "square", 0.016 + intensity * 0.006, 0.01, 280);
          }
          if (snare) {
            musicTone(210, 0.07, "square", 0.016 + intensity * 0.006, 0, 700);
            musicTone(2600, 0.05, "square", 0.01 + intensity * 0.003, 0.015, 8800);
          }
          if (clap) {
            musicTone(1800, 0.04, "square", 0.006 + intensity * 0.002, 0.02, 7600);
            musicTone(4200, 0.03, "square", 0.0045 + intensity * 0.0015, 0.03, 9000);
          }
          if (hat) {
            if (stepInBar >= 8) musicTone(7900, 0.016, "square", 0.0045 + intensity * 0.0018, 0.02, 9200);
          }
          if (chordHit) {
            chord.chord.forEach((f, i) => musicTone(jitter(f * (i === 0 ? 1 : 2), 0.0025), 0.18 + i * 0.02, i === 0 ? "triangle" : "sine", 0.007 + intensity * 0.003, i * 0.03, 4400 + intensity * 1400));
          }
          const motif = stepInBar < 8 ? HOOK : REPLY;
          const melodyFreq = chord.chord[0] * Math.pow(2, motif[stepInBar] / 12) * (stepInBar >= 8 ? 2 : 1);
          musicTone(melodyFreq, 0.16 + (stepInBar % 4 === 3 ? 0.04 : 0), stepInBar % 4 === 0 ? "square" : "triangle", 0.011 + intensity * 0.004, 0.18 + swing, 4200 + intensity * 1800, stepInBar % 4 === 1 ? -4 : 0);
          if (stepInBar % 4 === 2) musicTone(chord.chord[1] * (stepInBar >= 8 ? 2 : 1), 0.12, "triangle", 0.006 + intensity * 0.002, 0.28 + swing, 3800 + intensity * 900);
          if (stepInBar % 4 === 3 && h > 20) {
            const counter = chord.chord[0] * Math.pow(2, COUNTER_PATTERN[stepInBar] / 12);
            musicTone(counter, 0.1, "sine", 0.006 + intensity * 0.002, 0.34 + swing, 3400 + intensity * 700);
          }
          if (lift) {
            musicTone(nextChord.chord[0] * 2, 0.14, "triangle", 0.007 + intensity * 0.0025, 0.04, 5200);
            musicTone(nextChord.chord[2] * 2, 0.12, "sine", 0.0065 + intensity * 0.0025, 0.18, 6400);
          }
          if (h > 35 && stepInBar === 7) musicTone(chord.chord[1] * 2, 0.14, "triangle", 0.006 + intensity * 0.0025, 0.58, 5000);
          if (h > 70 && stepInBar === 15) musicTone(chord.chord[0] * 4, 0.16, "sine", 0.007 + intensity * 0.0025, 0.74, 6800);
        }
      }
      step++;
      const heatSpeedup = Math.min(240, (heatRef.current || 0) * 2.5);
      const groove = step % 8 === 6 ? 18 : 0;
      musicTimerRef.current = setTimeout(loop, Math.max(360, 780 - heatSpeedup - groove));
    };
    loop();
    if (musicKeepAliveRef.current) clearInterval(musicKeepAliveRef.current);
    musicKeepAliveRef.current = setInterval(() => {
      if (!musicStartedRef.current || musicMutedRef.current) return;
      const ctx = ensure();
      if (ctx?.state === "suspended") ctx.resume().catch(() => {});
      musicTone(392.0, 0.16, "triangle", 0.009, 0, 2400);
      musicTone(523.3, 0.14, "sine", 0.0075, 0.08, 3200);
    }, 2200);
  }
  function stopMusic() {
    musicStartedRef.current = false;
    if (musicTimerRef.current) clearTimeout(musicTimerRef.current);
    if (musicKeepAliveRef.current) clearInterval(musicKeepAliveRef.current);
  }

  return {
    startMusic, stopMusic,
    place: () => beep(300, 0.05, "square", 0.05),
    gold: () => { beep(700, 0.09, "triangle", 0.09, 0); beep(1000, 0.13, "triangle", 0.09, 0.06); },
    clear: (lines, heat) => {
      const base = 420 + heat * 9;
      for (let i = 0; i < Math.min(lines, 4); i++) beep(base + i * 95, 0.17, "triangle", 0.09, i * 0.05);
    },
    jackpot: () => {
      // Slot-machine style payout: reel ticks, coin drops, then a bright fanfare.
      [880, 988, 1175, 1318, 1568, 1760, 1976, 2093].forEach((f, i) => {
        beep(f, 0.045, "square", 0.055, i * 0.055);
      });
      [2637, 2349, 2093, 2637, 3136, 2794, 3136, 3520].forEach((f, i) => {
        beep(f, 0.08, "triangle", 0.07, 0.42 + i * 0.075);
      });
      [523, 659, 784, 1047, 1318].forEach((f) => {
        beep(f, 0.55, "sine", 0.045, 1.06);
      });
      beep(4186, 0.18, "triangle", 0.055, 1.1);
      beep(3520, 0.2, "triangle", 0.05, 1.26);
    },
    booster: () => { beep(880, 0.08, "sine", 0.08, 0); beep(1100, 0.08, "sine", 0.08, 0.05); },
    invalid: () => beep(140, 0.08, "square", 0.05),
    gameOver: () => { beep(300, 0.2, "sawtooth", 0.07, 0); beep(220, 0.22, "sawtooth", 0.07, 0.14); beep(140, 0.3, "sawtooth", 0.07, 0.3); },
    rescue: () => { beep(500, 0.1, "sine", 0.09, 0); beep(650, 0.1, "sine", 0.09, 0.08); beep(850, 0.16, "sine", 0.1, 0.16); },
  };
}

function shareJackpotCard(score, multiplier) {
  const canvas = document.createElement("canvas");
  canvas.width = 600; canvas.height = 800;
  const ctx = canvas.getContext("2d");
  const grad = ctx.createLinearGradient(0, 0, 0, 800);
  grad.addColorStop(0, "#241238"); grad.addColorStop(1, "#0A0512");
  ctx.fillStyle = grad; ctx.fillRect(0, 0, 600, 800);
  ctx.strokeStyle = "#FFD65A"; ctx.lineWidth = 8; ctx.strokeRect(20, 20, 560, 760);
  ctx.textAlign = "center";
  ctx.fillStyle = "#FFD65A";
  ctx.font = "800 66px Georgia";
  ctx.fillText("JACKPOT!", 300, 220);
  ctx.font = "600 26px Georgia";
  ctx.fillStyle = "#C9B8E8";
  ctx.fillText("STOKE", 300, 268);
  ctx.font = "700 100px Georgia";
  ctx.fillStyle = "#FFFFFF";
  ctx.fillText(String(score), 300, 430);
  ctx.font = "400 22px Georgia";
  ctx.fillStyle = "#C9B8E8";
  ctx.fillText("SCORE", 300, 468);
  ctx.font = "500 26px Georgia";
  ctx.fillStyle = "#FFD65A";
  ctx.fillText(`Heat multiplier x${multiplier}`, 300, 540);
  ctx.font = "400 18px Georgia";
  ctx.fillStyle = "#8A7CA8";
  ctx.fillText(new Date().toLocaleDateString(), 300, 740);

  canvas.toBlob(async (blob) => {
    if (!blob) return;
    const file = new File([blob], "stoke-jackpot.png", { type: "image/png" });
    if (navigator.share && navigator.canShare && navigator.canShare({ files: [file] })) {
      try { await navigator.share({ files: [file], title: "STOKE Jackpot!", text: `I just hit a JACKPOT in STOKE — score ${score}` }); return; } catch (e) {}
    }
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = "stoke-jackpot.png";
    document.body.appendChild(a); a.click(); a.remove();
    URL.revokeObjectURL(url);
  }, "image/png");
}

export default function Stoke() {
  const [grid, setGrid] = useState(emptyGrid);
  const [tray, setTray] = useState(() => [drawPiece(emptyGrid(), 0, idCounter++), drawPiece(emptyGrid(), 0, idCounter++), drawPiece(emptyGrid(), 0, idCounter++)]);
  const [score, setScore] = useState(0);
  const [best, setBest] = useState(0);
  const [heat, setHeat] = useState(0);
  const [gameOver, setGameOver] = useState(false);
  const [drag, setDrag] = useState(null);
  const [loaded, setLoaded] = useState(false);
  const [clearingKeys, setClearingKeys] = useState([]);
  const [pulse, setPulse] = useState(0);
  const [sfxMuted, setSfxMuted] = useState(false);
  const [musicMuted, setMusicMuted] = useState(false);
  const [streak, setStreak] = useState(1);
  const [freezeAvailable, setFreezeAvailable] = useState(false);
  const [toast, setToast] = useState(null);
  const [rescueUsed, setRescueUsed] = useState(false);
  const [rescuing, setRescuing] = useState(false);
  const [bombArmed, setBombArmed] = useState(false);
  const [jackpotFlash, setJackpotFlash] = useState(false);
  const [jackpotBonus, setJackpotBonus] = useState(null);
  const [shareReady, setShareReady] = useState(false);
  const [coins, setCoins] = useState(0);
  const [eraseMode, setEraseMode] = useState(false);
  const [gamesSinceInterstitial, setGamesSinceInterstitial] = useState(0);
  const [showInterstitial, setShowInterstitial] = useState(false);
  const [interstitialReady, setInterstitialReady] = useState(false);
  const [dailyGoals, setDailyGoals] = useState([]);
  const [goalsDate, setGoalsDate] = useState(null);
  const [showGoals, setShowGoals] = useState(false);
  const [showCoinPicker, setShowCoinPicker] = useState(false);
  const [purchasing, setPurchasing] = useState(null);
  const [liveOfferings, setLiveOfferings] = useState(null);
  const [combo, setCombo] = useState(0);
  const [comboPop, setComboPop] = useState(null);
  const [shake, setShake] = useState(false);

  const gridRef = useRef(null);
  const cellSizeRef = useRef(40);
  const heatPct = Math.round((heat / MAX_HEAT) * 100);
  const sound = useAudio(sfxMuted, musicMuted, heatPct);
  const deviceLayout = useDeviceLayout();

  useEffect(() => {
    const unlockMusic = () => sound.startMusic();
    const opts = { once: true, passive: true };
    window.addEventListener("pointerdown", unlockMusic, opts);
    window.addEventListener("touchstart", unlockMusic, opts);
    window.addEventListener("keydown", unlockMusic, opts);
    return () => {
      window.removeEventListener("pointerdown", unlockMusic);
      window.removeEventListener("touchstart", unlockMusic);
      window.removeEventListener("keydown", unlockMusic);
    };
  }, [sound]);

  useEffect(() => {
    if (!loaded || musicMuted) return;
    const t = setTimeout(() => sound.startMusic(), 120);
    return () => clearTimeout(t);
  }, [loaded, musicMuted, sound]);

  useEffect(() => {
    (async () => {
      let save = { best: 0, sfxMuted: false, musicMuted: false, streak: 1, lastPlayDate: null, freezeAvailable: false, coins: 0, dailyGoals: [], goalsDate: null };
      try {
        const res = await window.storage.get("stoke-save");
        if (res && res.value) save = { ...save, ...JSON.parse(res.value) };
      } catch (e) {}

      // Migrate old single "muted" saves so returning players don't get reset to sound-on.
      if (save.muted !== undefined && save.sfxMuted === undefined) {
        save.sfxMuted = save.muted;
        save.musicMuted = save.muted;
      }

      let newStreak = save.streak || 1;
      let newFreeze = !!save.freezeAvailable;
      const today = todayStr();
      if (save.lastPlayDate && save.lastPlayDate !== today) {
        const gap = daysBetween(save.lastPlayDate, today);
        if (gap === 1) newStreak = (save.streak || 1) + 1;
        else if (gap > 1) { if (newFreeze) newFreeze = false; else newStreak = 1; }
      }
      if (newStreak > 0 && newStreak % 7 === 0) newFreeze = true;

      let newGoals = save.dailyGoals && save.dailyGoals.length ? save.dailyGoals : generateDailyGoals();
      let newGoalsDate = save.goalsDate;
      if (newGoalsDate !== today) {
        newGoals = generateDailyGoals();
        newGoalsDate = today;
      }

      setBest(save.best || 0);
      setSfxMuted(!!save.sfxMuted);
      setMusicMuted(!!save.musicMuted);
      setStreak(newStreak);
      setFreezeAvailable(newFreeze);
      setCoins(save.coins || 0);
      setHeat(Math.min(newStreak - 1, 5));
      setDailyGoals(newGoals);
      setGoalsDate(newGoalsDate);

      window.storage.set("stoke-save", JSON.stringify({
        best: save.best || 0, sfxMuted: !!save.sfxMuted, musicMuted: !!save.musicMuted, streak: newStreak, lastPlayDate: today, freezeAvailable: newFreeze, coins: save.coins || 0, dailyGoals: newGoals, goalsDate: newGoalsDate,
      })).catch(() => {});
      setLoaded(true);
    })();
  }, []);

  useEffect(() => {
    if (!loaded) return;
    const newBest = Math.max(best, score);
    if (newBest !== best) setBest(newBest);
    window.storage.set("stoke-save", JSON.stringify({
      best: newBest, sfxMuted, musicMuted, streak, lastPlayDate: todayStr(), freezeAvailable, coins, dailyGoals, goalsDate,
    })).catch(() => {});
  }, [score, sfxMuted, musicMuted, loaded, coins, dailyGoals]);

  useEffect(() => {
    if (!showInterstitial) return;
    const plugins = getCapPlugins();
    if (isNative() && plugins && plugins.AdMob) {
      plugins.AdMob.showInterstitial()
        .catch(() => {})
        .finally(() => closeInterstitial());
      return;
    }
    setInterstitialReady(false);
    const t = setTimeout(() => setInterstitialReady(true), 2000);
    return () => clearTimeout(t);
  }, [showInterstitial]);

  useEffect(() => {
    if (gameOver || showInterstitial || clearingKeys.length > 0) return;
    const stuck = tray.every((p) => !anyPlacement(grid, p.shape));
    if (stuck && tray.length > 0) {
      sound.gameOver();
      setGamesSinceInterstitial((prev) => {
        const next = prev + 1;
        if (next >= INTERSTITIAL_EVERY) {
          setShowInterstitial(true);
          return 0;
        }
        setGameOver(true);
        return next;
      });
    }
  }, [grid, tray, gameOver, clearingKeys, showInterstitial]);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 1200);
    return () => clearTimeout(t);
  }, [toast]);

  useEffect(() => {
    if (!jackpotFlash) return;
    const t = setTimeout(() => {
      setJackpotFlash(false);
      setJackpotBonus(null);
    }, 1500);
    return () => clearTimeout(t);
  }, [jackpotFlash]);

  useEffect(() => {
    if (!shareReady) return;
    const t = setTimeout(() => setShareReady(false), 6000);
    return () => clearTimeout(t);
  }, [shareReady]);

  useEffect(() => {
    if (!comboPop) return;
    const t = setTimeout(() => setComboPop(null), 900);
    return () => clearTimeout(t);
  }, [comboPop]);

  useEffect(() => {
    if (!shake) return;
    const t = setTimeout(() => setShake(false), 280);
    return () => clearTimeout(t);
  }, [shake]);

  useEffect(() => () => sound.stopMusic(), []);

  // Real ad SDK bootstrap — only runs inside the native Capacitor shell.
  // In browser/testing, this is a no-op and the placeholder banner/mock
  // rescue flow below take over automatically.
  useEffect(() => {
    const plugins = getCapPlugins();
    if (!isNative() || !plugins || !plugins.AdMob) return;
    plugins.AdMob.initialize().then(() => {
      const showNativeBanner = () => {
        plugins.AdMob.showBanner({
          adId: ADMOB_BANNER_ID,
          adSize: "BANNER",
          position: "BOTTOM_CENTER",
        }).catch(() => {});
      };
      requestAnimationFrame(() => setTimeout(showNativeBanner, 50));
      plugins.AdMob.prepareRewardVideoAd({ adId: ADMOB_REWARDED_ID }).catch(() => {});
      plugins.AdMob.prepareInterstitial({ adId: ADMOB_INTERSTITIAL_ID }).catch(() => {});
    }).catch(() => {});
    return () => { plugins.AdMob.removeBanner().catch(() => {}); };
  }, []);

  useEffect(() => {
    const plugins = getCapPlugins();
    if (!isNative() || !plugins || !plugins.Purchases) return;
    plugins.Purchases.configure().catch(() => {});
  }, []);

  const updateCellSize = useCallback(() => {
    if (gridRef.current) cellSizeRef.current = gridRef.current.clientWidth / SIZE;
  }, []);
  useEffect(() => {
    updateCellSize();
    window.addEventListener("resize", updateCellSize);
    return () => window.removeEventListener("resize", updateCellSize);
  }, [updateCellSize]);

  function restart() {
    setGrid(emptyGrid());
    setTray([drawPiece(emptyGrid(), 0, idCounter++), drawPiece(emptyGrid(), 0, idCounter++), drawPiece(emptyGrid(), 0, idCounter++)]);
    setScore(0);
    setHeat(Math.min(streak - 1, 5));
    setGameOver(false);
    setDrag(null);
    setClearingKeys([]);
    setRescueUsed(false);
    setBombArmed(false);
    setEraseMode(false);
    setCombo(0);
    setComboPop(null);
    setJackpotBonus(null);
    setShake(false);
  }

  function closeInterstitial() {
    setShowInterstitial(false);
    setGameOver(true);
  }

  // Shows a real rewarded video via AdMob when running in the native app;
  // falls back to a timed mock so the flow is still testable in a browser.
  function watchAdToContinue() {
    setRescuing(true);
    const grantReward = () => {
      setGrid((g) => {
        const filled = [];
        g.forEach((row, r) => row.forEach((cell, c) => { if (cell) filled.push([r, c]); }));
        for (let i = filled.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [filled[i], filled[j]] = [filled[j], filled[i]];
        }
        const cleared = g.map((row) => row.slice());
        filled.slice(0, 6).forEach(([r, c]) => { cleared[r][c] = null; });
        return cleared;
      });
      setRescueUsed(true);
      setGameOver(false);
      setRescuing(false);
      sound.rescue();
    };

    const plugins = getCapPlugins();
    if (isNative() && plugins && plugins.AdMob) {
      let handled = false;
      const finish = () => { if (!handled) { handled = true; grantReward(); } };
      plugins.AdMob.addListener("onRewardedVideoAdReward", finish);
      plugins.AdMob.showRewardVideoAd().catch(() => {
        // Ad failed to load (no fill, offline, etc.) — don't strand the player.
        setRescuing(false);
        setToast("Ad unavailable — try again shortly");
      });
      return;
    }

    setTimeout(grantReward, 1400);
  }

  function bumpGoal(type, amount, mode = "add") {
    setDailyGoals((prev) => {
      let completed = false;
      const next = prev.map((g) => {
        if (g.type !== type || g.claimed) return g;
        const newProgress = mode === "max" ? Math.max(g.progress, amount) : g.progress + amount;
        const capped = Math.min(newProgress, g.target);
        if (capped >= g.target && g.progress < g.target) completed = true;
        return { ...g, progress: capped };
      });
      if (completed) setToast("Daily objective complete! 🎯");
      return next;
    });
  }

  function claimGoal(id) {
    setDailyGoals((prev) => prev.map((g) => {
      if (g.id !== id || g.claimed || g.progress < g.target) return g;
      setCoins((c) => c + g.reward);
      sound.booster();
      setToast(`+${g.reward} coins claimed!`);
      return { ...g, claimed: true };
    }));
  }

  function difficultyFor(approxScore) { return Math.min(1, approxScore / 4000); }

  function rerollTray() {
    if (coins < REROLL_COST || eraseMode) return;
    setCoins((c) => c - REROLL_COST);
    setTray([
      drawPiece(grid, difficultyFor(score), idCounter++),
      drawPiece(grid, difficultyFor(score), idCounter++),
      drawPiece(grid, difficultyFor(score), idCounter++),
    ]);
    sound.booster();
    setToast("Tray rerolled");
  }

  function toggleEraser() {
    if (eraseMode) { setEraseMode(false); return; }
    if (coins < ERASER_COST) { setToast("Not enough coins"); return; }
    setEraseMode(true);
    setToast("Tap a block to erase it");
  }

  function handleCellClick(r, c) {
    if (!eraseMode) return;
    if (!grid[r][c]) { setEraseMode(false); return; }
    setGrid((g) => {
      const next = g.map((row) => row.slice());
      next[r][c] = null;
      return next;
    });
    setCoins((coinsNow) => coinsNow - ERASER_COST);
    setEraseMode(false);
    sound.booster();
  }

  // Opens the coin-pack picker. When native, fetches live packages/prices from
  // RevenueCat; in browser testing, falls back to the static COIN_PACKAGES list.
  async function openCoinPicker() {
    setShowCoinPicker(true);
    const plugins = getCapPlugins();
    if (isNative() && plugins && plugins.Purchases) {
      try {
        const { offerings } = await plugins.Purchases.getOfferings();
        setLiveOfferings(offerings?.current?.availablePackages || []);
      } catch (e) {
        setLiveOfferings(null);
      }
    }
  }

  // Purchases a specific tier by RevenueCat package identifier (coins_100, etc).
  // Falls back to an instant test grant in browser testing.
  async function buyCoinPack(tier) {
    const plugins = getCapPlugins();
    if (isNative() && plugins && plugins.Purchases) {
      setPurchasing(tier.id);
      try {
        const source = liveOfferings || [];
        const pkg = source.find((p) => p.identifier === tier.id);
        if (!pkg) { setToast("Coin pack unavailable"); setPurchasing(null); return; }
        await plugins.Purchases.purchasePackage({ aPackage: pkg });
        setCoins((c) => c + tier.coins);
        setToast(`+${tier.coins} coins purchased!`);
        setShowCoinPicker(false);
      } catch (e) {
        setToast("Purchase cancelled");
      }
      setPurchasing(null);
      return;
    }
    setCoins((c) => c + tier.coins);
    setToast(`+${tier.coins} coins (test mode)`);
    setShowCoinPicker(false);
  }

  function detonateBomb() {
    const filled = [];
    grid.forEach((row, r) => row.forEach((cell, c) => { if (cell) filled.push(`${r}-${c}`); }));
    const bonus = 300 + filled.length * 15;
    setClearingKeys(filled);
    setScore((s) => s + bonus);
    setCoins((c) => c + 10);
    bumpGoal("jackpot", 1);
    setJackpotBonus(bonus);
    setJackpotFlash(true);
    setShareReady(true);
    setToast(`JACKPOT! +${bonus}`);
    setCombo(0);
    setComboPop({ id: Date.now(), text: `BOARD WIPE +${bonus}` });
    setShake(true);
    sound.jackpot();
    const carryHeat = Math.round(MAX_HEAT / 2);
    setHeat(carryHeat);
    setTimeout(() => {
      setGrid(emptyGrid());
      setClearingKeys([]);
    }, 260);
    setTray((prev) => {
      const remaining = prev.filter((p) => !p.bomb);
      return remaining.length === 0
        ? [drawPiece(emptyGrid(), difficultyFor(score), idCounter++), drawPiece(emptyGrid(), difficultyFor(score), idCounter++), drawPiece(emptyGrid(), difficultyFor(score), idCounter++)]
        : remaining;
    });
    setBombArmed(false);
  }

  function commitPlacement(piece, r0, c0) {
    if (piece.bomb) { detonateBomb(); return; }

    const newGrid = grid.map((row) => row.slice());
    piece.shape.forEach(([dr, dc]) => { newGrid[r0 + dr][c0 + dc] = { colorIdx: piece.colorIdx, gold: piece.gold }; });

    const fullRows = [];
    for (let r = 0; r < SIZE; r++) if (newGrid[r].every((c) => c)) fullRows.push(r);
    const fullCols = [];
    for (let c = 0; c < SIZE; c++) if (newGrid.every((row) => row[c])) fullCols.push(c);
    const linesCleared = fullRows.length + fullCols.length;

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
    const clearPts = linesCleared > 0 ? Math.round(linesCleared * SIZE * 10 * multiplier * comboMultiplier * lineBurstMultiplier) : 0;
    const approxScore = score + placementPts + clearPts;

    setHeat(newHeat);
    if (newHeat > heat) setPulse((p) => p + 1);
    setScore((s) => s + placementPts + clearPts);
    setCombo(comboNext);
    if (linesCleared > 0) {
      const coinBonus = linesCleared + Math.floor(comboNext / 3);
      setCoins((c) => c + coinBonus);
      setComboPop({ id: Date.now(), text: comboNext > 1 ? `${comboNext}x combo +${clearPts}` : `Line clear +${clearPts}` });
      if (linesCleared > 1 || comboNext >= 3) setShake(true);
    }
    bumpGoal("pieces", 1);
    bumpGoal("score", placementPts + clearPts);
    bumpGoal("heat", newHeat, "max");
    if (linesCleared > 0) bumpGoal("lines", linesCleared);
    if (linesCleared > 1) setToast(`${linesCleared} lines! Burst bonus`);
    else if (comboNext >= 3) setToast(`${comboNext}x combo cooking`);
    if (piece.gold) { bumpGoal("wildgem", 1); setToast("Wild Gem! Bonus payout"); sound.gold(); }

    const justHitMax = newHeat >= MAX_HEAT && heat < MAX_HEAT && !bombArmed;
    const diff = difficultyFor(approxScore);

    setTray((prev) => {
      const remaining = prev.filter((p) => p.id !== piece.id);
      let nextTray = remaining.length === 0
        ? [drawPiece(newGrid, diff, idCounter++), drawPiece(newGrid, diff, idCounter++), drawPiece(newGrid, diff, idCounter++)]
        : remaining;
      if (justHitMax) {
        const slot = Math.floor(Math.random() * nextTray.length);
        nextTray = nextTray.map((p, i) => (i === slot ? bombPiece(idCounter++) : p));
      }
      return nextTray;
    });
    if (justHitMax) setBombArmed(true);

    if (linesCleared > 0) {
      const keys = [];
      fullRows.forEach((r) => { for (let c = 0; c < SIZE; c++) keys.push(`${r}-${c}`); });
      fullCols.forEach((c) => { for (let r = 0; r < SIZE; r++) keys.push(`${r}-${c}`); });
      setClearingKeys(keys);
      sound.clear(linesCleared, newHeat);
      setTimeout(() => {
        setGrid((g) => {
          const cleared = g.map((row) => row.slice());
          fullRows.forEach((r) => { for (let c = 0; c < SIZE; c++) cleared[r][c] = null; });
          fullCols.forEach((c) => { for (let r = 0; r < SIZE; r++) cleared[r][c] = null; });
          return cleared;
        });
        setClearingKeys([]);
      }, 220);
      setGrid(newGrid);
    } else {
      setGrid(newGrid);
      if (!piece.gold) sound.place();
    }
  }

  function startDrag(e, piece) {
    if (gameOver || eraseMode) return;
    sound.startMusic();
    e.preventDefault();
    e.currentTarget.setPointerCapture(e.pointerId);
    const dims = shapeDims(piece.shape);
    setDrag({ piece, x: e.clientX, y: e.clientY, dims, pointerType: e.pointerType });
  }
  function moveDrag(e) {
    if (!drag) return;
    e.preventDefault();
    setDrag((d) => (d ? { ...d, x: e.clientX, y: e.clientY } : d));
  }
  function getPreview() {
    if (!drag || !gridRef.current) return null;
    const rect = gridRef.current.getBoundingClientRect();
    const cs = cellSizeRef.current;
    const liftY = drag.pointerType === "touch" ? 70 : 0;
    const localX = drag.x - rect.left;
    const localY = drag.y - rect.top - liftY;
    const centerCol = Math.floor(localX / cs) - Math.floor((drag.dims.w - 1) / 2);
    const centerRow = Math.floor(localY / cs) - Math.floor((drag.dims.h - 1) / 2);
    return { r0: centerRow, c0: centerCol, valid: canPlace(grid, drag.piece.shape, centerRow, centerCol) };
  }
  function endDrag(e) {
    if (!drag) return;
    e.preventDefault();
    const preview = getPreview();
    if (preview && preview.valid) commitPlacement(drag.piece, preview.r0, preview.c0);
    else sound.invalid();
    setDrag(null);
  }

  const preview = getPreview();
  const multiplier = (1 + heat * 0.125).toFixed(2);
  const marqueeSpeed = Math.max(1.1, 3.2 - heatPct / 45);
  const heatMode = heatPct >= 100 ? "JACKPOT READY" : heatPct >= 75 ? "FEVER" : heatPct >= 45 ? "HOT" : "WARM";

  return (
    <div style={{ ...S.wrap, ...deviceLayout.wrap }}>
      <style>{`
        * { box-sizing: border-box; }
        .tray-piece:active { transform: scale(0.93); }
        .grid-cell { transition: background 0.15s ease, box-shadow 0.15s ease; }
        .booster-btn:active { transform: scale(0.95); }
        @keyframes flashClear { 0% { transform: scale(1); filter: brightness(1); } 35% { transform: scale(1.2); filter: brightness(2.6); } 100% { transform: scale(0.1); opacity: 0; filter: brightness(3); } }
        @keyframes heatPulse { 0% { transform: scaleY(1); } 40% { transform: scaleY(1.6); } 100% { transform: scaleY(1); } }
        @keyframes toastIn { 0% { transform: translate(-50%, 8px); opacity: 0; } 15% { transform: translate(-50%, 0); opacity: 1; } 85% { opacity: 1; } 100% { opacity: 0; } }
        @keyframes goldPulse { 0%,100% { box-shadow: 0 0 4px rgba(255,214,90,0.5); } 50% { box-shadow: 0 0 12px rgba(255,214,90,0.95); } }
        @keyframes bombPulse { 0%,100% { filter: hue-rotate(0deg) brightness(1.1); } 50% { filter: hue-rotate(180deg) brightness(1.4); } }
        @keyframes marquee { 0%,100% { box-shadow: 0 0 14px 2px rgba(255,214,90,0.55), inset 0 0 20px rgba(255,214,90,0.12); } 50% { box-shadow: 0 0 22px 4px rgba(255,80,140,0.5), inset 0 0 26px rgba(255,80,140,0.14); } }
        @keyframes jackpotZoom { 0% { transform: translate(-50%,-50%) scale(0.4); opacity: 0; } 20% { transform: translate(-50%,-50%) scale(1.15); opacity: 1; } 35% { transform: translate(-50%,-50%) scale(1); opacity: 1; } 80% { opacity: 1; } 100% { transform: translate(-50%,-50%) scale(1); opacity: 0; } }
        @keyframes comboFloat { 0% { transform: translate(-50%, 12px) scale(0.8); opacity: 0; } 18% { transform: translate(-50%, 0) scale(1.08); opacity: 1; } 100% { transform: translate(-50%, -42px) scale(1); opacity: 0; } }
        @keyframes screenShake { 0%,100% { transform: translate(0,0); } 20% { transform: translate(-4px,2px); } 40% { transform: translate(4px,-2px); } 60% { transform: translate(-3px,-1px); } 80% { transform: translate(3px,1px); } }
      `}</style>

      <div style={S.header}>
        <div style={S.titleRow}>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <Flame size={26} color="#FFD65A" style={{ filter: `drop-shadow(0 0 ${6 + heatPct / 8}px #FFD65A)` }} />
            <h1 style={{ ...S.title, ...deviceLayout.title }}>STOKE</h1>
          </div>
          <div style={{ display: "flex", gap: 6 }}>
            <button style={S.iconBtn} onClick={() => setMusicMuted((m) => !m)} aria-label={musicMuted ? "Unmute music" : "Mute music"} title="Music">
              {musicMuted ? <VolumeX size={16} color="#C9B8E8" /> : <Volume2 size={16} color="#FFD65A" />}
              <span style={S.iconBtnLabel}>music</span>
            </button>
            <button style={S.iconBtn} onClick={() => setSfxMuted((m) => !m)} aria-label={sfxMuted ? "Unmute sound effects" : "Mute sound effects"} title="Sound effects">
              {sfxMuted ? <VolumeX size={16} color="#C9B8E8" /> : <Volume2 size={16} color="#FFD65A" />}
              <span style={S.iconBtnLabel}>sfx</span>
            </button>
          </div>
        </div>
        <div style={S.streakRow}>
          <span style={{ ...S.streakBadge, color: heatPct >= 75 ? "#FF8A3D" : "#FFD65A", borderColor: heatPct >= 75 ? "#9D4A24" : "#4A2E66" }}>{heatMode}</span>
          <span style={S.streakBadge}>Day {streak} streak</span>
          {freezeAvailable && (
            <span style={{ ...S.streakBadge, color: "#8FD3E8", borderColor: "#2E5A66" }}>
              <Snowflake size={11} style={{ marginRight: 3, verticalAlign: -2 }} />freeze ready
            </span>
          )}
          <span style={S.streakBadge}>🪙 {coins}</span>
        </div>
        <p style={{ ...S.tagline, ...deviceLayout.tagline }}>Clear lines to build heat. Max it out for a JACKPOT bomb that clears the board.</p>
      </div>

      <button style={S.goalsToggle} onClick={() => setShowGoals((v) => !v)}>
        <span>🎯 Daily Objectives</span>
        <span style={S.goalsCount}>
          {dailyGoals.filter((g) => g.progress >= g.target && !g.claimed).length > 0
            ? `${dailyGoals.filter((g) => g.progress >= g.target && !g.claimed).length} ready!`
            : `${dailyGoals.filter((g) => g.claimed).length}/${dailyGoals.length}`}
        </span>
      </button>
      {showGoals && (
        <div style={S.goalsPanel}>
          {dailyGoals.map((g) => {
            const done = g.progress >= g.target;
            return (
              <div key={g.id} style={S.goalRow}>
                <div style={{ flex: 1 }}>
                  <div style={S.goalLabel}>{g.label}</div>
                  <div style={S.goalTrack}>
                    <div style={{ ...S.goalFill, width: `${Math.min(100, (g.progress / g.target) * 100)}%` }} />
                  </div>
                  <div style={S.goalProgress}>{Math.min(g.progress, g.target)} / {g.target}</div>
                </div>
                {g.claimed ? (
                  <span style={S.goalClaimed}>✓ claimed</span>
                ) : (
                  <button style={{ ...S.goalClaimBtn, opacity: done ? 1 : 0.4 }} onClick={() => claimGoal(g.id)} disabled={!done}>
                    {done ? `Claim +${g.reward}🪙` : `${g.reward}🪙`}
                  </button>
                )}
              </div>
            );
          })}
        </div>
      )}

      <div style={{ ...S.statsRow, ...deviceLayout.statsRow }}>
        <div style={{ ...S.statBox, ...deviceLayout.statBox, flex: 1.1, borderColor: "#FFD65A", background: "linear-gradient(180deg, rgba(49, 28, 74, 0.96), rgba(30, 16, 48, 0.98))", boxShadow: "0 0 0 1px rgba(255, 214, 90, 0.16), 0 10px 22px rgba(0, 0, 0, 0.18)" }}><div style={{ ...S.statLabel, color: "#FFF3C4" }}>Score</div><div style={{ ...S.statValue, ...deviceLayout.statValue, fontSize: deviceLayout.statValue.fontSize + 6, color: "#FFFFFF", lineHeight: 1 }}>{score}</div></div>
        <div style={{ ...S.statBox, ...deviceLayout.statBox, flex: 1.1, borderColor: "#9D4A24", background: "linear-gradient(180deg, rgba(39, 24, 58, 0.96), rgba(23, 14, 36, 0.98))" }}><div style={{ ...S.statLabel, color: "#FFD65A" }}>Best</div><div style={{ ...S.statValue, ...deviceLayout.statValue }}>{best}</div></div>
        <div style={{ ...S.statBox, ...deviceLayout.statBox }}><div style={S.statLabel}>Combo</div><div style={{ ...S.statValue, ...deviceLayout.statValue }}>{combo > 0 ? `${combo}x` : "-"}</div></div>
        <div style={{ ...S.statBox, ...deviceLayout.statBox, flex: 1.3 }}>
          <div style={S.statLabel}>Heat ×{multiplier}</div>
          <div style={S.heatTrack}>
            <div key={pulse} style={{ ...S.heatFill, width: `${heatPct}%`, animation: "heatPulse 0.3s ease", transformOrigin: "center" }} />
          </div>
        </div>
      </div>

      <div style={{ position: "relative", animation: shake ? "screenShake 0.28s ease" : "none" }}>
        <div
          ref={gridRef}
          style={{ ...S.grid, ...deviceLayout.grid, animation: `marquee ${marqueeSpeed}s ease-in-out infinite`, border: eraseMode ? "2px dashed #FF3B5C" : S.grid.border }}
          onPointerMove={moveDrag} onPointerUp={endDrag} onPointerCancel={() => setDrag(null)}
        >
          {grid.map((row, r) => row.map((cell, c) => {
            const key = `${r}-${c}`;
            const isClearing = clearingKeys.includes(key);
            let bg = "transparent", glow = "none", border = "1px solid #2A1F3D";
            if (cell) {
              bg = cell.gold ? gemGradient(GOLD) : gemGradient(paletteRgb(cell.colorIdx));
              glow = `0 0 10px ${cell.gold ? toRgb(GOLD) : toRgb(paletteRgb(cell.colorIdx))}77`;
              border = "1px solid rgba(255,255,255,0.4)";
            }
            let previewState = null;
            if (preview) drag.piece.shape.forEach(([dr, dc]) => { if (preview.r0 + dr === r && preview.c0 + dc === c) previewState = preview.valid; });
            return (
              <div key={key} className="grid-cell" onClick={() => handleCellClick(r, c)} style={{
                ...S.cell,
                cursor: eraseMode ? "crosshair" : "default",
                background: previewState === true ? "#4ADE8055" : previewState === false ? "#FF3B5C66" : bg,
                boxShadow: previewState == null ? glow : "none",
                border: previewState != null ? "1px dashed " + (previewState ? "#4ADE80" : "#FF3B5C") : border,
                animation: isClearing ? "flashClear 0.22s ease-in forwards" : "none",
              }} />
            );
          }))}
        </div>
        {comboPop && <div key={comboPop.id} style={S.comboPop}>{comboPop.text}</div>}
        {toast && <div style={S.toast}>{toast}</div>}
        {jackpotFlash && (
          <div style={S.jackpotBanner}>
            <div>JACKPOT!</div>
            {jackpotBonus != null && <div style={S.jackpotScore}>+{jackpotBonus}</div>}
          </div>
        )}
        {shareReady && (
          <button style={S.shareBtn} onClick={() => shareJackpotCard(score, multiplier)}>📸 Share Jackpot</button>
        )}
      </div>

      <div style={{ ...S.tray, ...deviceLayout.tray }}>
        {tray.map((piece) => {
          const dims = shapeDims(piece.shape);
          const isDragging = drag && drag.piece.id === piece.id;
          return (
            <div key={piece.id} className="tray-piece" onPointerDown={(e) => startDrag(e, piece)} style={{ ...S.trayPiece, opacity: isDragging ? 0.25 : 1, touchAction: "none" }}>
              {piece.gold && <Sparkles size={12} color={toRgb(GOLD)} style={S.goldIcon} />}
              {piece.bomb && <Bomb size={16} color="#fff" style={{ ...S.goldIcon, animation: "bombPulse 0.9s ease infinite" }} />}
              <div style={{ display: "grid", gridTemplateColumns: `repeat(${dims.w}, ${deviceLayout.trayCell.size}px)`, gridTemplateRows: `repeat(${dims.h}, ${deviceLayout.trayCell.size}px)`, gap: deviceLayout.trayCell.gap }}>
                {Array.from({ length: dims.h }).map((_, r) => Array.from({ length: dims.w }).map((_, c) => {
                  const filled = piece.shape.some(([dr, dc]) => dr === r && dc === c);
                  const bg = piece.bomb ? "linear-gradient(135deg, #444, #111)" : piece.gold ? gemGradient(GOLD) : gemGradient(paletteRgb(piece.colorIdx));
                  return <div key={`${r}-${c}`} style={{ width: deviceLayout.trayCell.size, height: deviceLayout.trayCell.size, borderRadius: 3, background: filled ? bg : "transparent", boxShadow: filled ? "0 0 6px rgba(0,0,0,0.4)" : "none", animation: filled && piece.gold ? "goldPulse 1.1s ease infinite" : filled && piece.bomb ? "bombPulse 0.9s ease infinite" : "none" }} />;
                }))}
              </div>
            </div>
          );
        })}
      </div>

      <div style={{ ...S.boosterBar, ...deviceLayout.boosterBar }}>
        <button className="booster-btn" style={{ ...S.boosterBtn, ...deviceLayout.boosterBtn, opacity: coins < REROLL_COST ? 0.5 : 1 }} onClick={rerollTray} disabled={coins < REROLL_COST}>
          🔄 Reroll<span style={S.boosterCost}>{REROLL_COST}🪙</span>
        </button>
        <button className="booster-btn" style={{ ...S.boosterBtn, ...deviceLayout.boosterBtn, opacity: coins < ERASER_COST ? 0.5 : 1, borderColor: eraseMode ? "#FF3B5C" : "#4A2E66" }} onClick={toggleEraser} disabled={coins < ERASER_COST && !eraseMode}>
          ✂️ Erase<span style={S.boosterCost}>{ERASER_COST}🪙</span>
        </button>
        <button className="booster-btn" style={{ ...S.boosterBtnGold, ...deviceLayout.boosterBtn }} onClick={openCoinPicker}>
          🪙 Get coins
        </button>

      {drag && (
        <div style={{ position: "fixed", left: drag.x - drag.dims.w * 13, top: drag.y - drag.dims.h * 13 - (drag.pointerType === "touch" ? 70 : 0), pointerEvents: "none", display: "grid", gridTemplateColumns: `repeat(${drag.dims.w}, 26px)`, gridTemplateRows: `repeat(${drag.dims.h}, 26px)`, gap: "3px", zIndex: 50 }}>
          {Array.from({ length: drag.dims.h }).map((_, r) => Array.from({ length: drag.dims.w }).map((_, c) => {
            const filled = drag.piece.shape.some(([dr, dc]) => dr === r && dc === c);
            const bg = drag.piece.bomb ? "linear-gradient(135deg, #444, #111)" : drag.piece.gold ? gemGradient(GOLD) : gemGradient(paletteRgb(drag.piece.colorIdx));
            return <div key={`${r}-${c}`} style={{ width: 26, height: 26, borderRadius: 5, background: filled ? bg : "transparent", boxShadow: filled ? "0 0 14px rgba(255,255,255,0.4)" : "none" }} />;
          }))}
        </div>
      )}

      {showCoinPicker && (
        <div style={S.overlay}>
          <div style={{ ...S.overlayCard, ...deviceLayout.overlayCard }}>
            <h2 style={S.overlayTitle}>Get Coins</h2>
            <p style={S.overlayText}>Bigger packs give more coins per dollar.</p>
            <div style={S.coinTierList}>
              {COIN_PACKAGES.map((tier, i) => {
                const live = liveOfferings && liveOfferings.find((p) => p.identifier === tier.id);
                const priceLabel = live?.product?.priceString || tier.price;
                return (
                  <button
                    key={tier.id}
                    style={{ ...S.coinTierBtn, opacity: purchasing && purchasing !== tier.id ? 0.5 : 1 }}
                    onClick={() => buyCoinPack(tier)}
                    disabled={!!purchasing}
                  >
                    <span style={S.coinTierAmount}>🪙 {tier.coins}{i === COIN_PACKAGES.length - 1 ? " · best value" : ""}</span>
                    <span style={S.coinTierPrice}>{purchasing === tier.id ? "…" : priceLabel}</span>
                  </button>
                );
              })}
            </div>
            <button style={{ ...S.restartBtn, marginTop: 14, background: "#241238", color: "#C9B8E8" }} onClick={() => setShowCoinPicker(false)}>
              Close
            </button>
          </div>
        </div>
      )}

      {showInterstitial && (
        <div style={S.interstitialOverlay}>
          <div style={S.interstitialTag}>Advertisement</div>
          <div style={S.interstitialBox}>
            <div style={S.interstitialLabel}>Interstitial ad placeholder</div>
            <div style={{ color: "#8A7CA8", fontSize: 12 }}>Wire up AdMob / AppLovin / IronSource here</div>
          </div>
          <button style={{ ...S.restartBtn, opacity: interstitialReady ? 1 : 0.4, marginTop: 18 }} onClick={closeInterstitial} disabled={!interstitialReady}>
            {interstitialReady ? "Continue" : "Please wait…"}
          </button>
        </div>
      )}

      {gameOver && (
        <div style={S.overlay}>
          <div style={S.overlayCard}>
            <Flame size={30} color="#FFD65A" />
            <h2 style={S.overlayTitle}>Table's Closed</h2>
            <p style={S.overlayText}>No move fits. Final heat reached ×{multiplier}.</p>
            <div style={S.overlayStats}>
              <div><div style={S.statLabel}>Score</div><div style={S.statValue}>{score}</div></div>
              <div><div style={S.statLabel}>Best</div><div style={S.statValue}>{best}</div></div>
            </div>
            {!rescueUsed && (
              <button style={S.rescueBtn} onClick={watchAdToContinue} disabled={rescuing}>
                {rescuing ? "Loading ad…" : "Watch ad to clear space & continue"}
              </button>
            )}
            <button style={S.restartBtn} onClick={restart}><RotateCcw size={14} /> Play again</button>
          </div>
        </div>
      )}
    </div>
  );
}

const S = {
  wrap: {
    fontFamily: "'JetBrains Mono', monospace",
    background: "radial-gradient(ellipse at top, #241238 0%, #12081F 60%, #0A0512 100%)",
    color: "#F3ECE3",
    minHeight: "100%",
    padding: "20px 16px 120px",
    maxWidth: 460,
    margin: "0 auto",
    position: "relative",
    userSelect: "none",
  },
  header: { marginBottom: 12 },
  titleRow: { display: "flex", alignItems: "center", justifyContent: "space-between" },
  title: {
    fontFamily: "'Baloo 2', sans-serif", fontWeight: 800, fontSize: 32, letterSpacing: "0.02em", margin: 0,
    background: "linear-gradient(180deg, #FFF3C4, #FFD65A 60%, #E8A72E)",
    WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent",
    textShadow: "0 0 18px rgba(255,214,90,0.35)",
  },
  iconBtn: { background: "#241238", border: "1px solid #4A2E66", borderRadius: 6, width: 44, height: 36, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 1, cursor: "pointer" },
  iconBtnLabel: { fontSize: 8, letterSpacing: "0.05em", color: "#8A7CA8", textTransform: "uppercase" },
  streakRow: { display: "flex", gap: 6, marginTop: 8, flexWrap: "wrap" },
  streakBadge: { fontSize: 10.5, letterSpacing: "0.04em", padding: "3px 8px", borderRadius: 4, border: "1px solid #4A2E66", color: "#FFD65A", background: "#241238" },
  tagline: { color: "#C9B8E8", fontSize: 12.5, marginTop: 8, lineHeight: 1.5, fontFamily: "system-ui, sans-serif" },
  adBanner: {
    height: 50, borderRadius: 6, border: "1px dashed #4A2E66", background: "#1A0F2A",
    color: "#6E5F8C", fontSize: 11, display: "flex", alignItems: "center", justifyContent: "center",
    letterSpacing: "0.04em", marginBottom: 12, overflow: "hidden",
  },
  goalsToggle: {
    width: "100%", display: "flex", justifyContent: "space-between", alignItems: "center",
    background: "#1E1030", border: "1px solid #4A2E66", borderRadius: 6, padding: "9px 12px",
    color: "#FFD65A", fontFamily: "'JetBrains Mono', monospace", fontSize: 12, fontWeight: 700,
    cursor: "pointer", marginBottom: 10,
  },
  goalsCount: { fontSize: 11, color: "#C9B8E8", fontWeight: 500 },
  goalsPanel: {
    background: "#1E1030", border: "1px solid #4A2E66", borderRadius: 8, padding: "10px 12px",
    marginBottom: 12, display: "flex", flexDirection: "column", gap: 10,
  },
  goalRow: { display: "flex", alignItems: "center", gap: 10 },
  goalLabel: { fontSize: 11.5, color: "#F3ECE3", marginBottom: 4, fontFamily: "system-ui, sans-serif" },
  goalTrack: { height: 6, borderRadius: 3, background: "#12081F", overflow: "hidden" },
  goalFill: { height: "100%", borderRadius: 3, background: "linear-gradient(90deg, #FFD65A, #FF8A3D)", transition: "width 0.25s ease" },
  goalProgress: { fontSize: 9.5, color: "#8A7CA8", marginTop: 3 },
  goalClaimBtn: {
    background: "linear-gradient(135deg, #FFD65A, #FF8A3D)", color: "#2A1B08", border: "none", borderRadius: 6,
    padding: "6px 10px", fontFamily: "'JetBrains Mono', monospace", fontWeight: 700, fontSize: 10.5,
    cursor: "pointer", whiteSpace: "nowrap",
  },
  goalClaimed: { fontSize: 10.5, color: "#4ADE80", whiteSpace: "nowrap" },
  statsRow: { display: "flex", gap: 8, marginBottom: 14 },
  statBox: { flex: 1, background: "#1E1030", border: "1px solid #4A2E66", borderRadius: 6, padding: "8px 10px" },
  statLabel: { fontSize: 10, letterSpacing: "0.08em", textTransform: "uppercase", color: "#B7A4D8", marginBottom: 4 },
  statValue: { fontSize: 18, fontWeight: 700, color: "#FFF3C4" },
  heatTrack: { height: 8, borderRadius: 4, background: "#12081F", overflow: "hidden", marginTop: 2 },
  heatFill: { height: "100%", borderRadius: 4, transition: "width 0.25s ease", background: "linear-gradient(90deg, #FFD65A, #FF6B6B, #FF3B5C)", boxShadow: "0 0 10px rgba(255,107,107,0.7)" },
  grid: {
    display: "grid", gridTemplateColumns: `repeat(${SIZE}, 1fr)`, gridTemplateRows: `repeat(${SIZE}, 1fr)`, gap: "3px",
    background: "#1E1030", border: "2px solid #FFD65A", borderRadius: 10, padding: "6px", aspectRatio: "1 / 1", touchAction: "none",
  },
  cell: { borderRadius: 4, aspectRatio: "1 / 1" },
  toast: { position: "absolute", left: "50%", bottom: -6, transform: "translate(-50%, 0)", background: "#241238", border: "1px solid rgba(255,214,90,0.5)", color: "#FFD65A", fontSize: 11.5, padding: "6px 12px", borderRadius: 20, whiteSpace: "nowrap", animation: "toastIn 1.2s ease forwards" },
  comboPop: { position: "absolute", left: "50%", top: "38%", zIndex: 32, color: "#FFF3C4", fontFamily: "'Baloo 2', sans-serif", fontSize: 28, fontWeight: 800, textShadow: "0 0 18px rgba(255,138,61,0.9)", pointerEvents: "none", whiteSpace: "nowrap", animation: "comboFloat 0.9s ease forwards" },
  jackpotBanner: {
    position: "absolute", left: "50%", top: "50%", fontFamily: "'Baloo 2', sans-serif", fontWeight: 800, fontSize: 46,
    background: "linear-gradient(180deg, #FFF3C4, #FFD65A, #FF8A3D)", WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent",
    textShadow: "0 0 30px rgba(255,214,90,0.7)", animation: "jackpotZoom 1.5s ease forwards", pointerEvents: "none", zIndex: 30, letterSpacing: "0.03em", textAlign: "center", lineHeight: 0.9,
  },
  jackpotScore: {
    marginTop: 8, fontSize: 26, fontFamily: "'JetBrains Mono', monospace", letterSpacing: "0.02em",
  },
  shareBtn: {
    position: "absolute", left: "50%", bottom: 10, transform: "translateX(-50%)", zIndex: 31,
    background: "linear-gradient(135deg, #FFD65A, #FF8A3D)", color: "#2A1B08", border: "none", borderRadius: 20,
    padding: "8px 16px", fontFamily: "'JetBrains Mono', monospace", fontWeight: 700, fontSize: 12, cursor: "pointer",
  },
  tray: { display: "flex", justifyContent: "space-around", alignItems: "center", marginTop: 18, background: "#1E1030", border: "1px solid #4A2E66", borderRadius: 8, padding: "16px 10px", minHeight: 70 },
  trayPiece: { padding: 6, cursor: "grab", position: "relative" },
  goldIcon: { position: "absolute", top: -2, right: -2 },
  boosterBar: { display: "flex", gap: 8, marginTop: 10 },
  boosterBtn: {
    flex: 1, background: "#1E1030", border: "1px solid #4A2E66", borderRadius: 6, padding: "9px 6px",
    color: "#F3ECE3", fontFamily: "'JetBrains Mono', monospace", fontSize: 11.5, fontWeight: 600, cursor: "pointer",
    display: "flex", flexDirection: "column", alignItems: "center", gap: 3,
  },
  boosterBtnGold: {
    flex: 1, background: "linear-gradient(135deg, #FFD65A, #FF8A3D)", border: "none", borderRadius: 6, padding: "9px 6px",
    color: "#2A1B08", fontFamily: "'JetBrains Mono', monospace", fontSize: 11.5, fontWeight: 700, cursor: "pointer",
  },
  boosterCost: { fontSize: 9.5, color: "#B7A4D8", fontWeight: 400 },
  interstitialOverlay: {
    position: "absolute", inset: 0, background: "#0A0512f2", display: "flex", flexDirection: "column",
    alignItems: "center", justifyContent: "center", borderRadius: 8, zIndex: 60, padding: 24,
  },
  interstitialTag: { position: "absolute", top: 14, left: 14, fontSize: 10, letterSpacing: "0.1em", color: "#6E5F8C", border: "1px solid #4A2E66", borderRadius: 4, padding: "2px 6px" },
  interstitialBox: { width: "100%", maxWidth: 300, aspectRatio: "3/4", border: "1px dashed #4A2E66", borderRadius: 10, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8, textAlign: "center", padding: 16 },
  interstitialLabel: { color: "#C9B8E8", fontSize: 13, fontWeight: 600 },
  overlay: { position: "absolute", inset: 0, background: "#0A0512dd", display: "flex", alignItems: "center", justifyContent: "center", borderRadius: 8 },
  overlayCard: { background: "#1E1030", border: "1px solid #4A2E66", borderRadius: 10, padding: "26px 28px", textAlign: "center", width: "84%", maxWidth: 320 },
  overlayTitle: { fontFamily: "'Baloo 2', sans-serif", fontSize: 24, margin: "10px 0 4px", letterSpacing: "0.02em", color: "#FFD65A" },
  overlayText: { color: "#C9B8E8", fontSize: 12.5, marginBottom: 16, fontFamily: "system-ui, sans-serif" },
  overlayStats: { display: "flex", justifyContent: "center", gap: 24, marginBottom: 16 },
  coinTierList: { display: "flex", flexDirection: "column", gap: 8, marginTop: 6 },
  coinTierBtn: {
    display: "flex", justifyContent: "space-between", alignItems: "center",
    background: "#241238", border: "1px solid #4A2E66", borderRadius: 8, padding: "12px 14px",
    color: "#F3ECE3", fontFamily: "'JetBrains Mono', monospace", fontSize: 13, fontWeight: 600, cursor: "pointer",
  },
  coinTierAmount: { color: "#FFD65A" },
  coinTierPrice: { color: "#C9B8E8", fontSize: 12.5 },
  rescueBtn: { display: "block", width: "100%", background: "#2E5A66", color: "#EAF7FA", border: "1px solid #3E7684", borderRadius: 6, padding: "10px 14px", fontFamily: "'JetBrains Mono', monospace", fontWeight: 600, fontSize: 12, letterSpacing: "0.02em", cursor: "pointer", marginBottom: 10 },
  restartBtn: { display: "inline-flex", alignItems: "center", gap: 6, background: "linear-gradient(135deg, #FFD65A, #FF8A3D)", color: "#2A1B08", border: "none", borderRadius: 6, padding: "9px 16px", fontFamily: "'JetBrains Mono', monospace", fontWeight: 700, fontSize: 12.5, letterSpacing: "0.05em", textTransform: "uppercase", cursor: "pointer" },
};
