# Introduktion till Zig
!(knowit.png)
Adam Temmel & Fredrik Kåhre

---

# Om oss

* Konsulter från Knowit
* Bolagsverket
* Java & Vue

---

# Kort om Zig

* Dök upp 2016 (författare: Andrew Kelley)
* Systemspråk och toolchain
* Efterträdare till C
* Manuell minneshantering
* Fokuserar på enkelhet & pålitlighet

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

# Hello World!

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});
}
```

---

# Felhantering

```zig
const std = @import("std");

//       En slice av bytes (sträng)   Felunion
//                           v           v
fn parseIntAndSquare(source: []const u8) !u32 {
    const int = try std.fmt.parseInt(u32, source, 10);
    return int * int;
}
```
```zig
//     Packa upp eventuella fel med 'try'
//          v
const int = try parseIntAndSquare("1337");
```

---

# Felhantering (pt. 2)

```zig
const std = @import("std");

//                                Felunion borta
//                                       v
fn parseIntAndSquare(source: []const u8) u32 {
    //                           Ersätt eventuella fel med default-värde
    //                                            v
    const int = std.fmt.parseInt(u32, source, 10) catch 0;
    return int * int;
}
```

```zig
// Nu går det att ta bort 'try'!
const int = parseIntAndSquare("1337");
```

---

# Felhantering (pt. 3)

```zig
const std = @import("std");
const print = std.debug.print;

fn parseIntAndSquare(source: []const u8) u32 {
    //                        Packa upp fel med catch   Få felet som variabel
    //                                            v      v 
    const int = std.fmt.parseInt(u32, source, 10) catch |err| {
        // Hantera felet på önskat vis
        print("Kan inte konvertera {s} till ett tal, fel: {}\n", .{err, source});
        unreachable; // Markera att programmet aldrig får ta sig hit
    };
    return int * int;
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
    staff: ?Staff,
};

const Staff = struct {
    level: i32,  
};

const Character = union(enum) {
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
            if(m.staff) |staff| {
                print("The Mage also has a level {} staff\n", .{staff.level});
            }
        },
    }
}
```

---

# Felhantering (pt. 4)

```zig
// Definiera egna feltyper
const TjanstError = error {
    TjanstASvararInte,
    TjanstBSvararInte,
};
```

```zig
//     Explicit deklaration av vilka fel som kan uppstå
//                          v
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
---

# Enhetstester

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

# Comptime

```zig
const std = @import("std");

fn sumString(comptime str: []const u8) !comptime_int {
    var sum = 0;
    var it = std.mem.tokenize(u8, str, " ");
    while(it.next()) |slice| {
        sum += try std.fmt.parseInt(i32, slice, 10);
    }
    return sum;
}
```

```zig
// du får bara jobba med konstanta värden under comptime
const str = "1 2 3";
//   beräkna summan under kompileringssteget
//              v
const sum = comptime try sumString(str);
std.debug.print("Summan av {s} är {}", .{str, sum});
```

---

# Zig som byggsystem

* Nyttjar comptime för att bete sig likt ett skript (build.zig)
* Zig bundlas med hela Clang-sviten
* Kan kompilera C, C++ och Zig
* Stöd för korskompilering

```
# exempel på kompilering med angiven målplatform
zig cc -o hello.exe hello.c -target x86_64-windows-gnu
```

---

# Anropa C i Zig

```zig
// bygg exempelvis med 'zig build-exe cimport.zig -lc -lraylib'
const rl = @cImport({
    @cInclude("raylib.h"); // import av C-header
});

pub fn main() void {
    rl.InitWindow(800, 450, "raylib [core] example - basic window");
    defer rl.CloseWindow();

    ray.SetTargetFPS(60);

    while (!rl.WindowShouldClose()) {
        ray.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.RAYWHITE);
        rl.DrawText("Hello, World!", 190, 200, 20, rl.LIGHTGRAY);
    }
}
```

