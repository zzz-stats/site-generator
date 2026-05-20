youtube_cn: Youtube = .{},
youtube_en: Youtube = .{},
youtube_jp: Youtube = .{},

pub fn jsonStringify(stats: Stats, stringify: *std.json.Stringify) !void {
    const Json = struct {
        youtube_cn: ?Youtube,
        youtube_en: ?Youtube,
        youtube_jp: ?Youtube,
    };
    return stringify.write(Json{
        .youtube_cn = if (stats.youtube_cn.hasData()) stats.youtube_cn else null,
        .youtube_en = if (stats.youtube_en.hasData()) stats.youtube_en else null,
        .youtube_jp = if (stats.youtube_jp.hasData()) stats.youtube_jp else null,
    });
}

pub fn hasData(stats: Stats) bool {
    return stats.youtube_cn.hasData() or stats.youtube_en.hasData() or stats.youtube_jp.hasData();
}

pub const Youtube = struct {
    ep: List = .{},
    demo: List = .{},
    record: List = .{},
    teaser: List = .{},
    for_display_only: List = .{},
    exclusive_channel: List = .{},

    pub fn deinit(youtube: *Youtube, gpa: std.mem.Allocator) void {
        youtube.ep.items.deinit(gpa);
        youtube.demo.items.deinit(gpa);
        youtube.record.items.deinit(gpa);
        youtube.for_display_only.items.deinit(gpa);
        youtube.exclusive_channel.items.deinit(gpa);
    }

    pub fn hasData(youtube: Youtube) bool {
        return youtube.ep.items.len > 0 or
            youtube.demo.items.len > 0 or
            youtube.record.items.len > 0 or
            youtube.teaser.items.len > 0 or
            youtube.for_display_only.items.len > 0 or
            youtube.exclusive_channel.items.len > 0;
    }

    pub fn jsonStringify(youtube: Youtube, stringify: *std.json.Stringify) !void {
        const Json = struct {
            ep: ?List,
            demo: ?List,
            record: ?List,
            teaser: ?List,
            for_display_only: ?List,
            exclusive_channel: ?List,
        };
        return stringify.write(Json{
            .ep = if (youtube.ep.items.len > 0) youtube.ep else null,
            .demo = if (youtube.demo.items.len > 0) youtube.demo else null,
            .record = if (youtube.record.items.len > 0) youtube.record else null,
            .teaser = if (youtube.teaser.items.len > 0) youtube.teaser else null,
            .for_display_only = if (youtube.for_display_only.items.len > 0) youtube.for_display_only else null,
            .exclusive_channel = if (youtube.exclusive_channel.items.len > 0) youtube.exclusive_channel else null,
        });
    }

    pub const Video = struct {
        date: Date,
        views: u64,
        likes: u64,
        comments: u64,
    };

    pub const List = struct {
        items: std.MultiArrayList(Video) = .empty,

        pub fn jsonStringify(list: List, stringify: *std.json.Stringify) !void {
            const Json = struct {
                date: []const Date,
                views: []const u64,
                likes: []const u64,
                comments: []const u64,
            };
            return stringify.write(Json{
                .date = list.items.items(.date),
                .views = list.items.items(.views),
                .likes = list.items.items(.likes),
                .comments = list.items.items(.comments),
            });
        }

        pub fn jsonParse(
            allocator: std.mem.Allocator,
            source: anytype,
            options: std.json.ParseOptions,
        ) std.json.ParseError(@TypeOf(source.*))!List {
            const Json = struct {
                date: []const Date,
                views: []const u64,
                likes: []const u64,
                comments: []const u64,
            };
            const json = try std.json.innerParse(Json, allocator, source, options);

            var res = List{};
            errdefer res.items.deinit(allocator);

            const len = @min(json.date.len, json.views.len, json.likes.len, json.comments.len);
            try res.items.resize(allocator, len);
            @memcpy(res.items.items(.date), json.date[0..len]);
            @memcpy(res.items.items(.views), json.views[0..len]);
            @memcpy(res.items.items(.likes), json.likes[0..len]);
            @memcpy(res.items.items(.comments), json.comments[0..len]);

            return res;
        }
    };
};

pub const Date = packed struct {
    year: YearInt,
    month: MonthInt,
    day: DayInt,
    hour: HourInt,
    minute: MinuteInt,
    second: SecondInt,

    const YearInt = std.math.IntFittingRange(0, 9999);
    const MonthInt = std.math.IntFittingRange(0, 12);
    const DayInt = std.math.IntFittingRange(0, 31);
    const HourInt = std.math.IntFittingRange(0, 24);
    const MinuteInt = std.math.IntFittingRange(0, 60);
    const SecondInt = std.math.IntFittingRange(0, 60);

    pub fn parse(str: []const u8) !Date {
        return parseInner(str) catch return error.InvalidDateFormat;
    }

    fn parseInner(str: []const u8) !Date {
        // Expected format is "2023-01-01T12:00:00Z"
        const invalid_str = str.len != 20 or
            str[4] != '-' or str[7] != '-' or str[10] != 'T' or
            str[13] != ':' or str[16] != ':' or str[19] != 'Z';
        if (invalid_str)
            return error.InvalidDateFormat;

        return Date{
            .year = try std.fmt.parseUnsigned(YearInt, str[0..4], 10),
            .month = try std.fmt.parseUnsigned(MonthInt, str[5..7], 10),
            .day = try std.fmt.parseUnsigned(DayInt, str[8..10], 10),
            .hour = try std.fmt.parseUnsigned(HourInt, str[11..13], 10),
            .minute = try std.fmt.parseUnsigned(MinuteInt, str[14..16], 10),
            .second = try std.fmt.parseUnsigned(SecondInt, str[17..19], 10),
        };
    }

    test parse {
        try std.testing.expectEqual(Date{
            .year = 1234,
            .month = 12,
            .day = 23,
            .hour = 24,
            .minute = 43,
            .second = 32,
        }, try Date.parse("1234-12-23T24:43:32Z"));
        try std.testing.expectError(error.InvalidDateFormat, Date.parse("2023-01-01T12:00:00"));
        try std.testing.expectError(error.InvalidDateFormat, Date.parse("invalid"));
    }

    pub fn jsonStringify(date: Date, stringify: *std.json.Stringify) !void {
        try stringify.print("\"{d:04}-{d:02}-{d:02}T{d:02}:{d:02}:{d:02}Z\"", .{
            date.year,
            date.month,
            date.day,
            date.hour,
            date.minute,
            date.second,
        });
    }

    pub fn jsonParse(
        allocator: std.mem.Allocator,
        source: anytype,
        options: std.json.ParseOptions,
    ) std.json.ParseError(@TypeOf(source.*))!Date {
        _ = options;
        switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
            .string, .allocated_string => |str| return Date.parse(str) catch return error.UnexpectedToken,
            else => return error.UnexpectedToken,
        }
    }
};

test Date {
    _ = &Date;
}

const Stats = @This();

const std = @import("std");
