pub const Video = struct {
    pub const Statistics = struct {
        views: u64,
        likes: u64,
        comments: u64,
    };
};

pub fn fetchVideoStatistics(
    client: *std.http.Client,
    gpa: std.mem.Allocator,
    key: []const u8,
    id: []const u8,
) !Video.Statistics {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_allocator.allocator();
    defer arena_allocator.deinit();

    const base = "https://youtube.googleapis.com/youtube/v3";
    const endpoint = "videos";
    const part = "statistics";

    const url = try std.fmt.allocPrint(arena, "{s}/{s}?part={s}&id={s}&key={s}", .{ base, endpoint, part, id, key });

    var response_writer = std.Io.Writer.Allocating.init(gpa);
    defer response_writer.deinit();

    const result = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .headers = .{
            .accept_encoding = .{ .override = "application/json" },
        },
        .response_writer = &response_writer.writer,
    });
    if (result.status != .ok)
        return error.HttpError;

    const Response = struct {
        items: []struct {
            statistics: struct {
                viewCount: u64,
                likeCount: u64,
                commentCount: u64,
            },
        },
    };

    const response_str = response_writer.written();
    const response = std.json.parseFromSliceLeaky(Response, arena, response_str, .{
        .ignore_unknown_fields = true,
    }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidResponse,
    };
    if (response.items.len == 0)
        return error.InvalidResponse;

    return .{
        .views = response.items[0].statistics.viewCount,
        .likes = response.items[0].statistics.likeCount,
        .comments = response.items[0].statistics.commentCount,
    };
}

test fetchVideoStatistics {
    _ = &fetchVideoStatistics;
}

const std = @import("std");
