const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const md = @import("md.zig");
const render = @import("render.zig");
const web = @import("web.zig");
const build_options = @import("build_options");

const presentation_file = build_options.present;
const presentation_source = @embedFile(presentation_file);

const web_build = builtin.target.os.tag == .emscripten;

pub fn main() !void {
    var base_allocator = if (web_build) web.WebAllocator{} else std.heap.GeneralPurposeAllocator(.{}){};
    defer if (!web_build) std.debug.assert(base_allocator.deinit() == .ok);
    const ally = base_allocator.allocator();

    var arena = std.heap.ArenaAllocator.init(ally);
    defer arena.deinit();
    const arena_ally = arena.allocator();

    const root = try md.parse(presentation_source, arena_ally);

    const width = rl.getMonitorWidth(rl.getCurrentMonitor());
    const height = rl.getMonitorHeight(rl.getCurrentMonitor());

    rl.setTraceLogLevel(.log_warning);
    rl.initWindow(width, height, "Presentation");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var ctx = try render.Context.init(arena_ally, root, presentation_file);
    defer ctx.deinit();

    while (!rl.windowShouldClose()) {
        handleInputs(&ctx, root);
        rl.beginDrawing();
        defer rl.endDrawing();
        try render.currentSlide(&ctx, root);
    }
}

fn handleInputs(ctx: *render.Context, root: md.Root) void {
    if (rl.isKeyDown(.key_up) or rl.isKeyDown(.key_k)) {
        ctx.scale = @min(render.Context.max_scale, ctx.scale + 0.02);
    }
    if (rl.isKeyDown(.key_down) or rl.isKeyDown(.key_j)) {
        ctx.scale = @max(render.Context.min_scale, ctx.scale - 0.02);
    }
    if (rl.isKeyPressed(.key_left) or rl.isKeyDown(.key_h)) {
        render.prevSlide(ctx);
    }
    if (rl.isKeyPressed(.key_right) or rl.isKeyDown(.key_l)) {
        render.nextSlide(ctx, root);
    }
}

comptime {
    const refAllDecls = std.testing.refAllDecls;

    refAllDecls(@import("md.zig"));
    refAllDecls(@import("render.zig"));
    refAllDecls(@import("highlight.zig"));
}
