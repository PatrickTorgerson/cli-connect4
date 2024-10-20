// ********************************************************************************
//! https://github.com/PatrickTorgerson/connect4
//! Copyright (c) 2024 Patrick Torgerson
//! MIT license, see LICENSE for more information
// ********************************************************************************

const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const parsley = b.dependency("parsley", .{}).module("parsley");
    const zcon = b.dependency("zcon", .{}).module("zcon");

    const exe = b.addExecutable(.{
        .name = "connect4",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("parsley", parsley);
    exe.root_module.addImport("zcon", zcon);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .name = "tests",
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe_tests);
    const test_run_cmd = b.addRunArtifact(exe_tests);
    test_run_cmd.step.dependOn(b.getInstallStep());
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_run_cmd.step);
}
