pub fn main(init: std.process.Init) !void {
    var client = std.http.Client{
        .io = init.io,
        .allocator = init.gpa,
    };
    defer client.deinit();

    const key = init.environ_map.get("ZZZ_STATS_YOUTUBE_API_KEY") orelse return error.MissingKey;
    const stats = try youtube.fetchVideoStatistics(&client, init.gpa, key, "C5WS9Ohb-fI");
    std.debug.print("Views: {d}\nLikes: {d}\nComments: {d}\n", .{
        stats.views,
        stats.likes,
        stats.comments,
    });
}

test main {
    _ = &main;
}

const youtube = @import("youtube.zig");
const std = @import("std");
