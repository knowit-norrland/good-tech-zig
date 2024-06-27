const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    c.SetTraceLogLevel(c.LOG_WARNING);
    c.InitWindow(800, 600, "Window");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.DrawText("Hello world", 4, 4, 32, c.Color{
            .r = 255,
            .g = 255,
            .b = 255,
            .a = 255,
        });
        c.EndDrawing();
    }
}

comptime {
    const refAllDecls = std.testing.refAllDecls;

    refAllDecls(@import("md.zig"));
}
