const std = @import("std");
const md = @import("md.zig");
const render = @import("render.zig");
const builtin = @import("builtin");
const c = @cImport({
    @cInclude("raylib.h");
});

//TODO: se över detta
const md_src = @embedFile("./slide.md");

fn readMarkdown(ally: std.mem.Allocator) !?[]const u8 {
    if (builtin.target.isWasm()) {
        return md_src;
    }

    const args = try std.process.argsAlloc(ally);

    var file: []const u8 = "";

    if (args.len >= 2) {
        file = args[1];
    } else {
        std.debug.print("No file specified, exiting...", .{});
        return null;
    }

    return try std.fs.cwd().readFileAlloc(ally, file, 1_000_000_000);
}

pub fn main() !void {
    var base_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(base_allocator.deinit() == .ok);
    const ally = base_allocator.allocator();

    var arena = std.heap.ArenaAllocator.init(ally);
    defer arena.deinit();
    const arena_ally = arena.allocator();

    const src = try readMarkdown(arena_ally);
    if (src == null) return;
    const root = try md.parse(src.?, arena_ally);

    c.SetTraceLogLevel(c.LOG_WARNING);
    c.SetConfigFlags(c.FLAG_VSYNC_HINT | c.FLAG_WINDOW_HIGHDPI);
    c.InitWindow(800, 600, "Window");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    var ctx = render.Context.init();

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
