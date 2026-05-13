id: []const u8,
name: []const u8,
videos: Videos = .{},

pub const Videos = struct {
    youtube: Youtube = .{},

    pub const Youtube = struct {
        ep: ?[]const u8 = null,
        demo: ?[]const u8 = null,
        record: ?[]const u8 = null,
        teaser: ?[]const u8 = null,
        for_display_only: ?[]const u8 = null,
        exclusive_channel: ?[]const u8 = null,
    };
};

const Info = @This();

const Agent = @import("../Agent.zig");
const Stats = @import("Stats.zig");

const std = @import("std");
