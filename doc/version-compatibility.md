# Version Compatibility Guide

This document tracks version-specific compatibility information for lean-zig.

## Quick Summary

**Current Status (December 2025):**
- ✅ **One template works with all tested versions**
- ✅ **Lean 4.25.0 - 4.26.0**: Fully supported
- ✅ **Zig 0.14.0 - 0.15.2**: Fully supported  
- ✅ **Platforms**: Linux, macOS, Windows

The template automatically detects and adapts to your environment.

## Version Matrix

| Lean | Zig | Linux | macOS | Windows | Notes |
|------|-----|-------|-------|---------|-------|
| 4.26.0 | 0.15.2 | ✅ | ✅ | ✅ | Current recommended |
| 4.26.0 | 0.14.0 | ✅ | ✅ | ✅ | Older Zig works |
| 4.25.0 | 0.15.2 | ✅ | ✅ | ✅ | Older Lean works |
| 4.25.0 | 0.14.0 | ✅ | ✅ | ✅ | All combinations tested |

All 12 combinations (3 OS × 2 Lean × 2 Zig) pass CI tests.

## Version-Specific Changes

### Zig 0.15.0+

**Issue**: Zig 0.15 references `copy_file_range` symbol from glibc 2.38, but Lean bundles glibc 2.27.

**Solution**: Template automatically sets glibc 2.27 target on Linux (lines 24-33 in template/build.zig):

```zig
const target_resolved = if (target.result.os.tag == .linux and target.result.abi == .gnu)
    b.resolveTargetQuery(.{
        .cpu_arch = target.result.cpu.arch,
        .os_tag = .linux,
        .abi = .gnu,
        .glibc_version = .{ .major = 2, .minor = 27, .patch = 0 },
    })
else
    target;
```

**Impact**: Zero - handled automatically by template.

### Zig 0.14.0

**Behavior**: No glibc compatibility issue. Works with default target.

**Template handling**: Glibc override only applies to 0.15+, so 0.14 unaffected.

### Lean 4.25.0 vs 4.26.0

**Library Names**: Unchanged between versions
- `libleanrt.a` / `libleanrt.so`
- `libleanshared.a` / `libleanshared.so`
- On Windows: 6 additional libraries (libleanmanifest, libInit_shared, libLean, libgmp)

**Header Structure**: `lean.h` structure stable, `translateC` generates compatible bindings.

**Impact**: Zero - same template works for both.

### Windows Platform

**Issue**: MinGW linker requires direct `.a` file paths instead of `-l` flags.

**Solution**: Template detects Windows and uses `addObjectFile` instead of `linkSystemLibrary` (lines 86-99):

```zig
if (target.result.os.tag == .windows) {
    // Link .a files directly
    lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_lib, "libleanrt.a" }) });
    lib.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{ lean_lib, "libleanshared.dll.a" }) });
    // ... 4 more libraries
} else {
    // Unix: use standard linking
    lib.addLibraryPath(.{ .cwd_relative = lean_lib });
    lib.linkSystemLibrary("leanrt");
    lib.linkSystemLibrary("leanshared");
}
```

**Required Windows Libraries** (Lean 4.25+):
1. `libleanrt.a`
2. `libleanshared.dll.a`
3. `libleanmanifest.a`
4. `libInit_shared.dll.a`
5. `libLean.a`
6. `libgmp.a` (from `lib/` not `lib/lean/`)

**Impact**: Zero - handled automatically by template.

### macOS Platform

**Behavior**: Standard Unix linking, no special handling needed.

**Apple Silicon**: Works on both Intel and ARM (tested on macos-latest in CI).

## Future Version Compatibility

### When Lean Updates

**Likely Compatible:**
- Minor Lean updates (4.27.0, 4.28.0) with stable C ABI
- Header additions (new functions won't break existing code)

**May Break:**
- Major Lean version (5.0.0) if C ABI changes
- Renaming core runtime libraries
- Changing `lean --print-prefix` output format

**What to do:**
1. Update lean-zig to latest version
2. Check CHANGELOG for breaking changes
3. Test with `lake clean && lake build`
4. Report issues on GitHub if problems occur

### When Zig Updates

**Likely Compatible:**
- Patch updates (0.15.3, 0.15.4) - bug fixes only
- Minor updates (0.16.0) if build system API stable

**May Break:**
- Zig 1.0.0 (expected 2025-2026) - major API stabilization
- Build system redesign
- Breaking changes to `translateC`

**What to do:**
1. Check lean-zig releases for Zig 1.0 support
2. Template may need updates for new Zig APIs
3. We will publish updated templates as needed

## Upgrade Path

### Upgrading Lean

```bash
# Update Lean version
elan install leanprover/lean4:v4.27.0  # Example future version

# Rebuild (bindings regenerate automatically)
lake clean && lake build
```

**If build fails:**
1. Check lean-zig releases for compatibility notes
2. Update lean-zig: `lake update`
3. Re-copy template if changes noted: `cp .lake/packages/lean-zig/template/build.zig ./`

### Upgrading Zig

```bash
# Update Zig
elan install zig-0.16.0  # Example future version

# Rebuild
zig build clean && lake build
```

**If build fails:**
1. Check Zig release notes for build system changes
2. Check lean-zig releases for updated template
3. Re-copy template if updated

### Downgrading

**To use older versions:**

```bash
# Pin Lean version
echo "leanprover/lean4:v4.25.0" > lean-toolchain

# Pin Zig version  
# (depends on your Zig installation method - elan, manual, etc.)
```

The template supports Lean 4.25.0+ and Zig 0.14.0+, so downgrading within tested ranges should work.

## Breaking Change Policy

When a new Lean or Zig version introduces breaking changes:

1. **Template Update**: We update `template/build.zig` with version-specific logic
2. **Documentation**: Add notes to this file explaining changes
3. **CHANGELOG**: Document breaking changes with migration guide
4. **CI**: Add new version to test matrix
5. **Release**: Cut new lean-zig version with updated template

**Versioning impact:**
- **Template changes only**: Patch version (0.x.y+1)
- **API compatibility breaks**: Major version (1.0.0 → 2.0.0)

## Detecting Your Versions

```bash
# Check Lean version
lean --version

# Check Zig version  
zig version

# Check which template version you're using
head -20 build.zig | grep "TESTED VERSIONS"
```

## Reporting Compatibility Issues

If you encounter compatibility issues:

1. **Check versions**: Run commands above
2. **Check existing issues**: Search [GitHub Issues](https://github.com/unlifted/lean-zig/issues)
3. **Report new issue** with:
   - Lean version
   - Zig version
   - Platform (Linux/macOS/Windows)
   - Error message
   - Minimal reproduction if possible

## See Also

- [CHANGELOG.md](../CHANGELOG.md) - Version history and breaking changes
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Maintainer guide for handling version updates
- [README.md](../README.md) - Supported version policy
