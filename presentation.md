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

# Ergonomisk felhantering

---

# Strikt men generöst typsystem

---
