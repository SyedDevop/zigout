/** @type {WebAssembly.Exports} */
let exports = undefined;

const imports = {
  env: {},
};

const readString = (structPtr) => {
  const fields = new Uint32Array(exports.memory.buffer, structPtr, 2);
  return {
    size: fields[0],
    ptr: fields[1],
  };
};

const decodeString = (str) => {
  const bytes = new Uint8Array(exports.memory.buffer, str.ptr, str.size);
  return new TextDecoder().decode(bytes);
};

const getString = (structPtr) => {
  return decodeString(readString(structPtr));
};

WebAssembly.instantiateStreaming(fetch("game.wasm"), imports).then((result) => {
  exports = result.instance.exports;
  const ptr = exports.helloWorld();
  console.log({ ptr, string: getString(ptr) });
});
