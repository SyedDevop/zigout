import wasmUrl from "game.wasm?url";
import { loadWasm, type WasmImports } from "./wasm.ts";
import { hexColor, isMobile } from "./utils.ts";
import { Game } from "./web_game.ts";

const game = new Game();

// Mobile layout: hide header/controls and fit the canvas to the screen (see style.css).
if (isMobile()) document.body.classList.add("mobile");

const gate = document.getElementById("gate");
const gateError = document.getElementById("gate-error");
const btn = document.getElementById("fl-btn");

const updateGate = () => {
  if (!gate) return;
  const ok = !isMobile() || !!document.fullscreenElement;
  gate.hidden = ok;
  if (ok) game.canvas.focus();
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

await game.load();
game.initialize();
game.update();
// Keys the game handles; stop the browser from scrolling or activating focused buttons.
const GAME_KEYS = new Set(["ArrowLeft", "ArrowRight", " "]);

document.addEventListener("keydown", (e) => {
  if (GAME_KEYS.has(e.key)) e.preventDefault();
  if (e.repeat) return;
  switch (e.key) {
    case "ArrowLeft":
      game.exports.keyPressed(37);
      break;
    case "ArrowRight":
      game.exports.keyPressed(38);
      break;
    default:
      game.exports.keyPressed(e.keyCode);
  }
});
document.addEventListener("keyup", (e) => {
  switch (e.key) {
    case "ArrowLeft":
      game.exports.keyReleased(37);
      break;
    case "ArrowRight":
      game.exports.keyReleased(38);
      break;
    default:
      game.exports.keyReleased(e.keyCode);
  }
});
