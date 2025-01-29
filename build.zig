const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zbreak",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const dic = b.addExecutable(.{
        .name = "zb",
        .root_source_file = b.path("src/driction.zig"),
        .target = target,
        .optimize = optimize,
    });
    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    b.installArtifact(exe);
    dic.linkLibrary(raylib_artifact);
    dic.root_module.addImport("raylib", raylib);
    dic.root_module.addImport("raygui", raygui);
    b.installArtifact(dic);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const run_cmd_dic = b.addRunArtifact(dic);
    run_cmd_dic.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd_dic.addArgs(args);
    }
    const run_step_dic = b.step("run-dic", "Run Driction test example");
    run_step_dic.dependOn(&run_cmd_dic.step);

    const exe_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
