import wasmUrl from "./game.wasm?url";

/** Pointer into wasm linear memory. */
type Ptr = number;

/** Exports from web/game.zig. */
interface GameExports {
  memory: WebAssembly.Memory;
  StringLen(str: Ptr): number;
  StringData(str: Ptr): Ptr;
  allocString(): Ptr;
  allocUsize(): Ptr;
  helloWorld(): Ptr;
}

/** Mirrors the Zig `String` extern struct: { size: usize, ptr: [*]const u8 }. */
interface WasmString {
  size: number;
  ptr: Ptr;
}

let exports: GameExports;

const imports: WebAssembly.Imports = {
  env: {},
};

const readString = (structPtr: Ptr): WasmString => {
  const fields = new Uint32Array(exports.memory.buffer, structPtr, 2);
  return {
    size: fields[0],
    ptr: fields[1],
  };
};

const decodeString = (str: WasmString): string => {
  const bytes = new Uint8Array(exports.memory.buffer, str.ptr, str.size);
  return new TextDecoder().decode(bytes);
};

const getString = (structPtr: Ptr): string => {
  return decodeString(readString(structPtr));
};

WebAssembly.instantiateStreaming(fetch(wasmUrl), imports).then((result) => {
  exports = result.instance.exports as unknown as GameExports;
  const ptr = exports.helloWorld();
  console.log({ ptr, string: getString(ptr) });
});
