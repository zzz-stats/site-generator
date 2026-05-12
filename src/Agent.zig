id: []const u8,
name: []const u8,
videos: struct {
    youtube: struct {
        ep: ?[]const u8 = null,
        demo: ?[]const u8 = null,
        record: ?[]const u8 = null,
        teaser: ?[]const u8 = null,
        for_display_only: ?[]const u8 = null,
        exclusive_channel: ?[]const u8 = null,
    },
},

pub const Stats = struct {
    videos: struct {
        youtube: struct {
            ep: std.MultiArrayList(Youtube) = .empty,
            demo: std.MultiArrayList(Youtube) = .empty,
            record: std.MultiArrayList(Youtube) = .empty,
            teaser: std.MultiArrayList(Youtube) = .empty,
            for_display_only: std.MultiArrayList(Youtube) = .empty,
            exclusive_channel: std.MultiArrayList(Youtube) = .empty,
        } = .{},
    } = .{},

    pub const Youtube = struct {
        date: []const u8,
        views: u64,
        likes: u64,
        comments: u64,
    };
};

pub const all = [_]Agent{
    .{
        .id = "anby-demara",
        .name = "Anby Demara",
        .videos = .{
            .youtube = .{
                .teaser = "ILLiFFHEXvw",
                .demo = "Y2HTc9JZvwc",
            },
        },
    },
};

const Agent = @This();

const youtube = @import("youtube.zig");
const std = @import("std");
