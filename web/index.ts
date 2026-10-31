import wasmUrl from "game.wasm?url";
import { loadWasm, type WasmImports } from "./wasm.ts";

const canvas = document.getElementById("canvas") as HTMLCanvasElement | null;
const fpsText = document.getElementById("fps-value") as HTMLSpanElement | null;
if (!canvas) throw new Error("no canvas found");
const ctx = canvas.getContext("2d");
if (!ctx) throw new Error("no canvas context found");

const imports = {
  env: {
    randomFloatJs: () => Math.random(),
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
const view = new DataView(exports.memory.buffer);
// Exported Zig consts are wasm globals holding the address of the value in memory.
const WIDTH = view.getUint16(exports.WINDOW_WIDTH, true);
const HEIGHT = view.getUint16(exports.WINDOW_HEIGHT, true);
const BG_COLOR = view.getUint32(exports.BACKGROUND_COLOR, true);

canvas.width = WIDTH;
canvas.height = HEIGHT;
exports.init();

let lastTime: number = 0;
let accumulatedTime: number = 0;

let frameCount = 0;
let fpsElapsed = 0;
const FPS = 1 / 500;
fpsText && (fpsText.textContent = FPS.toString());
function frames(timestamp: number) {
  const dt = (timestamp - lastTime) / 1000;
  lastTime = timestamp;
  accumulatedTime += dt;

  // while (accumulatedTime >= FPS) {
  exports.update(dt);
  // accumulatedTime -= FPS;
  // }
  ctx!.fillStyle = `#${BG_COLOR.toString(16).padStart(8, "0")}`;
  ctx!.fillRect(0, 0, WIDTH, HEIGHT);
  exports.render();

  frameCount++;
  fpsElapsed += dt;

  if (fpsElapsed >= 1) {
    if (fpsText) {
      fpsText.textContent = frameCount.toString();
    }

    frameCount = 0;
    fpsElapsed = 0;
  }

  window.requestAnimationFrame(frames);
}
window.requestAnimationFrame(frames);

document.addEventListener("keydown", (e) => {
  switch (e.key) {
    case "ArrowLeft":
      exports.keyPressed(130);
      break;
    case "ArrowRight":
      exports.keyPressed(131);
      break;
    default:
      exports.keyPressed(e.key.charCodeAt(0));
  }
});
document.addEventListener("keyup", (e) => {
  switch (e.key) {
    case "ArrowLeft":
      exports.keyReleased(130);
      break;
    case "ArrowRight":
      exports.keyReleased(131);
      break;
    default:
      exports.keyReleased(e.key.charCodeAt(0));
  }
});
