# Introduktion till Zig
!(knowit-zig.png)
Adam Temmel & Fredrik Kåhre

---

# Om oss

* Konsulter från Knowit
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
* Explicit felhantering
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
* Inga interfaces/arv
* Inga macron
* Inga operatoröverlagringar
* Ingen dold logik

---

# Hello World!

```zig
const std = @import("std");

pub fn main() void {
    std.debug.print("Hello, World!\n", .{});
}
```

---

# Grundläggande typer

```zig
u8  // byte
i32 // int
f32 // float
f64 // double
```
```zig
[]u8       // "slice av bytes" (sträng)
[]const u8 // "slice av bytes för läsning"
```
```zig
u21 // Ok, får skapa "egna" avgränsingar mellan 1-65535 bitar
i34 // Också ok
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
    //          Ersätt eventuella fel med default-värde
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
        print("Kan inte konvertera {s} till ett tal, fel: {}\n", .{source, err});
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
};

const Mage = struct {
    intelligence: i32,
    staff: ?Staff, // '?' säger att värdet är frivilligt
};

const Staff = struct {
    level: i32,  
};

const Character = union(enum) { // Skapar en union utifrån ett enum
    knight: Knight, // Bara ett av dessa fält kan vara aktivt
    mage: Mage,
};
```

---

# Exempel på pattern-matching

```zig
const std = @import("std");
const print = std.debug.print;

fn printCharacter(c: Character) void {
    switch(c) { // Matcha utifrån vilket fält som är aktivt
        .knight => |k| {
            print("The Knight has {} strength\n", .{k.strength});
        },
        .mage => |m| {
            print("The Mage has {} intelligence\n", .{m.intelligence});
            if(m.staff) |staff| { // Om 'm.staff' inte är null
                print("The Mage also has a level {} staff\n", .{staff.level});
            }
        },
    }
}
```

---

# Felhantering (pt. 4)

```zig
const TjanstError = error { // Definiera egna feltyper
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
    arbetaMedTjanster() catch |err| { // Hantera fel
        // Matcha utifrån vilket fel som påträffas
        const tjanst = switch(err) { // Switch fungerar här som ett uttryck
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

// Deklaration av ett test
test "Exempel på test" {
    const int = try parseIntAndSquare("1337");
    try std.testing.expectEqual(1787569, int);
}
```

---

# Comptime

```zig
fn generateFibonacci(comptime n: usize) [n]u64 {
    @setEvalBranchQuota(10000); // Begränsa antalet beräkningar
    comptime var fibs: [n]u64 = undefined;
    comptime var i: usize = 0;
    inline while (i < n) : (i += 1) {
        fibs[i] = switch (i) {
            0, 1 => 1,
            else => fibs[i-1] + fibs[i-2],
        };
    }
    return fibs;
}

// Skapa en lista av de 10 första talen i Fibonacci-serien
const fib10 = generateFibonacci(10); 
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
    defer rl.CloseWindow(); // utför vid scopets slut
    rl.SetTargetFPS(60);
    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.RAYWHITE);
        rl.DrawText("Hello, World!", 190, 200, 20, rl.LIGHTGRAY);
    }
}
```
---

# Tack för oss!

Kontakt:
* adam.temmel@knowit.se
* fredrik.kahre@knowit.se

Länkar:
* https://knowit-norrland.github.io/zig/  (Presentation)
* https://github.com/knowit-norrland/good-tech-zig  (Källkod)

---

# Synpunkter

!(qr.png)
