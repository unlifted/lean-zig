const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Step 1: Determine Lean sysroot
    // First check for explicit -Dlean_sysroot option, otherwise auto-detect
    const lean_sysroot = b.option([]const u8, "lean_sysroot", "Path to Lean installation root") orelse blk: {
        // Auto-detect by running `lean --print-prefix`
        const lean_exe = b.findProgram(&[_][]const u8{"lean"}, &[_][]const u8{}) catch {
            std.debug.print("ERROR: 'lean' not found in PATH. Please install Lean or specify -Dlean_sysroot\n", .{});
            std.process.exit(1);
        };

        const result = b.run(&[_][]const u8{ lean_exe, "--print-prefix" });
        // Trim whitespace/newlines from output
        const prefix = std.mem.trim(u8, result, " \t\n\r");
        break :blk b.dupe(prefix);
    };

    std.debug.print("Using Lean sysroot: {s}\n", .{lean_sysroot});

    // Step 2: Locate lean.h header file
    const lean_header = b.pathJoin(&[_][]const u8{ lean_sysroot, "include", "lean", "lean.h" });
    const lean_include = b.pathJoin(&[_][]const u8{ lean_sysroot, "include" });

    // Verify the header exists and fail early if it does not
    std.fs.accessAbsolute(lean_header, .{}) catch {
        std.debug.print("ERROR: Cannot access lean.h at: {s}\n", .{lean_header});
        std.debug.print("Please ensure Lean is installed correctly or provide a valid -Dlean_sysroot\n", .{});
        std.process.exit(1);
    };

    // Step 3: Use translateC to generate bindings from lean.h
    const translate = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = lean_header },
        .target = target,
        .optimize = optimize,
    });

    // Add include path for lean headers
    translate.addIncludePath(.{ .cwd_relative = lean_include });

    // Create the lean_raw module from translated C bindings
    const lean_raw_module = translate.createModule();

    // Step 4: Create the main lean-zig library module
    const lean_zig_module = b.addModule("lean-zig", .{
        .root_source_file = b.path("Zig/lean.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import lean_raw into our lean-zig module
    lean_zig_module.addImport("lean_raw", lean_raw_module);

    // Step 5: Create a static library artifact (optional, for external linking)
    const lib = b.addLibrary(.{
        .name = "lean-zig",
        .root_module = lean_zig_module,
    });

    // Link against Lean runtime
    lib.linkLibC();
    lib.linkLibCpp();
    
    if (target.result.os.tag == .windows) {
        // On Windows, static libraries are in bin/ directory with lib prefix
        const lean_bin = b.pathJoin(&[_][]const u8{ lean_sysroot, "bin" });
        lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_bin, "libleanrt.a" }) });
        lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_bin, "libleanshared.dll.a" }) });
    } else {
        // On Unix, use standard library search
        const lean_lib = b.pathJoin(&[_][]const u8{ lean_sysroot, "lib", "lean" });
        lib.addLibraryPath(.{ .cwd_relative = lean_lib });
        lib.linkSystemLibrary("leanrt");
        lib.linkSystemLibrary("leanshared");
    }

    b.installArtifact(lib);

    // Step 6: Create test executable
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("Zig/lean_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    tests.root_module.addImport("lean_raw", lean_raw_module);

    // Link test executable against Lean runtime
    tests.linkLibC();
    tests.linkLibCpp();
    
    if (target.result.os.tag == .windows) {
        // On Windows, static libraries are in bin/ directory with lib prefix
        const lean_bin = b.pathJoin(&[_][]const u8{ lean_sysroot, "bin" });
        tests.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_bin, "libleanrt.a" }) });
        tests.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_bin, "libleanshared.dll.a" }) });
    } else {
        // On Unix, use standard library search
        const lean_lib = b.pathJoin(&[_][]const u8{ lean_sysroot, "lib", "lean" });
        tests.addLibraryPath(.{ .cwd_relative = lean_lib });
        tests.linkSystemLibrary("leanrt");
        tests.linkSystemLibrary("leanshared");
    }

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    // Step 7: Default build step
    const build_step = b.step("build", "Build the lean-zig library");
    build_step.dependOn(&lib.step);
}
