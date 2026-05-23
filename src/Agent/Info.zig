id: []const u8,
name: []const u8,
youtube_cn: Youtube = .{},
youtube_en: Youtube = .{},
youtube_jp: Youtube = .{},

pub fn jsonStringify(info: Info, stringify: *std.json.Stringify) !void {
    const Json = struct {
        id: []const u8,
        name: []const u8,
        youtube_cn: ?Youtube,
        youtube_en: ?Youtube,
        youtube_jp: ?Youtube,
    };
    return stringify.write(Json{
        .id = info.id,
        .name = info.name,
        .youtube_cn = if (info.youtube_cn.hasData()) info.youtube_cn else null,
        .youtube_en = if (info.youtube_en.hasData()) info.youtube_en else null,
        .youtube_jp = if (info.youtube_jp.hasData()) info.youtube_jp else null,
    });
}

pub const Youtube = struct {
    ep: ?[]const u8 = null,
    demo: ?[]const u8 = null,
    record: ?[]const u8 = null,
    teaser: ?[]const u8 = null,
    for_display_only: ?[]const u8 = null,
    exclusive_channel: ?[]const u8 = null,
    plastic_wrapped_journal: ?[]const u8 = null,

    pub fn hasData(youtube: Youtube) bool {
        inline for (@typeInfo(Youtube).@"struct".fields) |field| {
            if (@field(youtube, field.name) != null)
                return true;
        }
        return false;
    }
};

const Info = @This();

const Agent = @import("../Agent.zig");
const Stats = @import("Stats.zig");

const std = @import("std");
