import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Window } from "happy-dom";

const html = readFileSync("blocks/stoke_files/index.html", "utf8");

function scriptFromHtml(source) {
  const match = source.match(/<script>\n([\s\S]*)\n<\/script>/);
  assert.ok(match, "generated HTML should inline the built app script");
  return match[1];
}

function event(window, type, props = {}) {
  if (type.startsWith("pointer")) {
    return new window.PointerEvent(type, { bubbles: true, cancelable: true, ...props });
  }
  return new window.Event(type, { bubbles: true, cancelable: true, ...props });
}

async function renderApp({ width = 390, height = 780 } = {}) {
  const window = new Window({
    url: "http://localhost/",
    settings: { disableJavaScriptEvaluation: false },
  });
  const shell = html.replace(/<script>[\s\S]*<\/script>/, "");

  window.document.write(shell);
  window.__STOKE_TEST__ = true;
  window.innerWidth = width;
  window.innerHeight = height;
  window.visualViewport = {
    width,
    height,
    addEventListener() {},
    removeEventListener() {},
  };
  const randomValues = [0.9, 0, 0.9, 0.1];
  let randomIndex = 0;
  window.Math.random = () => randomValues[randomIndex++ % randomValues.length];
  window.HTMLElement.prototype.setPointerCapture = function setPointerCapture() {};
  window.AudioContext = class AudioContext {
    constructor() {
      this.currentTime = 0;
      this.state = "running";
      this.destination = {};
    }
    createOscillator() {
      return {
        type: "",
        frequency: { setValueAtTime() {} },
        connect() {},
        start() {},
        stop() {},
      };
    }
    createGain() {
      return {
        gain: {
          setValueAtTime() {},
          linearRampToValueAtTime() {},
          exponentialRampToValueAtTime() {},
        },
        connect() {},
      };
    }
    resume() {}
  };

  window.eval(scriptFromHtml(html));
  await new Promise((resolve) => setTimeout(resolve, 100));
  return window;
}

function closeApp(window) {
  window.happyDOM.abort();
  window.happyDOM.close();
}

function buttonsWithText(document, text) {
  return [...document.querySelectorAll("button")]
    .filter((button) => button.textContent.includes(text));
}

function visibleFilledCells(document) {
  return [...document.querySelectorAll(".grid-cell")]
    .filter((cell) => cell.style.background && cell.style.background !== "transparent");
}

test("generated app launches with board, tray, objectives, and coin shop", async () => {
  const window = await renderApp();
  const { document } = window;

  try {
    assert.match(document.body.textContent, /STOKE/);
    assert.equal(document.querySelectorAll(".grid-cell").length, 64);
    assert.equal(document.querySelectorAll(".tray-piece").length, 3);

    buttonsWithText(document, "Daily Objectives")[0].click();
    await new Promise((resolve) => setTimeout(resolve, 20));
    assert.match(document.body.textContent, /Claim|Clear|Score|Place|Reach|Hit/);

    buttonsWithText(document, "Get coins")[0].click();
    await new Promise((resolve) => setTimeout(resolve, 20));
    assert.match(document.body.textContent, /Get Coins/);
    assert.match(document.body.textContent, /\$0\.99/);
    assert.match(document.body.textContent, /2000/);
  } finally {
    closeApp(window);
  }
});

test("generated app accepts a drag placement onto the board", async () => {
  const window = await renderApp();
  const { document } = window;

  try {
    const trayPiece = document.querySelector(".tray-piece");
    const grid = document.querySelector(".grid-cell")?.parentElement;

    assert.ok(trayPiece, "tray should contain at least one piece");
    assert.ok(grid, "grid should render");

    Object.defineProperty(grid, "clientWidth", { value: 320, configurable: true });
    grid.getBoundingClientRect = () => ({
      left: 20,
      top: 120,
      right: 340,
      bottom: 440,
      width: 320,
      height: 320,
      x: 20,
      y: 120,
      toJSON() {},
    });
    window.dispatchEvent(event(window, "resize"));
    await new Promise((resolve) => setTimeout(resolve, 20));

    trayPiece.dispatchEvent(event(window, "pointerdown", {
      pointerId: 1,
      pointerType: "mouse",
      clientX: 32,
      clientY: 500,
    }));
    await new Promise((resolve) => setTimeout(resolve, 20));

    window.dispatchEvent(event(window, "pointermove", {
      pointerId: 1,
      pointerType: "mouse",
      clientX: 40,
      clientY: 140,
    }));
    await new Promise((resolve) => setTimeout(resolve, 20));

    window.dispatchEvent(event(window, "pointerup", {
      pointerId: 1,
      pointerType: "mouse",
      clientX: 40,
      clientY: 140,
    }));
    await new Promise((resolve) => setTimeout(resolve, 80));

    assert.ok(visibleFilledCells(document).length > 0, "a successful drag should place visible cells on the board");
    assert.equal(document.querySelectorAll(".tray-piece").length, 2);
  } finally {
    closeApp(window);
  }
});

test("generated app shows game over and rewarded rescue clears space", async () => {
  const window = await renderApp();
  const { document } = window;

  try {
    window.dispatchEvent(event(window, "stoke:test:forceGameOver"));
    await new Promise((resolve) => setTimeout(resolve, 80));

    assert.match(document.body.textContent, /Table's Closed/);
    assert.equal(visibleFilledCells(document).length, 64);

    buttonsWithText(document, "Watch ad")[0].click();
    await new Promise((resolve) => setTimeout(resolve, 1520));

    assert.doesNotMatch(document.body.textContent, /Table's Closed/);
    assert.equal(visibleFilledCells(document).length, 58);
    assert.equal(buttonsWithText(document, "Watch ad").length, 0);
  } finally {
    closeApp(window);
  }
});
