.PHONY: wasm wasm2wat serve main

main: 
	 zig build

WASM_SRC := ./web/game.zig
WASM_OUT := ./web/game.wasm
WASM_TARGET := wasm32-wasi #wasm32-freestanding
WASM_OPT := ReleaseSmall
WASM_STACK ?=

wasm:
	zig build-exe \
		-target $(WASM_TARGET) \
		-fno-entry \
		-rdynamic \
		-O ReleaseSmall \
		$(WASM_SRC) \
		-femit-bin=$(WASM_OUT) \
		$(if $(WASM_STACK),--stack $(WASM_STACK))

wasm2wat:
	 wasm2wat $(WASM_OUT)
serve:
	python -m http.server -d ./web/
