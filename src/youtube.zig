const base = "https://youtube.googleapis.com/youtube/v3";

const VideoStatisticsResponse = struct {
    items: []struct {
        id: []const u8,
        statistics: struct {
            viewCount: u64,
            likeCount: u64,
            commentCount: u64,
        },
    },
};

/// Fetches statistics for given video IDs using the YouTube Data API v3.
pub fn fetchVideoStatistics(
    client: *std.http.Client,
    gpa: std.mem.Allocator,
    key: []const u8,
    video_ids: []const u8,
) !std.json.Parsed(VideoStatisticsResponse) {
    const url = try std.fmt.allocPrint(gpa, "{s}/videos?part=statistics&id={s}&key={s}", .{ base, video_ids, key });
    defer gpa.free(url);

    var response_writer = std.Io.Writer.Allocating.init(gpa);
    defer response_writer.deinit();
    return fetchAndParse(client, gpa, &response_writer, url, VideoStatisticsResponse);
}

test fetchVideoStatistics {
    _ = &fetchVideoStatistics;
}

fn fetchAndParse(
    client: *std.http.Client,
    gpa: std.mem.Allocator,
    writer: *std.Io.Writer.Allocating,
    url: []const u8,
    comptime T: type,
) !std.json.Parsed(T) {
    const result = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .headers = .{ .accept_encoding = .{ .override = "application/json" } },
        .response_writer = &writer.writer,
    });
    if (result.status != .ok)
        return error.HttpError;

    const response_str = writer.written();
    return std.json.parseFromSlice(T, gpa, response_str, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidResponse,
    };
}

test fetchAndParse {
    _ = &fetchAndParse;
}

const std = @import("std");
