const std = @import("std");
const assert = std.debug.assert;

//TODO: kommentarer, siffror, typer

pub const Token = struct {
    pub const Kind = enum {
        keyword,
        symbol,
        comment,
        string,
        number,
        builtin,
        primitive,
        space,
        other,
    };

    value: []const u8,
    kind: Kind,
};

pub const Tokens = []const Token;

const Context = struct {
    idx: usize = 0,
    src: []const u8,

    pub fn next(self: *Context) void {
        self.idx += 1;
    }

    pub fn prev(self: *Context) void {
        assert(0 < self.idx);
        self.idx += 1;
    }

    pub fn get(self: Context) u8 {
        assert(!self.eol());
        return self.src[self.idx];
    }

    pub fn eol(self: Context) bool {
        return self.idx >= self.src.len;
    }

    pub fn substr(self: Context, from: usize) []const u8 {
        assert(from <= self.idx);
        assert(from <= self.src.len);
        return self.src[from..self.idx];
    }

    pub fn readPast(ctx: *Context, delimeter: u8) void {
        while (!ctx.eol()) : (ctx.next()) {
            if (delimeter == ctx.get()) {
                ctx.next();
                break;
            }
        }
    }

    pub fn readUntilSymbolOrWhitespace(ctx: *Context) void {
        while (!ctx.eol()) : (ctx.next()) {
            if (isSymbol(ctx.get()) or isWhitespace(ctx.get())) break;
        }
    }
};

const keywords = std.StaticStringMap(void).initComptime(.{
    .{"addrspace"},
    .{"align"},
    .{"allowzero"},
    .{"and"},
    .{"anyframe"},
    .{"anytype"},
    .{"asm"},
    .{"async"},
    .{"await"},
    .{"break"},
    .{"callconv"},
    .{"catch"},
    .{"comptime"},
    .{"const"},
    .{"continue"},
    .{"defer"},
    .{"else"},
    .{"enum"},
    .{"errdefer"},
    .{"error"},
    .{"export"},
    .{"extern"},
    .{"fn"},
    .{"for"},
    .{"if"},
    .{"inline"},
    .{"linksection"},
    .{"noalias"},
    .{"noinline"},
    .{"nosuspend"},
    .{"opaque"},
    .{"or"},
    .{"orelse"},
    .{"packed"},
    .{"pub"},
    .{"resume"},
    .{"return"},
    .{"struct"},
    .{"suspend"},
    .{"switch"},
    .{"test"},
    .{"threadlocal"},
    .{"try"},
    .{"union"},
    .{"unreachable"},
    .{"usingnamespace"},
    .{"var"},
    .{"volatile"},
    .{"while"},
});

pub fn line(ally: std.mem.Allocator, src: []const u8) !Tokens {
    var tokens = try std.ArrayList(Token).initCapacity(ally, 5);
    defer tokens.deinit();

    var ctx: Context = .{
        .src = src,
    };

    var begin: usize = 0;
    while (!ctx.eol()) {
        ctx.readUntilSymbolOrWhitespace();
        const token_slice = ctx.substr(begin);
        defer begin = ctx.idx;

        if (keywords.has(token_slice)) {
            try tokens.append(.{
                .value = token_slice,
                .kind = .keyword,
            });
        } else if (token_slice.len == 0 and isWhitespace(ctx.get())) {
            // konvertera tabbar till blanksteg
            const iterations: u64 = if (ctx.get() == '\t') 4 else 1;

            for (0..iterations) |_| {
                ctx.next();
                try tokens.append(.{
                    .value = " ",
                    .kind = .space,
                });
            }
        } else if (token_slice.len == 0 and isSymbol(ctx.get())) {
            if (ctx.get() == '"' or ctx.get() == '\'') {
                const target = ctx.get();
                begin = ctx.idx;
                ctx.next();
                ctx.readPast(target);
                try tokens.append(.{
                    .value = ctx.substr(begin),
                    .kind = .string,
                });
            } else if (ctx.get() == '/' and !ctx.eol() and ctx.src[ctx.idx + 1] == '/') { // comment
                try tokens.append(.{
                    .value = ctx.src[begin..],
                    .kind = .comment,
                });
                ctx.idx = ctx.src.len;
            } else {
                ctx.next();
                try tokens.append(.{
                    .value = ctx.substr(begin),
                    .kind = .symbol,
                });
            }
        } else if (std.mem.startsWith(u8, token_slice, "@")) {
            try tokens.append(.{
                .value = token_slice,
                .kind = .builtin,
            });
        } else {
            if (isNumber(token_slice)) {
                try tokens.append(.{
                    .value = token_slice,
                    .kind = .number,
                });
            } else if (isPrimitive(token_slice)) {
                try tokens.append(.{
                    .value = token_slice,
                    .kind = .primitive,
                });
            } else {
                try tokens.append(.{
                    .value = token_slice,
                    .kind = .other,
                });
            }
        }
    }

    return try tokens.toOwnedSlice();
}

fn isSymbol(char: u8) bool {
    return switch (char) {
        '.',
        ':',
        ',',
        ';',
        '=',
        '!',
        '{',
        '}',
        '(',
        ')',
        '[',
        ']',
        '&',
        '%',
        '"',
        '\'',
        '?',
        '+',
        '-',
        '*',
        '/',
        => true,
        else => false,
    };
}

fn isWhitespace(char: u8) bool {
    return switch (char) {
        ' ', '\n', '\t' => true,
        else => false,
    };
}

fn isNumber(slice: []const u8) bool {
    var i: usize = 0;
    if (slice[i] == '-') {
        i += 1;
    }

    while (i < slice.len) : (i += 1) {
        switch (slice[i]) {
            '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '.' => {},
            else => {
                return false;
            },
        }
    }
    return true;
}

fn isPrimitive(slice: []const u8) bool {
    if (slice[0] == 'u' or slice[0] == 'i' or slice[0] == 'f') {
        if (isNumber(slice[1..])) {
            return true;
        }
    }

    const static = struct {
        var primitive_table = std.StaticStringMap(void).initComptime(.{
            .{"bool"},
            .{"void"},
            .{"comptime_int"},
        });
    };

    return static.primitive_table.get(slice) != null;
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "highlight hello-world" {
    const src =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    std.debug.print("Hello, World!");
        \\}
    ;
    const ally = std.testing.allocator;

    var line_idx: usize = 0;

    // rad 1
    {
        const line_end = std.mem.indexOfScalarPos(u8, src, line_idx, '\n').?;
        defer line_idx = line_end + 1;
        const tokens = try line(ally, src[line_idx..line_end]);
        defer ally.free(tokens);
        try expect(0 < tokens.len);
        try expectEqual(Token.Kind.keyword, tokens[0].kind);
        try expectEqualStrings("const", tokens[0].value);
        try expectEqual(Token.Kind.space, tokens[1].kind);
        try expectEqual(Token.Kind.other, tokens[2].kind);
        try expectEqualStrings("std", tokens[2].value);
        try expectEqual(Token.Kind.space, tokens[3].kind);
        try expectEqual(Token.Kind.symbol, tokens[4].kind);
        try expectEqualStrings("=", tokens[4].value);
        try expectEqual(Token.Kind.space, tokens[5].kind);
        try expectEqual(Token.Kind.builtin, tokens[6].kind);
        try expectEqualStrings("@import", tokens[6].value);
        try expectEqual(Token.Kind.symbol, tokens[7].kind);
        try expectEqualStrings("(", tokens[7].value);
        try expectEqual(Token.Kind.string, tokens[8].kind);
        try expectEqualStrings("\"std\"", tokens[8].value);
        try expectEqual(Token.Kind.symbol, tokens[9].kind);
        try expectEqualStrings(")", tokens[9].value);
        try expectEqual(Token.Kind.symbol, tokens[10].kind);
        try expectEqualStrings(";", tokens[10].value);
    }

    // rad 2
    {
        const line_end = std.mem.indexOfScalarPos(u8, src, line_idx, '\n').?;
        defer line_idx = line_end + 1;
        const tokens = try line(ally, src[line_idx..line_end]);
        defer ally.free(tokens);
        try expectEqual(0, tokens.len);
    }
}

test "highlight numbers" {
    const src =
        \\print("askasd {}, {}", .{52, 42});
    ;
    const ally = std.testing.allocator;
    var it = std.mem.tokenize(u8, src, "\n");
    while (it.next()) |slice| {
        const tokens = try line(ally, slice);
        defer ally.free(tokens);
        try expect(0 < tokens.len);
        try expectEqual(Token.Kind.other, tokens[0].kind);
        try expectEqual(Token.Kind.symbol, tokens[1].kind);
        try expectEqual(Token.Kind.string, tokens[2].kind);
        try expectEqual(Token.Kind.symbol, tokens[3].kind);
        try expectEqual(Token.Kind.space, tokens[4].kind);
        try expectEqual(Token.Kind.symbol, tokens[5].kind);
        try expectEqual(Token.Kind.symbol, tokens[6].kind);
        try expectEqual(Token.Kind.number, tokens[7].kind);
    }
}

test "highlight comment" {
    const src =
        \\not comment // comment
    ;
    const ally = std.testing.allocator;
    var it = std.mem.tokenize(u8, src, "\n");
    while (it.next()) |slice| {
        const tokens = try line(ally, slice);
        defer ally.free(tokens);
        try expect(0 < tokens.len);
        try expectEqual(Token.Kind.other, tokens[0].kind);
        try expectEqual(Token.Kind.space, tokens[1].kind);
        try expectEqual(Token.Kind.other, tokens[2].kind);
        try expectEqual(Token.Kind.space, tokens[3].kind);
        try expectEqual(Token.Kind.comment, tokens[4].kind);
    }
}
