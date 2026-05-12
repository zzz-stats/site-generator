info: Agent,
stats: Stats,

pub const Info = struct {
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
        } = .{},
    },

    pub fn loadStats(info: Info, io: std.Io, gpa: std.mem.Allocator, dir: std.Io.Dir) !Agent {
        var filename_buf: [std.Io.Dir.max_name_bytes]u8 = undefined;
        const filename = std.fmt.bufPrint(&filename_buf, "{}.json", .{info.id});

        const content = try dir.readFileAlloc(io, filename, gpa, .unlimited) catch |err| switch (err) {
            error.FileNotFound => return Agent{ .info = info, .stats = .{} },
            else => |e| return e,
        };
        defer gpa.free(content);

        return info.loadFromString(gpa, content);
    }

    pub fn loadStatsFromString(info: Info, gpa: std.mem.Allocator, str: []const u8) !Agent {
        var res = Agent{
            .info = info,
            .stats = .{},
        };
        errdefer res.deinit(gpa);

        const json_root = try std.json.parseFromSlice(std.json.Value, gpa, str);
        defer json_root.deinit();

        const json_root_object = switch (json_root.value) {
            .object => |o| o,
            else => return error.InvalidJson,
        };

        const json_info_value = json_root_object.get("info") orelse return error.InvalidJson;
        const json_stats_value = json_root_object.get("stats") orelse return error.InvalidJson;

        // Parse info, just to validate it is correct
        const parsed_info = try std.json.parseFromValue(info, gpa, json_info_value, .{});
        defer parsed_info.deinit();

        const json_stats_object = switch (json_stats_value) {
            .object => |o| o,
            else => return error.InvalidJson,
        };

        const json_videos_value = json_stats_object.get("videos") orelse return error.InvalidJson;
        const json_videos_object = switch (json_videos_value) {
            .object => |o| o,
            else => return error.InvalidJson,
        };

        const json_youtube_value = json_videos_object.get("youtube") orelse return error.InvalidJson;
        const json_youtube_object = switch (json_youtube_value) {
            .object => |o| o,
            else => return error.InvalidJson,
        };

        // Format of each youtube field is:
        // "ep": {
        //   dates: ["2023-01-01T12:00:00Z", "2023-01-01T12:01:00Z", ...],
        //   views: [100, 150, ...],
        //   likes: [10, 15, ...],
        //   comments: [5, 7, ...],
        // }
        for (@typeInfo(Stats.Videos.Youtube.Video).@"struct".fields) |field| {
            const list: *Stats.Videos.Youtube.List = &@field(res.stats.videos.youtube, field.name);

            const json_field_value = json_youtube_object.get(field.name) orelse return error.InvalidJson;
            const json_field_object = switch (json_field_value) {
                .object => |o| o,
                else => return error.InvalidJson,
            };

            for (@typeInfo(Stats.Videos.Youtube.Video).@"struct".fields, 0..) |subfield, subfield_i| {
                const json_subfield_value = json_field_object.get(subfield.name) orelse return error.InvalidJson;
                const json_subfield_array = switch (json_subfield_value) {
                    .array => |a| a,
                    else => return error.InvalidJson,
                };

                if (subfield_i == 0) {
                    // On the first field, set the list length
                    try list.resize(gpa, json_subfield_array.items.len);
                } else {
                    // On subsequent fields, validate the length matches
                    if (json_subfield_array.items.len != list.items.len)
                        return error.InvalidJson;
                }

                for (json_subfield_array.items, 0..) |item, item_i| {
                    const ListField = Stats.Videos.Youtube.Video.List.Field;
                    list.items(@field(ListField, subfield.name))[item_i] = switch (item) {
                        .string => |s| switch (subfield.type) {
                            Stats.Videos.Youtube.Date => value,
                            else => return error.InvalidJson,
                        },
                        .integer => |value| switch (subfield.type) {
                            u64 => value,
                            else => return error.InvalidJson,
                        },
                        else => return error.InvalidJson,
                    };
                }
            }
        }

        return res;
    }
};

pub const Stats = struct {
    videos: Videos,

    const Videos = struct {
        youtube: Youtube,

        pub const Youtube = struct {
            ep: List = .empty,
            demo: List = .empty,
            record: List = .empty,
            teaser: List = .empty,
            for_display_only: List = .empty,
            exclusive_channel: List = .empty,

            pub const Video = struct {
                date: Date,
                views: u64,
                likes: u64,
                comments: u64,
            };

            pub const Date = packed struct {
                year: u16,
                month: std.math.IntFittingRange(0, 12),
                day: std.math.IntFittingRange(0, 31),
                hour: std.math.IntFittingRange(0, 60),
                minute: std.math.IntFittingRange(0, 60),
                second: std.math.IntFittingRange(0, 60),
            };

            pub const List = std.MultiArrayList(Video);
        };
    };
};

pub const all = [_]Info{
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

const std = @import("std");
