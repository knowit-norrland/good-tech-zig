const std = @import("std");
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

    c.SetTraceLogLevel(c.LOG_WARNING);
    c.InitWindow(1600, 900, "Presentation");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    var ctx = try render.Context.init(arena_ally, root, file);
    defer ctx.deinit();

    while (!c.WindowShouldClose()) {
        handleInputs(&ctx, root);
        c.BeginDrawing();
        render.currentSlide(&ctx, root);
        c.EndDrawing();
    }
}

fn handleInputs(ctx: *render.Context, root: md.Root) void {
    if (c.IsKeyDown(c.KEY_UP)) {
        ctx.scale = @min(render.Context.max_scale, ctx.scale + 0.02);
    }
    if (c.IsKeyDown(c.KEY_DOWN)) {
        ctx.scale = @max(render.Context.min_scale, ctx.scale - 0.02);
    }
    if (c.IsKeyPressed(c.KEY_LEFT)) {
        render.prevSlide(ctx);
    }
    if (c.IsKeyPressed(c.KEY_RIGHT)) {
        render.nextSlide(ctx, root);
    }
}

comptime {
    const refAllDecls = std.testing.refAllDecls;

    refAllDecls(@import("md.zig"));
    refAllDecls(@import("render.zig"));
}
