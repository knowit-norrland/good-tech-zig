const std = @import("std");

fn generateFibonacci(comptime n: usize) [n]u64 {
    @setEvalBranchQuota(10000); // Begränsa antalet beräkningar
    comptime var fibs: [n]u64 = undefined;
    comptime var i: usize = 0;
    inline while (i < n) : (i += 1) {
        fibs[i] = switch (i) {
            0, 1 => 1,
            else => fibs[i - 1] + fibs[i - 2],
        };
    }
    return fibs;
}

pub fn main() !void {
    // Skapa en lista av de 10 första talen i Fibonacci-serien
    const fib10 = generateFibonacci(10);
    std.debug.print("Serien innehåller {any}\n", .{fib10});
}
