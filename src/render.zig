const std = @import("std");
const builtin = @import("builtin");
const md = @import("md.zig");
const hi = @import("highlight.zig");
const rl = @import("raylib");

const TextureTable = std.StringHashMap(rl.Texture2D);

const regular_font_data = @embedFile("./inter.ttf");
const mono_space_font = @embedFile("./JetBrainsMono.ttf");

const code_font_size = 48;
const regular_font_size = 64;
const header_font_size = 128;

const color_bg = hex(0x3A3335);
const color_fg = hex(0xFFFFFF);
const color_cb = hex(0x2A2325);

const color_keyword = hex(0x569DD9);
const color_symbol = color_fg;
const color_other = color_fg;
const color_builtin = hex(0xAE7191);
const color_string = hex(0xDD9875);
const color_number = hex(0xBCD0A7);
const color_comment = hex(0x669654);
const color_primitive = hex(0x9ADDFF);

pub const Context = struct {
    pub const n_codepoints = 1024;
    pub const max_scale = 2.5;
    pub const min_scale = 0.5;

    regular_font: rl.Font,
    code_font: rl.Font,
    codepoints: [n_codepoints]i32,
    x: f32 = 0,
    y: f32 = 0,
    scale: f32 = 1.0,
    current_slide_idx: usize = 0,
    alpha: f32 = 1.0,
    animating: bool = false,
    animation_target_slide: usize = 0,
    animation_begin_timestamp: i64 = 0,
    texture_table: TextureTable,
    frame_arena: std.heap.ArenaAllocator,

    pub fn init(ally: std.mem.Allocator, root: md.Root, path: []const u8) !Context {
        var ctx = Context{
            .regular_font = undefined,
            .code_font = undefined,
            .codepoints = undefined,
            .texture_table = TextureTable.init(ally),
            .frame_arena = std.heap.ArenaAllocator.init(ally),
        };
        // den här instruktionen reserverar ett antal greninstruktioner
        // för bruk vid comptime (för sammanhangets skull)
        @setEvalBranchQuota(1024);
        // Den här beräkningen sker under comptime
        inline for (0..n_codepoints) |i| {
            ctx.codepoints[i] = i;
        }
        ctx.regular_font = rl.loadFontFromMemory(
            ".ttf",
            regular_font_data,
            // glöm inte bort att föra in eventuellt nya fontstorlekar här också...
            @max(
                regular_font_size,
                header_font_size,
            ),
            &ctx.codepoints,
        );
        ctx.code_font = rl.loadFontFromMemory(
            ".ttf",
            mono_space_font,
            code_font_size,
            &ctx.codepoints,
        );
        // gör textens kanter lite finare vid skalning (men påverkar såklart prestanda)
        rl.setTextureFilter(ctx.regular_font.texture, .texture_filter_anisotropic_4x);
        rl.setTextureFilter(ctx.code_font.texture, .texture_filter_anisotropic_4x);

        var buf: [512]u8 = undefined;
        const dir = workingDirFromPath(path);

        for (root.slides) |slide| {
            for (slide) |node| {
                switch (node) {
                    .image => |img| {
                        if (ctx.texture_table.getPtr(img.filename) != null) {
                            continue;
                        }
                        const c_slice = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{ dir, img.filename });
                        const loaded_texture = rl.loadTexture(c_slice);
                        rl.setTextureFilter(loaded_texture, .texture_filter_bilinear);
                        try ctx.texture_table.put(img.filename, loaded_texture);
                    },
                    else => {},
                }
            }
        }

        return ctx;
    }

    pub fn deinit(ctx: *const Context) void {
        var it = ctx.texture_table.valueIterator();
        while (it.next()) |texture| {
            rl.unloadTexture(texture.*);
        }
    }
};

// renderar en enskild slide
pub fn currentSlide(ctx: *Context, root: md.Root) !void {
    _ = ctx.frame_arena.reset(.retain_capacity);
    const nodes = root.slides[ctx.current_slide_idx];
    const b = bounds(ctx, nodes);
    ctx.x = @as(f32, @floatFromInt(rl.getRenderWidth())) / 2 - b.x / 2;
    ctx.y = @as(f32, @floatFromInt(rl.getRenderHeight())) / 2 - b.y / 2;
    ctx.y /= ctx.scale;
    try currentSlideImpl(ctx, root);
}

pub fn currentSlideImpl(ctx: *Context, root: md.Root) !void {
    const nodes = root.slides[ctx.current_slide_idx];

    handleAnimationStep(ctx);

    rl.clearBackground(color_bg);

    for (nodes) |node| {
        switch (node) {
            .header => |header| renderHeader(ctx, header),
            .text => |text| renderText(ctx, text),
            .list => |list| renderList(ctx, list),
            .image => |img| renderImage(ctx, img),
            .codeblock => |codeblock| try renderCodeblock(ctx, codeblock),
        }
    }

    const str = slideNrStr(ctx.current_slide_idx + 1, root.slides.len);
    const rect = rl.measureTextEx(ctx.regular_font, str, @floatFromInt(regular_font_size), 0);
    const x: f32 = @as(f32, @floatFromInt(rl.getRenderWidth())) - rect.x - 8;
    const y: f32 = @as(f32, @floatFromInt(rl.getRenderHeight())) - rect.y;
    drawStr(ctx, str, x, y, regular_font_size, color_fg, ctx.regular_font);
}

pub fn nextSlide(ctx: *Context, root: md.Root) void {
    if (ctx.animating or ctx.current_slide_idx + 1 >= root.slides.len) {
        return;
    }
    beginSlideChange(ctx, ctx.current_slide_idx + 1);
}

pub fn prevSlide(ctx: *Context) void {
    if (ctx.animating or ctx.current_slide_idx <= 0) {
        return;
    }
    beginSlideChange(ctx, ctx.current_slide_idx - 1);
}

fn beginSlideChange(ctx: *Context, idx: usize) void {
    ctx.animating = true;
    ctx.animation_target_slide = idx;
    ctx.animation_begin_timestamp = std.time.milliTimestamp();
}

fn handleAnimationStep(ctx: *Context) void {
    if (!ctx.animating) return;
    const animation_fade_out_seconds = 0.1;
    const animation_fade_in_seconds = 0.2;
    const animation_complete_seconds = animation_fade_out_seconds + animation_fade_in_seconds;
    const dt: f32 = @as(f32, @floatFromInt(
        std.time.milliTimestamp() - ctx.animation_begin_timestamp,
    )) / 1000.0;

    if (dt > animation_complete_seconds) {
        ctx.animating = false;
        ctx.alpha = 1.0;
        return;
    }

    if (dt < animation_fade_in_seconds) {
        ctx.alpha = 1.0 - dt / animation_fade_in_seconds;
    } else {
        ctx.current_slide_idx = ctx.animation_target_slide;
        ctx.alpha = (dt - animation_fade_in_seconds) / animation_fade_out_seconds;
    }
}

// renderingen av varje sorts enskild nod ansvarar för att flytta renderingscontexten
// genom att modifera ctx.y

fn renderText(ctx: *Context, text: md.Text) void {
    defer ctx.y += regular_font_size; // likt såhär
    drawStr(ctx, text.value, ctx.x, ctx.y, regular_font_size, color_fg, ctx.regular_font);
}

fn renderHeader(ctx: *Context, h: md.Header) void {
    defer ctx.y += header_font_size;
    drawStr(ctx, h.value, ctx.x, ctx.y, header_font_size, color_fg, ctx.regular_font);
}

fn renderList(ctx: *Context, l: md.List) void {
    const margin_left = ctx.x;
    defer {
        ctx.y += regular_font_size;
        ctx.x = margin_left;
    }

    const offset = regular_font_size / 4;
    const font_char_dimension = strBounds(" ", &ctx.regular_font, regular_font_size);

    //TODO: skalningen mår sisådär
    for (l.nodes) |listnode| {
        ctx.x += offset;
        ctx.y += regular_font_size / 4;
        drawCircle(ctx, regular_font_size / 4, color_fg);
        ctx.x += font_char_dimension.x * 3;
        ctx.x -= offset;
        ctx.y -= regular_font_size / 4;
        renderText(ctx, listnode.text);
        ctx.y += regular_font_size / 4;
        ctx.x = margin_left;
    }
}

fn renderImage(ctx: *Context, i: md.Image) void {
    const ptr = ctx.texture_table.getPtr(i.filename);
    std.debug.assert(ptr != null);
    defer ctx.y += @floatFromInt(ptr.?.height);
    drawImg(ctx, ptr.?.*, ctx.x, ctx.y, rl.Color.white);
}

fn renderCodeblock(ctx: *Context, codeblock: md.Codeblock) !void {
    drawCodeBackground(ctx, strBounds(codeblock.code, &ctx.code_font, code_font_size));

    const left_margin = ctx.x;

    var it = std.mem.splitScalar(u8, codeblock.code, '\n');
    while (it.next()) |line| {
        const tokens = try hi.line(ctx.frame_arena.allocator(), line);
        for (tokens) |token| {
            switch (token.kind) {
                .keyword => {
                    drawStr(ctx, token.value, ctx.x, ctx.y, code_font_size, color_keyword, ctx.code_font);
                },
                .builtin => {
                    drawStr(ctx, token.value, ctx.x, ctx.y, code_font_size, color_builtin, ctx.code_font);
                },
                .other => {
                    drawStr(ctx, token.value, ctx.x, ctx.y, code_font_size, color_other, ctx.code_font);
                },

                .space => {},
                .string => {
                    drawStr(ctx, token.value, ctx.x, ctx.y, code_font_size, color_string, ctx.code_font);
                },
                .symbol => {
                    drawStr(ctx, token.value, ctx.x, ctx.y, code_font_size, color_symbol, ctx.code_font);
                },
                .comment => {
                    drawStr(ctx, token.value, ctx.x, ctx.y, code_font_size, color_comment, ctx.code_font);
                },
                .number => {
                    drawStr(ctx, token.value, ctx.x, ctx.y, code_font_size, color_number, ctx.code_font);
                },
                .primitive => {
                    drawStr(ctx, token.value, ctx.x, ctx.y, code_font_size, color_primitive, ctx.code_font);
                },
            }
            const b = strBounds(token.value, &ctx.code_font, code_font_size);
            ctx.x += b.x * ctx.scale;
        }
        ctx.y += code_font_size;
        ctx.x = left_margin;
    }
}

fn bounds(ctx: *const Context, nodes: []const md.Node) rl.Vector2 {
    const b = nodesBounds(ctx, nodes);
    return .{
        .x = b.x * ctx.scale,
        .y = b.y * ctx.scale,
    };
}

fn nodesBounds(ctx: *const Context, nodes: []const md.Node) rl.Vector2 {
    var w: f32 = 0;
    var height: f32 = 0;

    for (nodes) |node| {
        const node_bounds = switch (node) {
            .text => |t| strBounds(t.value, &ctx.regular_font, regular_font_size),
            .header => |h| strBounds(h.value, &ctx.regular_font, header_font_size),
            .list => |l| nodesBounds(ctx, l.nodes),
            .image => |i| imgBounds(ctx, i),
            .codeblock => |code| strBounds(code.code, &ctx.code_font, code_font_size),
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

fn imgBounds(ctx: *const Context, img: md.Image) rl.Vector2 {
    const ptr = ctx.texture_table.getPtr(img.filename);
    std.debug.assert(ptr != null);
    return .{
        .x = @floatFromInt(ptr.?.width),
        .y = @floatFromInt(ptr.?.height),
    };
}

// "primitiv" funktion för att rendera en sträng vid angiven position
// tanken är att funktionerna för att rendera konstruktionerna nyttjar
// den här funktionen, så löser sig problem med skalning/dylikt på en
// gemensam punkt
fn drawStr(ctx: *const Context, str: []const u8, x: f32, y: f32, h: f32, color: rl.Color, font: rl.Font) void {
    const slice = strZ(str);
    var alpha_applied_color = color;
    alpha_applied_color.a = @intFromFloat(ctx.alpha * @as(f32, @floatFromInt(color.a)));
    rl.drawTextEx(
        font,
        slice,
        rl.Vector2{
            .x = x,
            .y = y * ctx.scale,
        },
        h * ctx.scale,
        0,
        alpha_applied_color,
    );
}

fn drawCircle(ctx: *const Context, radius: f32, color: rl.Color) void {
    var alpha_applied_color = color;
    alpha_applied_color.a = @intFromFloat(ctx.alpha * @as(f32, @floatFromInt(color.a)));
    rl.drawCircleV(.{
        .x = (ctx.x + radius),
        .y = (ctx.y + radius) * ctx.scale,
    }, radius * ctx.scale, alpha_applied_color);
}

fn drawCodeBackground(ctx: *const Context, textsize: rl.Vector2) void {
    var alpha_applied_color = color_cb;
    alpha_applied_color.a = @intFromFloat(ctx.alpha * @as(f32, @floatFromInt(color_cb.a)));
    const padding_x = 32 * ctx.scale;
    const padding_y = 16 * ctx.scale;
    const rect = rl.Rectangle{
        .x = (ctx.x - padding_x),
        .y = (ctx.y * ctx.scale - padding_y),
        .width = (textsize.x * ctx.scale + 2 * padding_x),
        .height = (textsize.y * ctx.scale + 2 * padding_y),
    };
    rl.drawRectangleRounded(rect, 0.05, 1, alpha_applied_color);
}

fn drawImg(ctx: *const Context, texture: rl.Texture2D, x: f32, y: f32, color: rl.Color) void {
    var alpha_applied_color = color;
    alpha_applied_color.a = @intFromFloat(ctx.alpha * @as(f32, @floatFromInt(color.a)));
    rl.drawTextureEx(
        texture,
        rl.Vector2{
            .x = x,
            .y = y * ctx.scale,
        },
        0,
        ctx.scale,
        alpha_applied_color,
    );
}

fn strBounds(str: []const u8, font: *const rl.Font, font_height: i32) rl.Vector2 {
    const slice = strZ(str);
    return rl.measureTextEx(font.*, slice, @floatFromInt(font_height), 0);
}

fn workingDirFromPath(path: []const u8) []const u8 {
    const idx = std.mem.lastIndexOfScalar(u8, path, '/') orelse return "";
    return path[0 .. idx + 1];
}

fn slideNrStr(current: usize, total: usize) [:0]const u8 {
    const static = struct {
        var buffer: [128]u8 = undefined;
    };
    return std.fmt.bufPrintZ(&static.buffer, "{}/{}", .{ current, total }) catch unreachable;
}

// bekvämlighet för att skapa nullterminerade strängar
fn strZ(str: []const u8) [:0]const u8 {
    const static = struct {
        var buffer: [2048]u8 = undefined;
    };
    return std.fmt.bufPrintZ(&static.buffer, "{s}", .{str}) catch unreachable;
}

fn hex(code: u24) rl.Color {
    return .{
        .r = @intCast((code & 0xFF0000) >> 16),
        .g = @intCast((code & 0x00FF00) >> 8),
        .b = @intCast((code & 0x0000FF) >> 0),
        .a = 255,
    };
}

test "test hex conversion" {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(rl.Color{
        .r = 58,
        .g = 51,
        .b = 53,
        .a = 255,
    }, hex(0x3A3335));
}
