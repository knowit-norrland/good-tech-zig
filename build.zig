const std = @import("std");
const fs = std.fs;
const builtin = @import("builtin");

const emscriptenSrc = "src/raylib/emscripten/";
const webCachedir = ".zig-cache/web/";
const webOutdir = "zig-out/web/";
const raylibSrc = "src/";
const raylibBindingSrc = "";

const APP_NAME = "good-tech-zig";

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    const is_wasm = target.result.cpu.arch == .wasm32;

    if (is_wasm and b.sysroot == null) {
        @panic("Pass '--sysroot \"[path to emsdk installation]/upstream/emscripten\"'");
    }

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    if (is_wasm) {
        buildWasm(b, target, optimize) catch unreachable;
        return;
    }

    const exe = b.addExecutable(.{
        .name = "good-tech-zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = .ReleaseFast,
        .rmodels = false,
        .shared = true,
    });

    exe.linkLibrary(raylib_dep.artifact("raylib"));

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.linkLibrary(raylib_dep.artifact("raylib"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

pub fn buildWasm(b: *std.Build, target: std.Build.ResolvedTarget, optimize: anytype) !void {
    const lib = b.addStaticLibrary(.{
        .name = "good-tech-zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = .ReleaseFast,
        .rmodels = false,
        .shared = true,
    });

    const emcc_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "emcc" });
    defer b.allocator.free(emcc_path);
    const emranlib_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "emranlib" });
    defer b.allocator.free(emranlib_path);
    const emar_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "emar" });
    defer b.allocator.free(emar_path);
    const include_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "cache", "sysroot", "include" });
    defer b.allocator.free(include_path);

    fs.cwd().makePath(webCachedir) catch {};
    fs.cwd().makePath(webOutdir) catch {};

    const warnings = ""; //-Wall

    const rcoreO = b.addSystemCommand(&.{emcc_path});
    rcoreO.addArgs(&.{ "-Os", warnings, "-c" });
    rcoreO.addFileArg(raylib_dep.path("src/rcore.c"));
    rcoreO.addArgs(&.{ "-o", webCachedir ++ "rcore.o" });
    rcoreO.addArgs(&.{ "-Os", warnings, "-DPLATFORM_WEB", "-DGRAPHICS_API_OPENGL_ES2" });

    const rshapesO = b.addSystemCommand(&.{emcc_path});
    rshapesO.addArgs(&.{ "-Os", warnings, "-c" });
    rshapesO.addFileArg(raylib_dep.path("src/rshapes.c"));
    rshapesO.addArgs(&.{ "-o", webCachedir ++ "rshapes.o" });
    rshapesO.addArgs(&.{ "-Os", warnings, "-DPLATFORM_WEB", "-DGRAPHICS_API_OPENGL_ES2" });

    const rtexturesO = b.addSystemCommand(&.{emcc_path});
    rtexturesO.addArgs(&.{ "-Os", warnings, "-c" });
    rtexturesO.addFileArg(raylib_dep.path("src/rtextures.c"));
    rtexturesO.addArgs(&.{ "-o", webCachedir ++ "rtextures.o" });
    rtexturesO.addArgs(&.{ "-Os", warnings, "-DPLATFORM_WEB", "-DGRAPHICS_API_OPENGL_ES2" });

    const rtextO = b.addSystemCommand(&.{emcc_path});
    rtextO.addArgs(&.{ "-Os", warnings, "-c" });
    rtextO.addFileArg(raylib_dep.path("src/rtext.c"));
    rtextO.addArgs(&.{ "-o", webCachedir ++ "rtext.o" });
    rtextO.addArgs(&.{ "-Os", warnings, "-DPLATFORM_WEB", "-DGRAPHICS_API_OPENGL_ES2" });

    const rmodelsO = b.addSystemCommand(&.{emcc_path});
    rmodelsO.addArgs(&.{ "-Os", warnings, "-c" });
    rmodelsO.addFileArg(raylib_dep.path("src/rmodels.c"));
    rmodelsO.addArgs(&.{ "-o", webCachedir ++ "rmodels.o" });
    rmodelsO.addArgs(&.{ "-Os", warnings, "-DPLATFORM_WEB", "-DGRAPHICS_API_OPENGL_ES2" });

    const utilsO = b.addSystemCommand(&.{emcc_path});
    utilsO.addArgs(&.{ "-Os", warnings, "-c" });
    utilsO.addFileArg(raylib_dep.path("src/utils.c"));
    utilsO.addArgs(&.{ "-o", webCachedir ++ "utils.o" });
    utilsO.addArgs(&.{ "-Os", warnings, "-DPLATFORM_WEB", "-DGRAPHICS_API_OPENGL_ES2" });

    const raudioO = b.addSystemCommand(&.{emcc_path});
    raudioO.addArgs(&.{ "-Os", warnings, "-c" });
    raudioO.addFileArg(raylib_dep.path("src/raudio.c"));
    raudioO.addArgs(&.{ "-o", webCachedir ++ "raudio.o" });
    raudioO.addArgs(&.{ "-Os", warnings, "-DPLATFORM_WEB", "-DGRAPHICS_API_OPENGL_ES2" });

    const libraylibA = b.addSystemCommand(&.{
        emar_path,
        "rcs",
        webCachedir ++ "libraylib.a",
        webCachedir ++ "rcore.o",
        webCachedir ++ "rshapes.o",
        webCachedir ++ "rtextures.o",
        webCachedir ++ "rtext.o",
        webCachedir ++ "rmodels.o",
        webCachedir ++ "utils.o",
        webCachedir ++ "raudio.o",
    });
    const emranlib = b.addSystemCommand(&.{
        emranlib_path,
        webCachedir ++ "libraylib.a",
    });

    libraylibA.step.dependOn(&rcoreO.step);
    libraylibA.step.dependOn(&rshapesO.step);
    libraylibA.step.dependOn(&rtexturesO.step);
    libraylibA.step.dependOn(&rtextO.step);
    libraylibA.step.dependOn(&rmodelsO.step);
    libraylibA.step.dependOn(&utilsO.step);
    libraylibA.step.dependOn(&raudioO.step);
    emranlib.step.dependOn(&libraylibA.step);

    //only build raylib if not already there
    _ = fs.cwd().statFile(webCachedir ++ "libraylib.a") catch {
        lib.step.dependOn(&emranlib.step);
    };

    lib.defineCMacro("__EMSCRIPTEN__", null);
    lib.defineCMacro("PLATFORM_WEB", null);
    std.log.info("emscripten include path: {s}", .{include_path});
    lib.addIncludePath(.{ .cwd_relative = include_path });
    lib.addIncludePath(.{ .cwd_relative = emscriptenSrc });
    lib.addIncludePath(.{ .cwd_relative = raylibBindingSrc });
    lib.addIncludePath(raylib_dep.path(raylibSrc));
    lib.addIncludePath(raylib_dep.path(raylibSrc ++ "extras/"));
    lib.root_module.addAnonymousImport("raylib", .{ .root_source_file = raylib_dep.path(raylibBindingSrc ++ "build.zig") });

    const libraryOutputFolder = "zig-out/lib/";
    // this installs the lib (libraylib-zig-examples.a) to the `libraryOutputFolder` folder
    b.installArtifact(lib);

    const shell = switch (optimize) {
        .Debug => emscriptenSrc ++ "shell.html",
        else => emscriptenSrc ++ "minshell.html",
    };

    const emcc = b.addSystemCommand(&.{
        emcc_path,
        "-o",
        webOutdir ++ "game.html",

        emscriptenSrc ++ "entry.c",
        raylibBindingSrc ++ "marshal.c",

        libraryOutputFolder ++ "lib" ++ "good-tech-zig" ++ ".a",
        "-I.",
        "-I" ++ raylibSrc,
        "-I" ++ emscriptenSrc,
        "-I" ++ raylibBindingSrc,
        "-L.",
        "-L" ++ webCachedir,
        "-L" ++ libraryOutputFolder,
        "-lraylib",
        "-l" ++ APP_NAME,
        "--shell-file",
        shell,
        "-DPLATFORM_WEB",
        "-DRAYGUI_IMPLEMENTATION",
        "-sUSE_GLFW=3",
        "-sWASM=1",
        "-sALLOW_MEMORY_GROWTH=1",
        "-sWASM_MEM_MAX=512MB", //going higher than that seems not to work on iOS browsers ¯\_(ツ)_/¯
        "-sTOTAL_MEMORY=512MB",
        "-sABORTING_MALLOC=0",
        "-sASYNCIFY",
        "-sFORCE_FILESYSTEM=1",
        "-sASSERTIONS=1",
        "--memory-init-file",
        "0",
        "--preload-file",
        "assets",
        "--source-map-base",
        "-O1",
        "-Os",
        // "-sLLD_REPORT_UNDEFINED",
        "-sERROR_ON_UNDEFINED_SYMBOLS=0",

        // optimizations
        "-O1",
        "-Os",

        // "-sUSE_PTHREADS=1",
        // "--profiling",
        // "-sTOTAL_STACK=128MB",
        // "-sMALLOC='emmalloc'",
        // "--no-entry",
        "-sEXPORTED_FUNCTIONS=['_malloc','_free','_main', '_emsc_main','_emsc_set_window_size']",
        "-sEXPORTED_RUNTIME_METHODS=ccall,cwrap",
    });

    emcc.step.dependOn(&lib.step);

    b.getInstallStep().dependOn(&emcc.step);
    //-------------------------------------------------------------------------------------

    std.log.info("\n\nOutput files will be in {s}\n---\ncd {s}\npython -m http.server\n---\n\nbuilding...", .{ webOutdir, webOutdir });
}
