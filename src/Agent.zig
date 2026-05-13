arena: std.heap.ArenaAllocator,
info: Info,
stats: Stats,

pub fn deinit(agent: *Agent) void {
    agent.arena.deinit();
}

pub fn read(io: std.Io, gpa: std.mem.Allocator, dir: std.Io.Dir, filename: []const u8) !Agent {
    const content = try dir.readFileAlloc(io, filename, gpa, .unlimited);
    defer gpa.free(content);

    return readFromString(gpa, content);
}

pub fn readFromString(gpa: std.mem.Allocator, str: []const u8) !Agent {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_allocator.allocator();
    errdefer arena_allocator.deinit();

    const Json = struct {
        info: Info,
        stats: Stats = .{},
    };
    var res = try std.json.parseFromSliceLeaky(Json, arena, str, .{ .allocate = .alloc_always });
    errdefer res.deinit();

    return .{
        .arena = arena_allocator,
        .info = res.info,
        .stats = res.stats,
    };
}

pub fn write(agent: Agent, io: std.Io, dir: std.Io.Dir) !void {
    var filename_buf: [std.Io.Dir.max_name_bytes]u8 = undefined;
    const filename = std.fmt.bufPrint(&filename_buf, "{}.json", .{agent.info.id});

    const file = try dir.createFileAtomic(io, filename, .{ .replace = true });
    defer file.deinit();

    try agent.writeToFile(io, file.file);
    try file.replace();
}

pub fn writeToFile(agent: Agent, io: std.Io, file: std.Io.File) !void {
    var buf: [4096]u8 = undefined;
    var writer = file.writer(io, &buf);
    try agent.writeToWriter(&writer.interface);
    try writer.end();
}

pub fn writeToWriter(agent: Agent, writer: *std.Io.Writer) !void {
    const Json = struct {
        info: Info,
        stats: ?Stats,
    };
    return std.json.Stringify.value(
        Json{
            .info = agent.info,
            .stats = if (agent.stats.hasData()) agent.stats else null,
        },
        .{
            .whitespace = .indent_2,
            .emit_null_optional_fields = false,
        },
        writer,
    );
}

fn testReadAndWriteSame(json: []const u8) !void {
    return testReadAndWriteDiff(json, json);
}

fn testReadAndWriteDiff(input: []const u8, expected: []const u8) !void {
    const gpa = std.testing.allocator;
    var agent1 = try readFromString(gpa, input);
    defer agent1.deinit();

    var writer = std.Io.Writer.Allocating.init(gpa);
    defer writer.deinit();

    try agent1.writeToWriter(&writer.writer);
    try std.testing.expectEqualStrings(expected, writer.written());

    var agent2 = try readFromString(gpa, writer.written());
    defer agent2.deinit();

    writer.clearRetainingCapacity();
    try agent2.writeToWriter(&writer.writer);
    try std.testing.expectEqualStrings(expected, writer.written());
}

test testReadAndWriteSame {
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "videos": {
        \\      "youtube": {}
        \\    }
        \\  }
        \\}
    );
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "videos": {
        \\      "youtube": {
        \\        "ep": "aaaaaaaaaaa"
        \\      }
        \\    }
        \\  }
        \\}
    );
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "videos": {
        \\      "youtube": {
        \\        "ep": "aaaaaaaaaaa",
        \\        "demo": "aaaaaaaaaaa",
        \\        "record": "aaaaaaaaaaa",
        \\        "teaser": "aaaaaaaaaaa",
        \\        "for_display_only": "aaaaaaaaaaa",
        \\        "exclusive_channel": "aaaaaaaaaaa"
        \\      }
        \\    }
        \\  }
        \\}
    );
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "videos": {
        \\      "youtube": {
        \\        "ep": "aaaaaaaaaaa"
        \\      }
        \\    }
        \\  },
        \\  "stats": {
        \\    "videos": {
        \\      "youtube": {
        \\        "ep": {
        \\          "date": [
        \\            "2024-01-01T00:00:00Z"
        \\          ],
        \\          "views": [
        \\            123
        \\          ],
        \\          "likes": [
        \\            456
        \\          ],
        \\          "comments": [
        \\            789
        \\          ]
        \\        }
        \\      }
        \\    }
        \\  }
        \\}
    );
}

pub const FetchStatsArguments = struct {
    io: std.Io,
    gpa: std.mem.Allocator,
    client: *std.http.Client,
    youtube_api_key: []const u8,
};

pub fn fetchStats(agent: *Agent, args: FetchStatsArguments) !void {
    try agent.fetchYoutubeStats(args);
}

pub fn fetchYoutubeStats(agent: *Agent, args: FetchStatsArguments) !void {
    const youtube_fields = @typeInfo(Info.Videos.YouTube).@"struct".fields;
    const youtube_info = &argent.info.videos.youtube;
    const youtube_stats = &argent.stats.videos.youtube;

    var futures: [youtube_fields.len]std.Thread.Future(!void) = undefined;
}

const Agent = @This();

pub const Info = @import("Agent/Info.zig");
pub const Stats = @import("Agent/Stats.zig");

const youtube = @import("youtube.zig");
const std = @import("std");
