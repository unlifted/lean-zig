// Template build.zig for projects using lean-zig
//
// TESTED VERSIONS (as of December 2025):
//   - Lean: 4.25.0, 4.26.0
//   - Zig: 0.14.0, 0.15.2
//   - Platforms: Linux, macOS, Windows
//
// VERSION-SPECIFIC NOTES:
//   - Zig 0.15+: Requires glibc 2.27 target on Linux (auto-configured)
//   - Windows: Uses direct .a linking (handled automatically)
//   - Lean 4.25+: Library names stable (libleanrt, libleanshared)
//
// ════════════════════════════════════════════════════════════════════════════
// ⚠️  CUSTOMIZE THIS: Set your Zig FFI source file path
// ════════════════════════════════════════════════════════════════════════════
// Replace "zig/CHANGE_ME.zig" with the path to YOUR Zig source file.
// For multi-file projects, just point to the root file.
//
// Examples:
//   - "zig/ffi.zig"              (single file)
//   - "zig/main.zig"             (multi-file, imports helpers.zig, etc.)
//   - "src/ffi/bindings.zig"     (custom structure)
//
const ZIG_FFI_SOURCE = "zig/CHANGE_ME.zig"; // ← TODO: CHANGE THIS!
//
// ════════════════════════════════════════════════════════════════════════════
// The rest of this file should not need changes for basic usage.
// ════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Auto-detect target, but override glibc version on Linux for Zig 0.15+
    const target = b.standardTargetOptions(.{});

    // Override glibc version on Linux to match Lean's bundled version (2.27)
    // This prevents "undefined reference to copy_file_range" errors with Zig 0.15+
    const target_resolved = if (target.result.os.tag == .linux and target.result.abi == .gnu)
        b.resolveTargetQuery(.{
            .cpu_arch = target.result.cpu.arch,
            .os_tag = .linux,
            .abi = .gnu,
            .glibc_version = .{ .major = 2, .minor = 27, .patch = 0 },
        })
    else
        target;

    const optimize = b.standardOptimizeOption(.{});

    // Get Lean sysroot for headers and libraries
    const lean_sysroot = getLeanSysroot(b);
    const lean_include = b.pathJoin(&[_][]const u8{ lean_sysroot, "include" });

    // Create FFI module using the path specified above
    const ffi_module = b.createModule(.{
        .root_source_file = b.path(ZIG_FFI_SOURCE),
        .target = target_resolved,
        .optimize = optimize,
        .link_libc = true,
    });

    // Get lean-zig from Lake packages directory
    const lean_zig_path = b.path(".lake/packages/lean-zig/Zig/lean.zig");
    const lean_header_path = b.pathJoin(&[_][]const u8{ lean_include, "lean", "lean.h" });

    // Generate bindings from lean.h using translateC
    // This ensures bindings match YOUR installed Lean version
    const lean_raw = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = lean_header_path },
        .target = target_resolved,
        .optimize = optimize,
    });
    lean_raw.addIncludePath(.{ .cwd_relative = lean_include });

    // Set up lean-zig module with auto-generated bindings
    const lean_zig_module = b.createModule(.{
        .root_source_file = lean_zig_path,
        .target = target_resolved,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lean_raw", .module = lean_raw.createModule() },
        },
    });
    ffi_module.addImport("lean", lean_zig_module); // Import as "lean"

    // Build the static library
    const lib = b.addLibrary(.{
        .name = "leanzig", // Must match nameToStaticLib in lakefile
        .root_module = ffi_module,
        .linkage = .static,
    });

    // Link against Lean runtime (version-aware)
    linkLeanRuntime(lib, b, lean_sysroot, target_resolved);

    // Add copy_file_range stub for glibc 2.27 compatibility (Zig 0.15+ on Linux)
    // Auto-copies stub from lean-zig package if not present in project
    addGlibcCompatStub(lib, b);

    b.installArtifact(lib);
}

// Auto-copy and link glibc compatibility stub
fn addGlibcCompatStub(lib: *std.Build.Step.Compile, b: *std.Build) void {
    const stub_src_path = ".lake/packages/lean-zig/compat/copy_file_range_stub.o";
    const stub_dest_path = ".zig-cache/copy_file_range_stub.o";

    // Try to copy stub from package to cache
    std.fs.cwd().makePath(".zig-cache") catch {};

    if (std.fs.cwd().copyFile(stub_src_path, std.fs.cwd(), stub_dest_path, .{})) {
        // Successfully copied, link it
        lib.addObjectFile(b.path(stub_dest_path));
    } else |err| {
        // Failed to copy - provide helpful error message
        std.debug.print("\n" ++ "=" ** 70 ++ "\n", .{});
        std.debug.print("ERROR: Could not find glibc compatibility stub file\n", .{});
        std.debug.print("=" ** 70 ++ "\n\n", .{});
        std.debug.print("Expected: {s}\n", .{stub_src_path});
        std.debug.print("Error: {}\n\n", .{err});
        std.debug.print("This file is required for Zig 0.15+ on Linux.\n\n", .{});
        std.debug.print("Solutions:\n", .{});
        std.debug.print("  1. Ensure lean-zig dependency is downloaded: lake build\n", .{});
        std.debug.print("  2. Check that .lake/packages/lean-zig/ exists\n", .{});
        std.debug.print("  3. See doc/glibc-compatibility.md for details\n\n", .{});
        std.debug.print("=" ** 70 ++ "\n", .{});
        std.process.exit(1);
    }
}

// Helper function to link Lean runtime libraries (platform-aware)
fn linkLeanRuntime(lib: *std.Build.Step.Compile, b: *std.Build, lean_sysroot: []const u8, target: std.Build.ResolvedTarget) void {
    lib.linkLibC();

    const lean_lib = b.pathJoin(&[_][]const u8{ lean_sysroot, "lib", "lean" });

    if (target.result.os.tag == .windows) {
        // Windows MinGW: Link .a and .dll.a files directly
        // Required libraries for Lean 4.25+ on Windows
        const gmp_lib = b.pathJoin(&[_][]const u8{ lean_sysroot, "lib" });

        lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_lib, "libleanrt.a" }) });
        lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_lib, "libleanshared.dll.a" }) });
        lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_lib, "libleanmanifest.a" }) });
        lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_lib, "libInit_shared.dll.a" }) });
        lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_lib, "libLean.a" }) });
        lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ gmp_lib, "libgmp.a" }) });
    } else {
        // Unix (Linux/macOS): Use standard library search
        lib.addLibraryPath(.{ .cwd_relative = lean_lib });
        lib.linkSystemLibrary("leanrt");
        lib.linkSystemLibrary("leanshared");
    }
}

fn getLeanSysroot(b: *std.Build) []const u8 {
    const lean_exe = b.findProgram(&[_][]const u8{"lean"}, &[_][]const u8{}) catch {
        std.debug.print("ERROR: 'lean' not found in PATH\n", .{});
        std.process.exit(1);
    };
    const result = b.run(&[_][]const u8{ lean_exe, "--print-prefix" });
    return b.dupe(std.mem.trim(u8, result, " \t\n\r"));
}
