const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;
    const target = mb.ports.rp2xxx.boards.raspberrypi.pico;
    const optimize = b.standardOptimizeOption(.{});

    const ir_dep = b.dependency("ir", .{});

    const remote_control = mb.add_firmware(
        .{
            .name = "remote_control",
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/remote_control.zig"),
            .imports = &.{
                .{ .name = "ir", .module = ir_dep.module("ir") },
            },
        },
    );

    mb.install_firmware(remote_control, .{});

    const reader = mb.add_firmware(
        .{
            .name = "reader",
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/reader.zig"),
            .imports = &.{
                .{ .name = "ir", .module = ir_dep.module("ir") },
            },
        },
    );

    mb.install_firmware(reader, .{});
}
