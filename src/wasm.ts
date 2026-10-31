export interface WasmExports {
 init : () => void,
 update : (dt: number, ) => void,
 reset : () => void,
 render : () => void,
 killAll : () => void,
 getScore : () => number,
 keyPressed : (key: number, ) => void,
 keyReleased : (key: number, ) => void,
 FPS : number,
 WINDOW_WIDTH : number,
 WINDOW_HEIGHT : number,
 BACKGROUND_COLOR : number,
 /**
 * Zig modules expose their linear memory back to JS
 */ 
 readonly memory: WebAssembly.Memory;
};


export interface WasmImports extends WebAssembly.Imports {
  env: {
   drawReactJs : (x: number, y: number, width: number, height: number, r: number, g: number, b: number, a: number, ) => void,
   randomFloatJs : () => number,
  },
};


/**
 * Type-safe interface mirroring the native WebAssemblyInstantiatedSource structure
 */
export interface ZigInstantiatedSource {
  instance: Omit<WebAssembly.Instance, 'exports'> & { exports: WasmExports };
  module: WebAssembly.Module;
}


export async function loadWasm(url: string, imports: WasmImports): Promise<ZigInstantiatedSource> {
  // Explicitly cast the resulting promise structure to your target interfaces
  return (await WebAssembly.instantiateStreaming(
    fetch(url),
    imports,
  )) as unknown as ZigInstantiatedSource;
}