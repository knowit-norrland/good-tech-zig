const std = @import("std");

pub const Root = struct {
    const Nodes = []const Node;
    slides: []Nodes,

    pub fn deinit(self: Root, ally: std.mem.Allocator) void {
        defer ally.free(self.slides);
        for (self.slides) |slide| {
            defer ally.free(slide);
            for (slide) |node| {
                switch (node) {
                    .text, .header, .codeblock, .image => {},
                    .list => |list| {
                        list.deinit(ally);
                    },
                }
            }
        }
    }
};

pub const Node = union(enum) {
    text: Text,
    header: Header,
    list: List,
    codeblock: Codeblock,
    image: Image,
};

pub const Text = struct {
    value: []const u8,
};

pub const Header = struct {
    value: []const u8,
    level: u32,
};

pub const List = struct {
    //TODO: det här kanske räcker med att vara en Text(?)
    nodes: []const Node,
    ordered: bool,

    pub fn deinit(self: List, ally: std.mem.Allocator) void {
        ally.free(self.nodes);
    }
};

pub const Codeblock = struct {
    code: []const u8,
    language: []const u8,
};

pub const Image = struct {
    filename: []const u8,
};

pub fn parse(source: []const u8, ally: std.mem.Allocator) !Root {
    var slides = std.ArrayList([]const Node).init(ally);
    defer slides.deinit();
    var children = std.ArrayList(Node).init(ally);
    defer children.deinit();

    var i: usize = 0;
    while (i < source.len) : (i += 1) {
        if (parseCodeBlock(source, &i)) |codeblock| {
            try children.append(codeblock);
        } else if (parseHeader(source, &i)) |header| {
            try children.append(header);
        } else if (try parseUnorderedList(source, &i, ally)) |list| {
            try children.append(list);
        } else if (parseDivider(source, &i)) {
            try slides.append(try children.toOwnedSlice());
        } else if (parseImage(source, &i)) |img| {
            try children.append(img);
        } else {
            try children.append(parseText(source, &i));
        }
    }

    try slides.append(try children.toOwnedSlice());

    return .{
        .slides = try slides.toOwnedSlice(),
    };
}

fn parseText(source: []const u8, index: *usize) Node {
    const begin = index.*;
    while (index.* < source.len) : (index.* += 1) {
        switch (source[index.*]) {
            '\n' => {
                //spara undan begin till hit
                return Node{
                    .text = .{
                        .value = source[begin..index.*],
                    },
                };
            },
            else => {},
        }
    }
    return Node{
        .text = .{
            .value = source[begin..],
        },
    };
}
fn parseUnorderedList(source: []const u8, index: *usize, ally: std.mem.Allocator) !?Node {
    var list = std.ArrayList(Node).init(ally);
    defer list.deinit();

    while (index.* < source.len) : (index.* += 1) {
        if (source[index.*] != '*') {
            break;
        }
        index.* += 1;

        const node = parseText(source, index);
        try list.append(node);
    }

    return if (list.items.len == 0)
        null
    else
        .{
            .list = .{
                .ordered = false,
                .nodes = try list.toOwnedSlice(),
            },
        };
}

fn parseHeader(source: []const u8, index: *usize) ?Node {
    const c = source[index.*];
    return switch (c) {
        '#' => {
            index.* += 1;
            while (index.* < source.len and source[index.*] == ' ') : (index.* += 1) {}
            return Node{
                .header = .{
                    .value = parseText(source, index).text.value,
                    .level = 1,
                },
            };
        },
        else => null,
    };
}

fn parseCodeBlock(source: []const u8, index: *usize) ?Node {
    const startindex = index.*;

    if (source.len < 3 + index.*) return null;

    if (!std.mem.eql(u8, source[index.* .. index.* + 3], "```")) return null;
    index.* += 3;
    var tempindex = index.*;

    var lang: []const u8 = "";
    var code: []const u8 = "";

    while (index.* < source.len) : (index.* += 1) {
        if (source[index.*] == '\n') {
            lang = source[tempindex..index.*];
            index.* += 1;
            break;
        }
    }
    tempindex = index.*;
    while (index.* + 4 <= source.len) : (index.* += 1) {
        if (std.mem.eql(u8, source[index.* .. index.* + 4], "\n```")) {
            code = source[tempindex..index.*];
            index.* += 3;
            return .{
                .codeblock = .{
                    .code = code,
                    .language = lang,
                },
            };
        }
    }
    index.* = startindex;
    return null;
}

fn parseDivider(source: []const u8, index: *usize) bool {
    const divider_str = "\n---\n";
    if (source.len < divider_str.len + index.*) {
        return false;
    }
    if (!std.mem.eql(u8, divider_str, source[index.* .. index.* + divider_str.len])) {
        return false;
    }

    index.* += divider_str.len;
    return true;
}

fn parseImage(source: []const u8, index: *usize) ?Node {
    const start_idx = index.*;
    const image_start = "!(";

    if (source.len < image_start.len + index.*) {
        return null;
    }

    if (!std.mem.eql(u8, image_start, source[index.* .. index.* + image_start.len])) {
        return null;
    }

    index.* += image_start.len;

    while (index.* < source.len and source[index.*] != ')') : (index.* += 1) {}

    if (index.* >= source.len) {
        index.* = start_idx;
        return null;
    }

    const img_src_begin = start_idx + image_start.len;
    const img_src_end = index.*;
    return .{
        .image = .{
            .filename = source[img_src_begin..img_src_end],
        },
    };
}

const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;
const expectEqualString = std.testing.expectEqualStrings;

test "parse simple markdown" {
    const src =
        \\Hej
        \\på
        \\dig
    ;

    const root = try parse(src, std.testing.allocator);
    defer root.deinit(std.testing.allocator);

    try expectEqual(1, root.slides.len);
    try expectEqual(3, root.slides[0].len);
}

test "parse header" {
    const src =
        \\# Hej
        \\på
        \\dig
    ;

    const root = try parse(src, std.testing.allocator);
    defer root.deinit(std.testing.allocator);

    try expectEqual(1, root.slides.len);
    try expectEqual(3, root.slides[0].len);
    try expectEqual(std.meta.Tag(Node).header, std.meta.activeTag(root.slides[0][0]));
    try expectEqualString("Hej", root.slides[0][0].header.value);
}

test "parse list" {
    const src =
        \\* Hej
        \\* på
        \\* dig
    ;

    const root = try parse(src, std.testing.allocator);
    defer root.deinit(std.testing.allocator);

    try expectEqual(1, root.slides.len);
    try expectEqual(1, root.slides[0].len);

    switch (root.slides[0][0]) {
        .list => |list| {
            try expectEqual(3, list.nodes.len);
            try expect(!list.ordered);
        },
        else => try expect(false),
    }
}

test "parse codeblock" {
    const src =
        \\```zig
        \\var x = u32;
        \\```
    ;

    const root = try parse(src, std.testing.allocator);
    defer root.deinit(std.testing.allocator);

    try expectEqual(1, root.slides.len);
    try expectEqual(1, root.slides[0].len);
    switch (root.slides[0][0]) {
        .codeblock => {},
        else => unreachable,
    }
    try expectEqualString("zig", root.slides[0][0].codeblock.language);
    try expectEqualString("var x = u32;", root.slides[0][0].codeblock.code);
}

test "parse divider" {
    const src =
        \\content before
        \\
        \\---
        \\
        \\content after
    ;

    const root = try parse(src, std.testing.allocator);
    defer root.deinit(std.testing.allocator);

    try expectEqual(2, root.slides.len);
    try expectEqual(1, root.slides[0].len);
    try expectEqual(1, root.slides[1].len);
    try expectEqualString("content before", root.slides[0][0].text.value);
    try expectEqualString("content after", root.slides[1][0].text.value);
}

test "parse image" {
    const src =
        \\!(my-image.png)
    ;

    const root = try parse(src, std.testing.allocator);
    defer root.deinit(std.testing.allocator);

    try expectEqual(1, root.slides.len);
    try expectEqual(1, root.slides[0].len);
    try expectEqualString("my-image.png", root.slides[0][0].image.filename);
}
