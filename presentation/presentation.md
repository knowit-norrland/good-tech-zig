# Introduktion till Zig
!(knowit.png)
Adam Temmel & Fredrik Kåhre

---

# Om Oss
bla bla bla

---

# Kort om Zig

* Dök upp 2016 (författare: Andrew Kelley)
* Systemspråk och toolchain
* Efterträdare till C
* Manuell minneshantering
* Fokuserar på enkelhet & pålitlighet

---

# Hello World!

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});
}
```

---

# Vad erbjuder Zig som språk?

* Imperativ stil
* Ergonomisk felhantering
* Strikt men generöst typsystem
* Typer som värden
* Metaprogrammering via comptime
* Minnesstrategier via Allocators
* Stödhjul för minnessäkerhet

---

# Imperativ stil

* Explicit minneshantering
* Explicita fel
* Inga funktionsöverlagringar
* Inga interfaces
* Inga macron
* Inga operatoröverlagringar
* Ingen dold logik
* Ingen preprocessor
* Inget arv


---

# Felhantering

```zig
const std = @import("std");

fn parseIntAndSquare(source: []const u8) !u32 {
    const int = try std.fmt.parseInt(u32, source, 10);
    return int * int;
}

test "Exempel med 'try'" {
    const int = try parseIntAndSquare("1337");
    try std.testing.expectEqual(1787569, int);
}
```

---

# Felhantering (pt. 2)

```zig
const std = @import("std");

fn parseIntAndSquare(source: []const u8) u32 {
    const int = std.fmt.parseInt(u32, source, 10) catch 0;
    return int * int;
}

test "Exempel utan 'try', med 'catch'" {
    const int = parseIntAndSquare("1337");
    try std.testing.expectEqual(1787569, int);
}
```

---

# Felhantering (pt. 3)

```zig
const std = @import("std");
const print = std.debug.print;

fn parseIntAndSquare(source: []const u8) u32 {
    const int = std.fmt.parseInt(u32, source, 10) catch |err| {
        print("Kan inte konvertera {s} till ett tal, fel: {}\n", .{err, source});
        unreachable;
    };
    return int * int;
}

test "Exempel med 'catch'-block" {
    const int = parseIntAndSquare("1337");
    try std.testing.expectEqual(1787569, int);
}
```

---

# Felhantering (pt. 4)

```zig
const TjanstError = error {
    TjanstASvararInte,
    TjanstBSvararInte,
};

fn arbetaMedTjanster() TjanstError!void {
    if(tjanstA.marDaligt()) {
        return TjanstError.TjanstASvararInte;
    }
    if(tjanstB.marDaligt()) {
        return TjanstError.TjanstBSvararInte;
    }

    // Gör något med tjänsterna...
}

```

---

# Strikt men generöst typsystem

```zig
const Knight = struct {
    strength: i32,
    alive: bool,
};

const Mage = struct {
    intelligence: i32,
    alive: bool,
};

const Character = union {
    knight: Knight,
    mage: Mage,
};
```

---

# Exempel på pattern-matching

```zig
const std = @import("std");
const print = std.debug.print;

fn printCharacter(c: Character) void {
    switch(c) {
        .knight => |k| {
            print("The Knight has {} strength\n", .{k.strength});
        },
        .mage => |m| {
            print("The Mage has {} intelligence\n", .{m.intelligence});
        },
    }
}
```

---

# Exempel på pattern-matching (pt.2)

```zig
const std = @import("std");
const print = std.debug.print;

fn funktion() void {
    arbetaMedTjanster() catch |err| {
        const tjanst = switch(err) {
            .TjanstASvararInte => "A",
            .TjanstBSvararInte => "B",
        };
        print("Tjanst {s} svarar inte\n", .{tjanst});
    };
}
```
