import wasmUrl from "game.wasm?url";
import { loadWasm, type WasmImports } from "./wasm.ts";

const canvas = document.getElementById("canvas") as HTMLCanvasElement | null;
if (!canvas) throw new Error("no canvas found");
const ctx = canvas.getContext("2d");
if (!ctx) throw new Error("no canvas context found");

// Set after instantiation; logJs is only called from exported functions, never during instantiate.
let memory: WebAssembly.Memory | null = null;
const decoder = new TextDecoder();
const logFns = [console.error, console.warn, console.info, console.debug] as const;

const readString = (ptr: number, len: number): string | null => {
  if (!memory) return null;
  return decoder.decode(new Uint8Array(memory.buffer, ptr, len));
};

const hexColor = (r: number, g: number, b: number, a: number): string => {
  const red = r.toString(16).padStart(2, "0");
  const green = g.toString(16).padStart(2, "0");
  const blue = b.toString(16).padStart(2, "0");
  const alpha = a.toString(16).padStart(2, "0");
  return `#${red}${green}${blue}${alpha}`;
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

const { instance } = await loadWasm(wasmUrl, imports);
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

document.addEventListener("keydown", (e) => {
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
  console.log("KeyUp", e.key);
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
