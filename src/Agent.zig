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
    const filename = try std.fmt.bufPrint(&filename_buf, "{s}.json", .{agent.info.id});

    var file = try dir.createFileAtomic(io, filename, .{ .replace = true });
    defer file.deinit(io);

    try agent.writeToFile(io, file.file);
    try file.replace(io);
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
        \\    "youtube": {}
        \\  }
        \\}
    );
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "youtube": {
        \\      "ep": "aaaaaaaaaaa"
        \\    }
        \\  }
        \\}
    );
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "youtube": {
        \\      "ep": "aaaaaaaaaaa",
        \\      "demo": "aaaaaaaaaaa",
        \\      "record": "aaaaaaaaaaa",
        \\      "teaser": "aaaaaaaaaaa",
        \\      "for_display_only": "aaaaaaaaaaa",
        \\      "exclusive_channel": "aaaaaaaaaaa"
        \\    }
        \\  }
        \\}
    );
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "youtube": {
        \\      "ep": "aaaaaaaaaaa"
        \\    }
        \\  },
        \\  "stats": {
        \\    "youtube": {
        \\      "ep": {
        \\        "date": [
        \\          "2024-01-01T00:00:00Z"
        \\        ],
        \\        "views": [
        \\          123
        \\        ],
        \\        "likes": [
        \\          456
        \\        ],
        \\        "comments": [
        \\          789
        \\        ]
        \\      }
        \\    }
        \\  }
        \\}
    );
}

pub const FetchArgs = struct {
    io: std.Io,
    gpa: std.mem.Allocator,
    client: *std.http.Client,
    date: Stats.Date,
    youtube_api_key: []const u8,
};

pub fn readFetchAndWriteEntireDirectory(dir: std.Io.Dir, args: FetchArgs) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(args.gpa);
    const arena = arena_allocator.allocator();
    defer arena_allocator.deinit();

    const Result = @typeInfo(@TypeOf(readFetchAndWrite)).@"fn".return_type.?;
    var agents = std.ArrayList(struct { filename: []const u8, result: Result }).empty;
    defer agents.deinit(args.gpa);

    var it = dir.iterate();
    while (try it.next(args.io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        try agents.append(args.gpa, .{
            .filename = try arena.dupe(u8, entry.name),
            .result = undefined,
        });
    }

    const func = struct {
        fn func(res: *Result, d: std.Io.Dir, f: []const u8, a: FetchArgs) void {
            res.* = readFetchAndWrite(d, f, a);
        }
    }.func;

    var group = std.Io.Group.init;
    for (agents.items) |*agent|
        try group.concurrent(args.io, func, .{ &agent.result, dir, agent.filename, args });
    try group.await(args.io);

    for (agents.items) |agent|
        try agent.result;
}

pub fn readFetchAndWrite(dir: std.Io.Dir, filename: []const u8, args: FetchArgs) !void {
    var agent = try Agent.read(args.io, args.gpa, dir, filename);
    defer agent.deinit();

    try agent.fetch(args);
    try agent.write(args.io, dir);
}

pub fn fetch(agent: *Agent, args: FetchArgs) !void {
    try agent.fetchYoutube(args);
}

pub fn fetchYoutube(agent: *Agent, args: FetchArgs) !void {
    const youtube_fields = @typeInfo(Info.Youtube).@"struct".fields;
    const youtube_info = &agent.info.youtube;
    const youtube_stats = &agent.stats.youtube;

    const Result = @typeInfo(@TypeOf(fetchYoutubeVideo)).@"fn".return_type.?;
    const func = struct {
        fn func(res: *Result, a: *Agent, id: []const u8, l: *Stats.Youtube.List, ar: FetchArgs) void {
            res.* = a.fetchYoutubeVideo(id, l, ar);
        }
    }.func;

    var results: [youtube_fields.len]Result = undefined;
    var group = std.Io.Group.init;

    inline for (youtube_fields, &results) |field, *res| continue_blk: {
        const video_id = @field(youtube_info, field.name) orelse {
            res.* = {};
            break :continue_blk;
        };
        const list = &@field(youtube_stats, field.name);
        try group.concurrent(args.io, func, .{ res, agent, video_id, list, args });
    }

    try group.await(args.io);

    for (results) |res|
        try res;
}

fn fetchYoutubeVideo(agent: *Agent, video_id: []const u8, list: *Stats.Youtube.List, args: FetchArgs) !void {
    const stats = try youtube.fetchVideoStatistics(args.client, args.gpa, args.youtube_api_key, video_id);
    try list.items.append(agent.arena.allocator(), .{
        .date = args.date,
        .views = stats.views,
        .likes = stats.likes,
        .comments = stats.comments,
    });
}

const Agent = @This();

pub const Info = @import("Agent/Info.zig");
pub const Stats = @import("Agent/Stats.zig");

const youtube = @import("youtube.zig");
const std = @import("std");
