const std = @import("std");

fn parseIntAndSquare(source: []const u8) !u32 {
    const int = try std.fmt.parseInt(u32, source, 10);
    return int * int;
}

test "Konvertering av heltal" {
    const int = try parseIntAndSquare("1337");
    try std.testing.expectEqual(1787569, int);
}
