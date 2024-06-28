const std = @import("std");

pub const Root = struct {
    nodes: []const Node,

    pub fn deinit(self: Root, ally: std.mem.Allocator) void {
        ally.free(self.nodes);
    }
};

pub const Node = union(enum) {
    text: Text,
    header: Header,
};

pub const Text = struct {
    value: []const u8,
};

pub const Header = struct {
    value: []const u8,
    level: u32,
};

pub fn parse(source: []const u8, ally: std.mem.Allocator) !Root {
    var children = std.ArrayList(Node).init(ally);
    defer children.deinit();
    var i: usize = 0;
    while (i < source.len) : (i += 1) {
        const node = readText(source, &i);
        try children.append(node);
    }

    return .{
        .nodes = try children.toOwnedSlice(),
    };
}

fn readText(source: []const u8, index: *usize) Node {
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

fn readHeader(source: []const u8, index: *usize) ?Node {
    const c = source[index.*];
    return switch (c) {
        '#' => {
            index.* += 1;
            return Node{
                .header = .{
                    .value = readText(source, index).value,
                    .level = 1,
                },
            };
        },
        else => null,
    };
}

const expectEqual = std.testing.expectEqual;

test "parse simple markdown" {
    const src =
        \\Hej
        \\på
        \\dig
    ;

    const root = try parse(src, std.testing.allocator);
    defer root.deinit(std.testing.allocator);

    try expectEqual(3, root.nodes.len);
}
