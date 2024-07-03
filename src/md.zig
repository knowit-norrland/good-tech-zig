const std = @import("std");

pub const Root = struct {
    nodes: []const Node,

    pub fn deinit(self: Root, ally: std.mem.Allocator) void {
        defer ally.free(self.nodes);
        for(self.nodes) |node| {
            switch (node) {
                .text, .header => {},
                .list => |list| {
                    list.deinit(ally);
                },
             }
        }
    }
};

pub const Node = union(enum) {
    text: Text,
    header: Header,
    list : List,
};

pub const Text = struct {
    value: []const u8,
};

pub const Header = struct {
    value: []const u8,
    level: u32,
};
pub const List = struct {
    nodes : []const Node,
    ordered : bool,

    pub fn deinit(self: List, ally: std.mem.Allocator) void {
        ally.free(self.nodes);
    }
};

pub fn parse(source: []const u8, ally: std.mem.Allocator) !Root {
    var children = std.ArrayList(Node).init(ally);
    defer children.deinit();
    var i: usize = 0;
    while (i < source.len) : (i += 1) {
        if(try parseUnorderedList(source, &i, ally)) |list| {
            try children.append(list);
        } else {
            try children.append( readText(source, &i));
        }

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
fn parseUnorderedList(source: []const u8, index: *usize, ally: std.mem.Allocator) !?Node{
    var list = std.ArrayList(Node).init(ally);
    defer list.deinit();

    while (index.* < source.len) : (index.* += 1) {
        if(source[index.*] != '*') {
            break;
        }
        index.* += 1;

        const node = readText(source, index);
        try list.append(node);
    }

    return if(list.items.len == 0)
        null
    else .{
            .list = .{
                .ordered = false,
                .nodes =  try list.toOwnedSlice(),
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
const expect = std.testing.expect;

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

test "parse list" {
    const src =
    \\* Hej
    \\* på
    \\* dig
   ;

    const root = try parse(src, std.testing.allocator);
    defer root.deinit(std.testing.allocator);

    try expectEqual(1, root.nodes.len);

    switch (root.nodes[0]) {
        .list => | list | {
            try expectEqual(3, list.nodes.len);
            try expect(!list.ordered);
        },
        else => try expect(false),
     }

}