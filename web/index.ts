import wasmUrl from "./game.wasm?url";
let canvas = document.getElementById("canvas") as HTMLCanvasElement | null;
if (!canvas) throw new Error("no canvas found");
let ctx = canvas.getContext("2d");
if (!ctx) throw new Error("no canvas context found");

/** Exports from web/game.zig. */
interface GameExports {
  memory: WebAssembly.Memory;
  WINDOW_WIDTH: WebAssembly.Global;
  WINDOW_HEIGHT: WebAssembly.Global;
  BACKGROUND_COLOR: WebAssembly.Global;
  init: () => void;
  update: (dt: number) => void;
  reset: () => void;
  render: () => void;
  killAll: () => void;
  getScore: () => number;
  keyPressed: (key: number) => void;
  keyReleased: (key: number) => void;
}

const imports: WebAssembly.Imports = {
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
};

const { instance } = await WebAssembly.instantiateStreaming(fetch(wasmUrl), imports);
const exports = instance.exports as unknown as GameExports;

const view = new DataView(exports.memory.buffer);
// Exported Zig consts are wasm globals holding the address of the value in memory.
const WIDTH = view.getUint16(exports.WINDOW_WIDTH.value, true);
const HEIGHT = view.getUint16(exports.WINDOW_HEIGHT.value, true);
const BG_COLOR = view.getUint32(exports.BACKGROUND_COLOR.value, true);

canvas.width = WIDTH;
canvas.height = HEIGHT;
exports.init();

let start: number | null = null;
let framesId: number | null = null;

function firstFrame(timestamp: number) {
  start = timestamp;
  framesId = window.requestAnimationFrame(frames);
}
function frames(timestamp: number) {
  const dt = (timestamp - start!) / 1000;
  start = timestamp;
  exports.update(dt);
  ctx!.fillStyle = `#${BG_COLOR.toString(16).padStart(8, "0")}`;
  ctx!.fillRect(0, 0, WIDTH, HEIGHT);
  exports.render();
  framesId = window.requestAnimationFrame(frames);
}
framesId = window.requestAnimationFrame(frames);

document.addEventListener("keydown", (e) => {
  exports.keyPressed(e.keyCode);
});
document.addEventListener("keyup", (e) => {
  exports.keyReleased(e.keyCode);
});
