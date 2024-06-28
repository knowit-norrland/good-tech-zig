const std = @import("std");

const c = @cImport({
    @cInclude("raylib.h");
});

var buffer: [2048]u8 = .{0} ** 2048;

pub fn drawText(str: []const u8, x: u32, y: u32, h: u32) void {
    //TODO: det här är egenligen inte så unreachable :^)
    const slice = std.fmt.bufPrintZ(&buffer, "{s}", .{str}) catch unreachable;
    c.DrawText(slice, @intCast(x), @intCast(y), @intCast(h), c.Color{
        .r = 255,
        .g = 255,
        .b = 255,
        .a = 255,
    });
}
