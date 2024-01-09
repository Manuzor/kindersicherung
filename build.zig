const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSafe,
    });

    const strip = b.option(bool, "strip", "strip debug symbols / omit pdbs");

    const exe = b.addExecutable(.{
        .name = "kindersicherung",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = mode,
        .strip = strip,
    });
    exe.addWin32ResourceFile(.{
        .file = .{ .path = "src/kindersicherung.rc" },
    });
    exe.subsystem = if (mode == .Debug) .Console else .Windows;
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
