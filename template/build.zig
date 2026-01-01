// Template build.zig for projects using lean-zig
//
// TESTED VERSIONS (as of December 2025):
//   - Lean: 4.25.0, 4.26.0
//   - Zig: 0.14.0, 0.15.2
//   - Platforms: Linux, macOS, Windows
//
// VERSION-SPECIFIC NOTES:
//   - Zig 0.15+: Requires glibc 2.27 target on Linux (line 30)
//   - Windows: Uses direct .a linking (handled automatically line 86-92)
//   - Lean 4.25+: Library names stable (libleanrt, libleanshared)
//
// To use:
// 1. Copy this file to your project root: cp .lake/packages/lean-zig/template/build.zig ./
// 2. Customize line 38 to point to your Zig source file
// 3. Add extern_lib to your lakefile.lean (see doc/usage.md)

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

    // ═══════════════════════════════════════════════════════════════
    // CUSTOMIZE THIS: Point to your Zig FFI root source file
    // ═══════════════════════════════════════════════════════════════
    // This should be the file that exports your FFI functions with `export fn`.
    // If you have multiple Zig files, just point to the root file here -
    // Zig's build system automatically compiles any files you @import.
    //
    // Examples:
    //   Single file:     "zig/ffi.zig"
    //   Multi-file:      "zig/main.zig" (which does @import("helpers.zig"), etc.)
    //   Complex project: "src/ffi/bindings.zig"
    const ffi_module = b.createModule(.{
        .root_source_file = b.path("zig/your_code.zig"), // ← CHANGE THIS LINE
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

    // Add copy_file_range stub for glibc 2.27 compatibility (Zig 0.15+)
    // This stub provides a fallback implementation that signals ENOSYS
    lib.addObjectFile(b.path("copy_file_range_stub.o"));

    b.installArtifact(lib);
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
