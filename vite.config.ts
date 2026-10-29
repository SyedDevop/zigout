import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { defineConfig, type Plugin } from "vite";

const WASM_SRC = resolve(import.meta.dirname, "web/game.zig");
const WASM_OUT = "web/game.wasm";

function zigWasm(optimize: string): Plugin {
  const build = () => {
    return execFileSync(
      "make",
      [`WASM_SRC="${WASM_SRC}"`, `WASM_OUT="${WASM_OUT}"`, `WASM_OPT="${optimize}"`],
      { stdio: "inherit" },
    );
  };

  return {
    name: "zig-wasm",
    buildStart() {
      this.addWatchFile(WASM_SRC);
      try {
        build();
      } catch (err) {
        // In dev keep serving the last good game.wasm; fail hard on production builds.
        if (this.meta.watchMode) this.warn("zig build failed, serving stale game.wasm");
        else throw err;
      }
    },
    hotUpdate({ file, server }) {
      if (file !== WASM_SRC) return;
      try {
        build();
        server.ws.send({ type: "full-reload" });
      } catch {
        server.config.logger.error("zig build failed");
      }
      return [];
    },
  };
}

export default defineConfig(({ mode }) => ({
  root: "web",
  publicDir: resolve(import.meta.dirname, "public"),
  plugins: [zigWasm(mode === "production" ? "ReleaseSmall" : "Debug")],
  server: {
    port: 5173,
  },
  build: {
    outDir: resolve(import.meta.dirname, "dist"),
    emptyOutDir: true,
    target: "es2023",
  },
}));
