import wasmUrl from "game.wasm?url";
import { loadWasm, type WasmImports } from "./wasm.ts";

const canvas = document.getElementById("canvas") as HTMLCanvasElement | null;
const fpsText = document.getElementById("fps-value") as HTMLSpanElement | null;
if (!canvas) throw new Error("no canvas found");
const ctx = canvas.getContext("2d");
if (!ctx) throw new Error("no canvas context found");

// Set after instantiation; logJs is only called from exported functions, never during instantiate.
let memory: WebAssembly.Memory | null = null;
const decoder = new TextDecoder();
const logFns = [console.error, console.warn, console.info, console.debug] as const;

const imports = {
  env: {
    randomFloatJs: () => Math.random(),
    logJs: (level: number, ptr: number, len: number) => {
      if (!memory) return;
      // Re-read memory.buffer each call: it is replaced whenever wasm memory grows.
      const msg = decoder.decode(new Uint8Array(memory.buffer, ptr, len));
      (logFns[level] ?? console.log)(`[zig] ${msg}`);
    },
    drawReactJs: (
      x: number,
      y: number,
      w: number,
      h: number,
      r: number,
      g: number,
      b: number,
      a: number,
    ) => {
      const red = r.toString(16).padStart(2, "0");
      const green = g.toString(16).padStart(2, "0");
      const blue = b.toString(16).padStart(2, "0");
      const alpha = a.toString(16).padStart(2, "0");
      ctx.fillStyle = `#${red}${green}${blue}${alpha}`;
      ctx.fillRect(x, y, w, h);
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

let lastTime: number | null = null;

function frames(timestamp: number) {
  // First frame has no previous timestamp; clamp so a tab switch can't produce a giant step.
  const dt = lastTime === null ? 0 : Math.min((timestamp - lastTime) / 1000, 0.0166);
  lastTime = timestamp;

  exports.update(dt);
  ctx!.fillStyle = `#${BG_COLOR.toString(16).padStart(8, "0")}`;
  ctx!.fillRect(0, 0, WIDTH, HEIGHT);
  exports.render();
  window.requestAnimationFrame(frames);
}
window.requestAnimationFrame(frames);

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
