const std = @import("std");

pub fn buildWasm(b: *std.Build) void {
    const wasm_stack_size = b.option(u64, "wasm-stack-size", "Stack size for the WASM target");
    const show_what = b.option(bool, "wasm2wat", "Convert WASM to WAT");
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .ofmt = .wasm,
    });

    const wasm_exe = b.addExecutable(.{
        .name = "zbreak-wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
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

    if (show_what orelse false) {
        const run_wat = b.addSystemCommand(&.{"wasm2wat"});
        run_wat.addFileArg(wasm_exe.getEmittedBin());
        wasm_step.dependOn(&run_wat.step);
    }
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

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

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
