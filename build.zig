pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spaghet = b.dependency("spaghet", .{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "spaghet", .module = spaghet.module("spaghet") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "zzz_stats_github_io",
        .root_module = mod,
    });

    const tests = b.addTest(.{ .root_module = mod });
    const run_test = b.addRunArtifact(tests);
    b.default_step.dependOn(&run_test.step);

    const run = b.step("run", "");
    const run_exe_step = b.addRunArtifact(exe);
    run_exe_step.addArgs(b.args orelse &.{});
    run_exe_step.stdio = .inherit;
    run.dependOn(&run_exe_step.step);

    const install_exe = b.addInstallArtifact(exe, .{});
    run_exe_step.step.dependOn(&install_exe.step);

    const check = b.step("check", "Check if tests compile");
    check.dependOn(&tests.step);
}

const std = @import("std");
