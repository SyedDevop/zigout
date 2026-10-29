.PHONY: wasm wasm2wat serve

WASM_SRC := ./web/game.zig
WASM_OUT := ./web/game.wasm
WASM_TARGET := wasm32-wasi #wasm32-freestanding
WASM_OPT := ReleaseSmall

wasm:
	zig build-exe -target $(WASM_TARGET) -fno-entry -rdynamic -O ReleaseSmall $(WASM_SRC) -femit-bin=$(WASM_OUT)
wasm2wat:
	 wasm2wat $(WASM_OUT)
serve:
	python -m http.server -d ./web/
