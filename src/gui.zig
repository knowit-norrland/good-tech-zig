const std = @import("std");
const md = @import("md.zig");

const c = @cImport({
    @cInclude("raylib.h");
});

var buffer: [2048]u8 = .{0} ** 2048;

pub fn drawText(str: []const u8, x: f32, y: f32, h: i32) void {
    //TODO: det här är egenligen inte så unreachable :^)
    const slice = std.fmt.bufPrintZ(&buffer, "{s}", .{str}) catch unreachable;
    c.DrawText(slice, @intFromFloat(x), @intFromFloat(y), h, c.Color{
        .r = 255,
        .g = 255,
        .b = 255,
        .a = 255,
    });
}

pub fn drawRoot(root: md.Root) void {
    const b = bounds(root);
    const x_start = @as(f32, @floatFromInt(c.GetRenderWidth())) / 2 - b.x / 2;
    const y_start: f32 = 0;

    for (0.., root.nodes) |idx, node| {
        const x = x_start;
        const y = y_start + @as(f32, @floatFromInt(32 * idx));

        std.debug.print("{d}x{d}\n", .{ b.x, b.y });
        switch (node) {
            .header => |header| {
                drawText(header.value, x, y, 32);
            },
            .text => |text| {
                drawText(text.value, x, y, 32);
            },
            .list => |list| {
                for (list.nodes) |listnode| {
                    drawText(listnode.text.value, x, y, 32);
                }
            },
            .codeblock => |block| {
                drawText(block.code, x, y, 32);
            },
        }
    }
}

pub fn bounds(root: md.Root) c.Vector2 {
    return nodesBounds(root.nodes);
}

fn nodesBounds(nodes: []const md.Node) c.Vector2 {
    var w: f32 = 0;
    var height: f32 = 0;

    for (nodes) |node| {
        const node_bounds = switch (node) {
            .text => |t| strBounds(t.value),
            .header => |h| strBounds(h.value),
            .list => |l| nodesBounds(l.nodes),
            .codeblock => unreachable,
        };

        if (w < node_bounds.x) {
            w = node_bounds.x;
        }
        height += node_bounds.y;
    }

    return .{
        .x = w,
        .y = height,
    };
}

fn strBounds(str: []const u8) c.Vector2 {
    const slice = std.fmt.bufPrintZ(&buffer, "{s}", .{str}) catch unreachable;
    const text_width = c.MeasureText(slice, 32);
    return .{
        .x = @floatFromInt(text_width),
        .y = 32,
    };
}
