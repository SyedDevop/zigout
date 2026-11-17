import wasmUrl from "game.wasm?url";
import { loadWasm, type WasmImports } from "./wasm.ts";
import { hexColor, isMobile } from "./utils.ts";

const canvas = document.getElementById("canvas") as HTMLCanvasElement | null;
if (!canvas) throw new Error("no canvas found");
const ctx = canvas.getContext("2d");
if (!ctx) throw new Error("no canvas context found");

// Mobile layout: hide header/controls and fit the canvas to the screen (see style.css).
if (isMobile()) document.body.classList.add("mobile");

// On mobile, block play until the user goes full screen.
const gate = document.getElementById("gate");
const gateError = document.getElementById("gate-error");
const btn = document.getElementById("fl-btn");

const updateGate = () => {
  if (!gate) return;
  const ok = !isMobile() || !!document.fullscreenElement;
  gate.hidden = ok;
  if (ok) canvas.focus();
};

btn?.addEventListener("click", async () => {
  if (gateError) gateError.hidden = true;
  try {
    if (!document.fullscreenElement && document.documentElement.requestFullscreen) {
      await document.documentElement.requestFullscreen();
    }
  } catch {
    if (gateError) {
      gateError.textContent = "Full screen was blocked — tap the button to try again.";
      gateError.hidden = false;
    }
    return;
  }
  // Orientation lock is unsupported on many browsers (e.g. iOS); full screen alone is enough.
  try {
    await (
      screen.orientation as ScreenOrientation & { lock?: (o: string) => Promise<void> }
    ).lock?.("landscape");
  } catch {}
  updateGate();
});

document.addEventListener("fullscreenchange", updateGate);
updateGate();

// Set after instantiation; logJs is only called from exported functions, never during instantiate.
let memory: WebAssembly.Memory | null = null;
const decoder = new TextDecoder();
const logFns = [console.error, console.warn, console.info, console.debug] as const;

const readString = (ptr: number, len: number): string | null => {
  if (!memory) return null;
  return decoder.decode(new Uint8Array(memory.buffer, ptr, len));
};

const imports = {
  env: {
    jsRandomFloat: () => Math.random(),
    jsLog: (level: number, ptr: number, len: number) => {
      // Re-read memory.buffer each call: it is replaced whenever wasm memory grows.
      const msg = readString(ptr, len) ?? "Wasm Memory";
      (logFns[level] ?? console.log)(`[zig] ${msg}`);
    },

    jsDrawReact: (x, y, w, h, r, g, b, a) => {
      ctx.fillStyle = hexColor(r, g, b, a);
      ctx.fillRect(x, y, w, h);
    },
    jsDrawText: (ptr, len, pos_x, pos_y, font_size, r, g, b, a) => {
      const text = readString(ptr, len);
      if (!text) return;
      ctx.font = `${font_size}px sans-serif`;
      ctx.fillStyle = hexColor(r, g, b, a);
      ctx.fillText(text, pos_x, pos_y);
    },
    jsMeasureText: (ptr, len, font_size) => {
      const text = readString(ptr, len);
      if (!text) return 0;
      ctx.font = `${font_size}px sans-serif`;
      return ctx.measureText(text).width;
    },
  },
} satisfies WasmImports;

const loader = document.getElementById("loader");
const loaderText = document.getElementById("loader-text");

let loaded: Awaited<ReturnType<typeof loadWasm>>;
try {
  loaded = await loadWasm(wasmUrl, imports);
} catch (err) {
  loader?.classList.add("error");
  if (loaderText) loaderText.textContent = "Failed to load the game. Please refresh.";
  throw err;
}
const { instance } = loaded;
const exports = instance.exports;
memory = exports.memory;
const view = new DataView(exports.memory.buffer);
// Exported Zig consts are wasm globals holding the address of the value in memory.
const WIDTH = view.getUint16(exports.WINDOW_WIDTH, true);
const HEIGHT = view.getUint16(exports.WINDOW_HEIGHT, true);
const BG_COLOR = view.getUint32(exports.BACKGROUND_COLOR, true);

canvas.width = WIDTH;
canvas.height = HEIGHT;
exports.init();

let lastTime: number;

function firstFrame(timestamp: number) {
  lastTime = timestamp;
  frames(timestamp);
}
function frames(timestamp: number) {
  // First frame has no previous timestamp; clamp so a tab switch can't produce a giant step.
  const dt = Math.min((timestamp - lastTime) / 1000, 0.0166);
  lastTime = timestamp;

  exports.update(dt);
  ctx!.fillStyle = `#${BG_COLOR.toString(16).padStart(8, "0")}`;
  ctx!.fillRect(0, 0, WIDTH, HEIGHT);
  exports.render();
  window.requestAnimationFrame(frames);
}
window.requestAnimationFrame(firstFrame);
document.body.classList.add("ready");
canvas.focus();

// Keys the game handles; stop the browser from scrolling or activating focused buttons.
const GAME_KEYS = new Set(["ArrowLeft", "ArrowRight", " "]);

document.addEventListener("keydown", (e) => {
  if (GAME_KEYS.has(e.key)) e.preventDefault();
  if (e.repeat) return;
  switch (e.key) {
    case "ArrowLeft":
      exports.keyPressed(37);
      break;
    case "ArrowRight":
      exports.keyPressed(38);
      break;
    default:
      exports.keyPressed(e.keyCode);
  }
});
document.addEventListener("keyup", (e) => {
  switch (e.key) {
    case "ArrowLeft":
      exports.keyReleased(37);
      break;
    case "ArrowRight":
      exports.keyReleased(38);
      break;
    default:
      exports.keyReleased(e.keyCode);
  }
});
