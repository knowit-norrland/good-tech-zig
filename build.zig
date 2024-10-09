const std = @import("std");
const rlz = @import("raylib-zig");
const fs = std.fs;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "good-tech-zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const presentation_path = b.option([]const u8, "present", "Ge en sökväg för den presentationsfil som skall bakas in");
    const options = b.addOptions();

    options.addOption([]const u8, "present", presentation_path orelse "");
    exe.root_module.addOptions("build_options", options);

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    if (target.query.os_tag == .emscripten) {
        const exe_lib = rlz.emcc.compileForEmscripten(b, "steroids.zig", "src/main.zig", target, optimize);
        exe_lib.root_module.addOptions("build_options", options);

        exe_lib.linkLibrary(raylib_artifact);

        exe_lib.root_module.addImport("raylib", raylib);

        const include_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "cache", "sysroot", "include" });

        defer b.allocator.free(include_path);

        exe_lib.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = include_path } });

        exe_lib.linkLibC();

        // linking raylib to the exe_lib output file.
        const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });

        // Use the custom HTML template
        // This will be the index.html where the game is rendered.
        // You can find an example in my repository.
        link_step.addArg("--shell-file");
        link_step.addArg("shell.html");

        // Embed the assets directory
        // This generates an index.data file which is neede for the game to run.

        link_step.addArg("--preload-file");
        link_step.addArg("presentation");
        link_step.addArg("-sALLOW_MEMORY_GROWTH");
        //link_step.addArg("-sWASM_MEM_MAX=16MB");
        link_step.addArg("-sTOTAL_MEMORY=16MB");
        link_step.addArg("-sERROR_ON_UNDEFINED_SYMBOLS=0");
        link_step.addArg("-sUSE_OFFSET_CONVERTER");
        link_step.addArg("-sASSERTIONS");

        // Add any other flags you need
        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rlz.emcc.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run the game");
        run_option.dependOn(&run_step.step);
        return;
    }

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
