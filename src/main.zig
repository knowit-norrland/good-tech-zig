const std = @import("std");
const builtin = @import("builtin");
const md = @import("md.zig");
const render = @import("render.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var base_allocator = std.heap.GeneralPurposeAllocator(.{}){};
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

    const width = c.GetMonitorWidth(c.GetCurrentMonitor());
    const height = c.GetMonitorHeight(c.GetCurrentMonitor());

    c.SetTraceLogLevel(c.LOG_WARNING);
    c.InitWindow(width, height, "Presentation");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    var ctx = try render.Context.init(arena_ally, root, file);
    defer ctx.deinit();

    while (!c.WindowShouldClose()) {
        handleInputs(&ctx, root);
        c.BeginDrawing();
        try render.currentSlide(&ctx, root);
        c.EndDrawing();
    }
}

fn handleInputs(ctx: *render.Context, root: md.Root) void {
    if (c.IsKeyDown(c.KEY_UP) or c.IsKeyDown(c.KEY_K)) {
        ctx.scale = @min(render.Context.max_scale, ctx.scale + 0.02);
    }
    if (c.IsKeyDown(c.KEY_DOWN) or c.IsKeyDown(c.KEY_J)) {
        ctx.scale = @max(render.Context.min_scale, ctx.scale - 0.02);
    }
    if (c.IsKeyPressed(c.KEY_LEFT) or c.IsKeyDown(c.KEY_H)) {
        render.prevSlide(ctx);
    }
    if (c.IsKeyPressed(c.KEY_RIGHT) or c.IsKeyDown(c.KEY_L)) {
        render.nextSlide(ctx, root);
    }
}

comptime {
    const refAllDecls = std.testing.refAllDecls;

    refAllDecls(@import("md.zig"));
    refAllDecls(@import("render.zig"));
    refAllDecls(@import("highlight.zig"));
}
