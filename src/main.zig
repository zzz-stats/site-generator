pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2)
        return error.NotEnoughArguments;

    const youtube_api_key = init.environ_map.get("ZZZ_STATS_YOUTUBE_API_KEY") orelse return error.MissingKey;

    const date = blk: {
        const date_process_result = try std.process.run(init.arena.allocator(), init.io, .{
            .argv = &[_][]const u8{ "date", "-u", "+%Y-%m-%dT%H:%M:%SZ" },
        });
        const date_process_stdout = std.mem.trim(u8, date_process_result.stdout, "\n\r");
        break :blk try Agent.Stats.Date.parse(date_process_stdout);
    };

    var client = std.http.Client{
        .io = init.io,
        .allocator = init.gpa,
    };
    defer client.deinit();

    const path = args[1];
    const cwd = std.Io.Dir.cwd();
    if (cwd.openDir(io, path, .{ .iterate = false })) |dir| {
        defer dir.close(io);

        try Agent.readFetchAndWriteEntireDirectory(dir, .{
            .io = io,
            .gpa = init.gpa,
            .client = &client,
            .date = date,
            .youtube_api_key = youtube_api_key,
        });
    } else |_| {
        const dirname = std.fs.path.dirname(path) orelse ".";
        const basename = std.fs.path.basename(path);

        const dir = try cwd.openDir(io, dirname, .{});
        defer dir.close(io);

        try Agent.readFetchAndWrite(dir, basename, .{
            .io = io,
            .gpa = init.gpa,
            .client = &client,
            .date = date,
            .youtube_api_key = youtube_api_key,
        });
    }
}

test main {
    _ = &main;

    _ = @import("Agent/Info.zig");
    _ = @import("Agent/Stats.zig");
    _ = @import("Agent.zig");
    _ = @import("youtube.zig");
}

const Agent = @import("Agent.zig");
const datetime = @import("datetime");
const youtube = @import("youtube.zig");
const std = @import("std");
