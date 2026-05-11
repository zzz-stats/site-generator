pub fn main(init: std.process.Init) !void {
    var client = std.http.Client{
        .io = init.io,
        .allocator = init.gpa,
    };
    defer client.deinit();

    try getYoutubeVideoInfo(&client, init.gpa, "KEY", "VIDEO_ID");
}

pub fn getYoutubeVideoInfo(client: *std.http.Client, gpa: std.mem.Allocator, key: []const u8, id: []const u8) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_allocator.allocator();
    defer arena_allocator.deinit();
    const base = "https://youtube.googleapis.com/youtube/v3";
    const endpoint = "videos";
    const part = "snippet%2CcontentDetails%2Cstatistics";

    const authorization_header = try std.fmt.allocPrint(arena, "Bearer {}", .{key});
    const url = try std.fmt.allocPrint(arena, "{}/{}?part={}&id={}&key={}", .{ base, endpoint, part, id, key });

    var response_writer = std.Io.Writer.Allocating.init(gpa);
    defer response_writer.deinit();

    const result = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .headers = .{
            .authorization = .{ .override = authorization_header },
            .accept_encoding = .{ .override = "application/json" },
        },
    });
    _ = result;
}

test main {
    _ = &main;
}

const std = @import("std");
