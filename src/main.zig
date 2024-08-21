const std = @import("std");
const md = @import("md.zig");
const gui = @import("gui.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var base_allocator = switch (std.debug.runtime_safety) {
        true => std.heap.GeneralPurposeAllocator(.{}){},
        false => std.heap.page_allocator,
    };
    defer std.debug.assert(base_allocator.deinit() == .ok);
    const ally = base_allocator.allocator();

    var arena = std.heap.ArenaAllocator.init(ally);
    defer arena.deinit();
    const arena_ally = arena.allocator();

    const args = try std.process.argsAlloc(arena_ally);

    var file: []const u8 = "";

    if (args.len >= 2) {
        file = args[1];
    } else {
        std.debug.print("No file specified, exiting...", .{});
        return;
    }

    const src = try std.fs.cwd().readFileAlloc(arena_ally, file, 1_000_000_000);
    const root = try md.parse(src, arena_ally);

    c.SetTraceLogLevel(c.LOG_WARNING);
    c.InitWindow(800, 600, "Window");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        gui.drawRoot(root);
        c.EndDrawing();
    }
}

comptime {
    const refAllDecls = std.testing.refAllDecls;

    refAllDecls(@import("md.zig"));
}
