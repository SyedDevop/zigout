import wasmUrl from "game.wasm?url";
import { hexColor } from "./utils";
import { loadWasm, type WasmExports, type WasmImports } from "./wasm";

const decoder = new TextDecoder();
const logFns = [console.error, console.warn, console.info, console.debug] as const;

export class Game {
  canvas: HTMLCanvasElement;
  ctx: CanvasRenderingContext2D;
  memory: WebAssembly.Memory | null = null;
  exports!: WasmExports;

  gameLoaded = false;
  WIDTH!: number;
  HEIGHT!: number;
  BG_COLOR!: number;

  lastTime: number = 0;
  constructor() {
    const canvas = document.getElementById("canvas") as HTMLCanvasElement | null;
    if (!canvas) throw new Error("no canvas found");
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("no canvas context found");
    this.canvas = canvas;
    this.ctx = ctx;
  }
  initialize() {
    if (!this.gameLoaded) {
      throw new Error(
        "Game not loaded. Create a Game instance and call await game.load() before using it.",
      );
    }

    const view = new DataView(this.exports.memory.buffer);
    // Exported Zig consts are wasm globals holding the address of the value in memory.
    this.WIDTH = view.getUint16(this.exports.WINDOW_WIDTH, true);
    this.HEIGHT = view.getUint16(this.exports.WINDOW_HEIGHT, true);
    this.BG_COLOR = view.getUint32(this.exports.BACKGROUND_COLOR, true);

    this.canvas.width = this.WIDTH;
    this.canvas.height = this.HEIGHT;
    this.exports.init();
  }

  update() {
    window.requestAnimationFrame((t) => this.firstFrame(t));
    document.body.classList.add("ready");
    this.canvas.focus();
  }

  frames(timestamp: number) {
    // First frame has no previous timestamp; clamp so a tab switch can't produce a giant step.
    const dt = Math.min((timestamp - this.lastTime) / 1000, 0.0166);
    this.lastTime = timestamp;

    this.exports.update(dt);
    this.ctx!.fillStyle = hexColor(this.BG_COLOR);
    this.ctx!.fillRect(0, 0, this.WIDTH, this.HEIGHT);
    this.exports.render();
    window.requestAnimationFrame((t) => this.frames(t));
  }

  firstFrame(timestamp: number) {
    this.lastTime = timestamp;
    this.frames(timestamp);
  }

  async load() {
    const imports = {
      env: {
        jsRandomFloat: () => Math.random(),
        jsLog: (level: number, ptr: number, len: number) => {
          // Re-read memory.buffer each call: it is replaced whenever wasm memory grows.
          const msg = this.readString(ptr, len) ?? "Wasm Memory";
          (logFns[level] ?? console.log)(`[zig] ${msg}`);
        },

        jsDrawReact: (x, y, w, h, r, g, b, a) => {
          this.ctx.fillStyle = hexColor(r, g, b, a);
          this.ctx.fillRect(x, y, w, h);
        },
        jsDrawText: (ptr, len, pos_x, pos_y, font_size, r, g, b, a) => {
          const text = this.readString(ptr, len);
          if (!text) return;
          this.ctx.font = `${font_size}px sans-serif`;
          this.ctx.fillStyle = hexColor(r, g, b, a);
          this.ctx.fillText(text, pos_x, pos_y);
        },
        jsMeasureText: (ptr, len, font_size) => {
          const text = this.readString(ptr, len);
          if (!text) return 0;
          this.ctx.font = `${font_size}px sans-serif`;
          return this.ctx.measureText(text).width;
        },
      },
    } satisfies WasmImports;

    try {
      const loaded = await loadWasm(wasmUrl, imports);
      this.exports = loaded.instance.exports;
      this.memory = this.exports.memory;
      this.gameLoaded = true;
    } catch (err) {
      const loader = document.getElementById("loader");
      const loaderText = document.getElementById("loader-text");
      loader?.classList.add("error");
      if (loaderText) loaderText.textContent = "Failed to load the game. Please refresh.";
      throw err;
    }
  }

  readString(ptr: number, len: number): string | null {
    if (!this.memory) return null;
    return decoder.decode(new Uint8Array(this.memory.buffer, ptr, len));
  }
}
