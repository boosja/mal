const std = @import("std");

pub fn build(b: *std.Build) void {
    const name = b.option([]const u8, "name", "step name (without .zig)") orelse "stepA_mal";
    const root_source_file = b.path(b.option([]const u8, "root_source_file", "step name (with .zig)") orelse "stepA_mal.zig");

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = root_source_file,
            .target = b.standardTargetOptions(.{}),
            .optimize = b.standardOptimizeOption(.{}),
        }),
    });

    b.installArtifact(exe);
}
