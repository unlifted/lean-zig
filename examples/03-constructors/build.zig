const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    // Override glibc version on Linux to match Lean's bundled version (2.27)
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

    // Get Lean sysroot
    const lean_sysroot = getLeanSysroot(b);
    const lean_lib = b.pathJoin(&[_][]const u8{ lean_sysroot, "lib", "lean" });

    // Create a module for the Zig FFI code
    const ffi_module = b.createModule(.{
        .root_source_file = b.path("zig/constructors.zig"),
        .target = target_resolved,
        .optimize = optimize,
    });

    // Add lean-zig module from parent directory
    const lean_zig_path = b.path("../../Zig/lean.zig");
    const lean_include = b.pathJoin(&[_][]const u8{ lean_sysroot, "include" });

    // Create lean_raw bindings using translateC
    const lean_raw = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_include, "lean", "lean.h" }) },
        .target = target_resolved,
        .optimize = optimize,
    });
    lean_raw.addIncludePath(.{ .cwd_relative = lean_include });

    const lean_zig_module = b.createModule(.{
        .root_source_file = lean_zig_path,
        .target = target_resolved,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lean_raw", .module = lean_raw.createModule() },
        },
    });
    ffi_module.addImport("lean-zig", lean_zig_module);

    // Build the FFI library
    const lib = b.addLibrary(.{
        .name = "leanzig",
        .root_module = ffi_module,
        .linkage = .static,
    });

    // Link against Lean runtime
    lib.linkLibC();
    lib.addObjectFile(b.path("../../copy_file_range_stub.o"));
    lib.addLibraryPath(.{ .cwd_relative = lean_lib });
    lib.linkSystemLibrary("leanrt");
    lib.linkSystemLibrary("leanshared");

    b.installArtifact(lib);
}

fn getLeanSysroot(b: *std.Build) []const u8 {
    const lean_exe = b.findProgram(&[_][]const u8{"lean"}, &[_][]const u8{}) catch {
        std.debug.print("ERROR: 'lean' not found in PATH\n", .{});
        std.process.exit(1);
    };
    const result = b.run(&[_][]const u8{ lean_exe, "--print-prefix" });
    return b.dupe(std.mem.trim(u8, result, " \t\n\r"));
}
