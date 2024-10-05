const std = @import("std");

fn sumString(comptime str: []const u8) !comptime_int {
    var sum = 0;
    var it = std.mem.tokenize(u8, str, " ");
    while(it.next()) |slice| {
        sum += try std.fmt.parseInt(i32, slice, 10);
    }
    return sum;
}

pub fn main() !void {
    // du får bara jobba med konstanta värden under comptime
    const str = "1 2 3";
    std.debug.print("Summan av {s} är {}", .{str, comptime try sumString(str)});
}