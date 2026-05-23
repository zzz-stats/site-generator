arena: std.heap.ArenaAllocator,
info: Info,
stats: Stats,

pub fn deinit(agent: *Agent) void {
    agent.arena.deinit();
}

pub fn read(io: std.Io, gpa: std.mem.Allocator, dir: std.Io.Dir, filename: []const u8) !Agent {
    const content = try dir.readFileAlloc(io, filename, gpa, .unlimited);
    defer gpa.free(content);

    return readFromString(gpa, filename, content);
}

pub fn readFromString(gpa: std.mem.Allocator, filename: []const u8, str: []const u8) !Agent {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_allocator.allocator();
    errdefer arena_allocator.deinit();

    const Json = struct {
        info: Info,
        stats: Stats = .{},
    };

    var scanner = std.json.Scanner.initCompleteInput(gpa, str);
    defer scanner.deinit();

    var diagnostics = std.json.Scanner.Diagnostics{};
    scanner.enableDiagnostics(&diagnostics);

    var res = std.json.parseFromTokenSourceLeaky(Json, arena, &scanner, .{
        .allocate = .alloc_always,
    }) catch |err| {
        std.log.err("Failed to parse {s}:{}:{}: {s}", .{
            filename, diagnostics.getLine(), diagnostics.getColumn(), @errorName(err),
        });
        return err;
    };
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
    return std.json.Stringify.value(
        agent,
        .{
            .whitespace = .indent_2,
            .emit_null_optional_fields = false,
        },
        writer,
    );
}

pub fn jsonStringify(agent: Agent, stringify: *std.json.Stringify) !void {
    const Json = struct {
        info: Info,
        stats: ?Stats,
    };
    return stringify.write(Json{
        .info = agent.info,
        .stats = if (agent.stats.hasData()) agent.stats else null,
    });
}

fn testReadAndWriteSame(json: []const u8) !void {
    return testReadAndWriteDiff(json, json);
}

fn testReadAndWriteDiff(input: []const u8, expected: []const u8) !void {
    const gpa = std.testing.allocator;
    var agent1 = try readFromString(gpa, "test.json", input);
    defer agent1.deinit();

    var writer = std.Io.Writer.Allocating.init(gpa);
    defer writer.deinit();

    try agent1.writeToWriter(&writer.writer);
    try std.testing.expectEqualStrings(expected, writer.written());

    var agent2 = try readFromString(gpa, "test.json", writer.written());
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
        \\    "name": "Test Agent"
        \\  }
        \\}
    );
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "youtube_cn": {
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
        \\    "youtube_cn": {
        \\      "ep": "aaaaaaaaaaa"
        \\    },
        \\    "youtube_en": {
        \\      "ep": "bbbbbbbbbbb"
        \\    }
        \\  }
        \\}
    );
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "youtube_cn": {
        \\      "ep": "aaaaaaaaaaa"
        \\    },
        \\    "youtube_en": {
        \\      "ep": "bbbbbbbbbbb"
        \\    },
        \\    "youtube_jp": {
        \\      "ep": "ccccccccccc"
        \\    }
        \\  }
        \\}
    );
    try testReadAndWriteSame(
        \\{
        \\  "info": {
        \\    "id": "test-agent",
        \\    "name": "Test Agent",
        \\    "youtube_cn": {
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
        \\    "youtube_cn": {
        \\      "ep": "aaaaaaaaaaa"
        \\    }
        \\  },
        \\  "stats": {
        \\    "youtube_cn": {
        \\      "ep": {
        \\        "date": [
        \\          "2024-01-01T00:00:00Z"
        \\        ],
        \\        "view_count": [
        \\          123
        \\        ],
        \\        "like_count": [
        \\          456
        \\        ],
        \\        "comment_count": [
        \\          789
        \\        ]
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
        \\    "youtube_cn": {
        \\      "ep": "aaaaaaaaaaa"
        \\    },
        \\    "youtube_en": {
        \\      "ep": "bbbbbbbbbbb"
        \\    }
        \\  },
        \\  "stats": {
        \\    "youtube_cn": {
        \\      "ep": {
        \\        "date": [
        \\          "2024-01-01T00:00:00Z"
        \\        ],
        \\        "view_count": [
        \\          123
        \\        ],
        \\        "like_count": [
        \\          456
        \\        ],
        \\        "comment_count": [
        \\          789
        \\        ]
        \\      }
        \\    },
        \\    "youtube_en": {
        \\      "ep": {
        \\        "date": [
        \\          "2024-01-01T00:00:00Z"
        \\        ],
        \\        "view_count": [
        \\          321
        \\        ],
        \\        "like_count": [
        \\          654
        \\        ],
        \\        "comment_count": [
        \\          987
        \\        ]
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
        \\    "youtube_cn": {
        \\      "ep": "aaaaaaaaaaa"
        \\    },
        \\    "youtube_en": {
        \\      "ep": "bbbbbbbbbbb"
        \\    },
        \\    "youtube_jp": {
        \\      "ep": "ccccccccccc"
        \\    }
        \\  },
        \\  "stats": {
        \\    "youtube_cn": {
        \\      "ep": {
        \\        "date": [
        \\          "2024-01-01T00:00:00Z"
        \\        ],
        \\        "view_count": [
        \\          123
        \\        ],
        \\        "like_count": [
        \\          456
        \\        ],
        \\        "comment_count": [
        \\          789
        \\        ]
        \\      }
        \\    },
        \\    "youtube_en": {
        \\      "ep": {
        \\        "date": [
        \\          "2024-01-01T00:00:00Z"
        \\        ],
        \\        "view_count": [
        \\          321
        \\        ],
        \\        "like_count": [
        \\          654
        \\        ],
        \\        "comment_count": [
        \\          987
        \\        ]
        \\      }
        \\    },
        \\    "youtube_jp": {
        \\      "ep": {
        \\        "date": [
        \\          "2024-01-01T00:00:00Z"
        \\        ],
        \\        "view_count": [
        \\          231
        \\        ],
        \\        "like_count": [
        \\          564
        \\        ],
        \\        "comment_count": [
        \\          897
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

    // For all agent json files, call `readFetchAndWrite` concurrently
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
    const info_youtube_fields = comptime blk: {
        var res: []const []const u8 = &.{};
        for (@typeInfo(Info).@"struct".fields) |info_field| {
            if (!std.mem.startsWith(u8, info_field.name, "youtube_"))
                continue;
            res = res ++ [_][]const u8{info_field.name};
        }

        const res_copy = res[0..res.len].*;
        break :blk res_copy;
    };

    // Get all youtube ids into a single comma seperated string. Will be used to request video
    // statistics for all videos of this agent.
    var video_ids = std.Io.Writer.Allocating.init(args.gpa);
    defer video_ids.deinit();

    var ids_count: usize = 0;
    inline for (info_youtube_fields) |info_field| {
        const youtube_info = &@field(agent.info, info_field);

        inline for (youtube_fields) |field| continue_blk: {
            const video_id = @field(youtube_info, field.name) orelse break :continue_blk;
            try video_ids.writer.print("{s}{s}", .{ if (ids_count == 0) "" else ",", video_id });
            ids_count += 1;
        }
    }

    const response = try youtube.fetchVideoStatistics(args.client, args.gpa, args.youtube_api_key, video_ids.written());
    defer response.deinit();

    var response_index: usize = 0;
    inline for (info_youtube_fields) |info_field| {
        const youtube_info = &@field(agent.info, info_field);
        const youtube_stats = &@field(agent.stats, info_field);

        inline for (youtube_fields) |field| continue_blk: {
            const video_id = @field(youtube_info, field.name) orelse break :continue_blk;

            const response_item = blk: {
                for (response.value.items) |*item| {
                    if (std.mem.eql(u8, item.id, video_id))
                        break :blk item;
                }

                std.log.err("Failed to fetch '{s}.{s}.{s}'", .{ agent.info.id, info_field, field.name });
                return error.InvalidResponse;
            };

            const list = &@field(youtube_stats, field.name);
            try list.items.append(agent.arena.allocator(), .{
                .date = args.date,
                .view_count = response_item.statistics.viewCount,
                .like_count = response_item.statistics.likeCount,
                .comment_count = response_item.statistics.commentCount,
            });

            response_index += 1;
        }
    }
}

const Agent = @This();

pub const Info = @import("Agent/Info.zig");
pub const Stats = @import("Agent/Stats.zig");

const youtube = @import("youtube.zig");
const std = @import("std");
