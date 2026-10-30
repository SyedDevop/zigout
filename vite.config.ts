import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { defineConfig, type Plugin } from "vite";

const ZIG_SRC = resolve(import.meta.dirname, "src");
const WASM_OUT = resolve(import.meta.dirname, "zig-out/bin/zbreak-wasm.wasm"); //"web/game.wasm";

function zigWasm(optimize: string): Plugin {
  const build = () => {
    return execFileSync(
      "zig",
      ["build", "wasm", "--verbose"],
      // "zig",
      // ["wasm", `WASM_SRC="${WASM_SRC}"`, `WASM_OUT="${WASM_OUT}"`, `WASM_OPT="${optimize}"`],
      { stdio: "inherit" },
    );
  };

  return {
    name: "zig-wasm",
    config() {
      return {
        resolve: {
          // Regex so the alias also matches `game.wasm?url` and keeps the query.
          alias: [{ find: /^game\.wasm(?=\?|$)/, replacement: WASM_OUT }],
        },
      };
    },
    configureServer(server) {
      server.watcher.add(ZIG_SRC);
    },
    buildStart() {
      try {
        build();
      } catch (err) {
        // In dev keep serving the last good game.wasm; fail hard on production builds.
        if (this.meta.watchMode) this.warn("zig build failed, serving stale game.wasm");
        else throw err;
      }
    },
    hotUpdate({ file, server }) {
      if (this.environment.name !== "client") return;
      if (!file.startsWith(`${ZIG_SRC}/`) || !file.endsWith(".zig")) return;
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
  server: { port: 5173 },
  build: {
    outDir: resolve(import.meta.dirname, "dist"),
    emptyOutDir: true,
    target: "es2023",
  },
}));
