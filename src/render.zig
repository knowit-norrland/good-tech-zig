const std = @import("std");
const md = @import("md.zig");

const c = @cImport({
    @cInclude("raylib.h");
});

const regular_font_data = @embedFile("./inter.ttf");

const regular_font_size = 64;
const header_font_size = 128;

const color_bg = hex(0x3A3335);
const color_fg = hex(0xFFFFFF);

pub const Context = struct {
    pub const n_codepoints = 1024;
    pub const max_scale = 2.5;
    pub const min_scale = 0.5;

    regular_font: c.Font,
    codepoints: [n_codepoints]i32,
    x: f32 = 0,
    y: f32 = 0,
    bounds: c.Vector2 = .{},
    scale: f32 = 1.0,
    current_slide_idx: usize = 0,
    alpha: f32 = 1.0,
    animating: bool = false,
    animation_target_slide: usize = 0,
    animation_begin_timestamp: i64 = 0,

    pub fn init() Context {
        var ctx = Context{
            .regular_font = undefined,
            .codepoints = undefined,
        };
        // den här instruktionen reserverar ett antal greninstruktioner
        // för bruk vid comptime (för sammanhangets skull)
        @setEvalBranchQuota(1024);
        // Den här beräkningen sker under comptime
        inline for (0..n_codepoints) |i| {
            ctx.codepoints[i] = i;
        }
        ctx.regular_font = c.LoadFontFromMemory(
            ".ttf",
            regular_font_data.ptr,
            regular_font_data.len,
            // glöm inte bort att föra in eventuellt nya fontstorlekar här också...
            @max(
                regular_font_size,
                header_font_size,
            ) * max_scale,
            (&ctx.codepoints).ptr,
            n_codepoints,
        );
        // gör textens kanter lite finare vid skalning (men påverkar såklart prestanda)
        // se: https://en.wikipedia.org/wiki/Bilinear_interpolation
        c.SetTextureFilter(ctx.regular_font.texture, c.TEXTURE_FILTER_BILINEAR);
        return ctx;
    }
};

// renderar en enskild slide
pub fn currentSlide(ctx: *Context, root: md.Root) void {
    const nodes = root.slides[ctx.current_slide_idx];
    ctx.bounds = bounds(ctx, nodes);
    ctx.x = @as(f32, @floatFromInt(c.GetRenderWidth())) / 2 - ctx.bounds.x / 2;
    ctx.y = @as(f32, @floatFromInt(c.GetRenderHeight())) / 2 - ctx.bounds.y / 2;
    currentSlideImpl(ctx, root);
}

pub fn currentSlideImpl(ctx: *Context, root: md.Root) void {
    const nodes = root.slides[ctx.current_slide_idx];

    handleAnimationStep(ctx);

    c.ClearBackground(color_bg);

    for (nodes) |node| {
        switch (node) {
            .header => |header| renderHeader(ctx, header),
            .text => |text| renderText(ctx, text),
            .list => |list| {
                for (list.nodes) |listnode| {
                    renderText(ctx, listnode.text);
                }
            },
            .image => {},
            .codeblock => |block| {
                //TODO: återimplmentera det här
                _ = block;
                //renderText(ctx, block.code);
            },
        }
    }
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
    drawStr(ctx, text.value, ctx.x, ctx.y, regular_font_size, color_fg);
}

fn renderHeader(ctx: *Context, h: md.Header) void {
    defer ctx.y += header_font_size;
    drawStr(ctx, h.value, ctx.x, ctx.y, header_font_size, color_fg);
}

fn bounds(ctx: *const Context, nodes: []const md.Node) c.Vector2 {
    const b = nodesBounds(nodes);
    return .{
        .x = b.x * ctx.scale,
        .y = b.y * ctx.scale,
    };
}

fn nodesBounds(nodes: []const md.Node) c.Vector2 {
    var w: f32 = 0;
    var height: f32 = 0;

    for (nodes) |node| {
        const node_bounds = switch (node) {
            .text => |t| strBounds(t.value, regular_font_size),
            .header => |h| strBounds(h.value, header_font_size),
            .list => |l| nodesBounds(l.nodes),
            .image => c.Vector2{
                .x = 0,
                .y = 0,
            },
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

// "primitiv" funktion för att rendera en sträng vid angiven position
// tanken är att funktionerna för att rendera konstruktionerna nyttjar
// den här funktionen, så löser sig problem med skalning/dylikt på en
// gemensam punkt
fn drawStr(ctx: *const Context, str: []const u8, x: f32, y: f32, h: f32, color: c.Color) void {
    const slice = strZ(str);
    var alpha_applied_color = color;
    alpha_applied_color.a = @intFromFloat(ctx.alpha * @as(f32, @floatFromInt(color.a)));
    c.DrawTextEx(
        ctx.regular_font,
        slice,
        c.Vector2{
            .x = x,
            .y = y * ctx.scale,
        },
        h * ctx.scale,
        0,
        alpha_applied_color,
    );
}

fn strBounds(str: []const u8, font_height: i32) c.Vector2 {
    const slice = strZ(str);
    const text_width = c.MeasureText(slice, font_height);
    return .{
        .x = @floatFromInt(text_width),
        .y = @floatFromInt(font_height),
    };
}

// bekvämlighet för att skapa nullterminerade strängar
fn strZ(str: []const u8) [:0]const u8 {
    const static = struct {
        var buffer: [2048]u8 = .{0} ** 2048;
    };
    return std.fmt.bufPrintZ(&static.buffer, "{s}", .{str}) catch unreachable;
}

fn hex(code: u24) c.Color {
    return .{
        .r = @intCast((code & 0xFF0000) >> 16),
        .g = @intCast((code & 0x00FF00) >> 8),
        .b = @intCast((code & 0x0000FF) >> 0),
        .a = 255,
    };
}

test "test hex conversion" {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(c.Color{
        .r = 58,
        .g = 51,
        .b = 53,
        .a = 255,
    }, hex(0x3A3335));
}
