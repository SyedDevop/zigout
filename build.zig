const std = @import("std");

pub fn buildWasm(b: *std.Build) void {
    const wasm_stack_size = b.option(u64, "wasm-stack-size", "Stack size for the WASM target");
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .ofmt = .wasm,
    });

    const wasm_exe = b.addExecutable(.{
        .name = "zbreak-wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/Game.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
        }),
    });
    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;
    if (wasm_stack_size) |stack_size| wasm_exe.stack_size = stack_size;
    const install_wasm = b.addInstallArtifact(wasm_exe, .{});
    const wasm_step = b.step("wasm", "Build wasm target");
    wasm_step.dependOn(&install_wasm.step);

    // wasm:
    // zig build-exe \
    //        -O ReleaseSmall \
    //        $(WASM_SRC) \
    //        -femit-bin=$(WASM_OUT) \
    //        $(if $(WASM_STACK),--stack $(WASM_STACK))
    //
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zbreak",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
    exe.root_module.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    const exe_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    buildWasm(b);
}
