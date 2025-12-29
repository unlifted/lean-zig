# Multi-Version Support Strategy

This document explains how `lean-zig` supports multiple versions of Lean and Zig without creating exponential version combinations.

## Overview

**Goal**: Support multiple Lean and Zig versions with a single codebase, avoiding `numLeanVersions × numZigVersions` library releases.

**Strategy**: Runtime detection + conditional compilation + CI matrix testing

## Lean Version Compatibility

### Automatic Binding Synchronization

The library uses a **hybrid JIT approach** that automatically adapts to your Lean installation:

1. **Build-time detection**: `build.zig` runs `lean --print-prefix` to locate your Lean installation
2. **Auto-generated bindings**: Zig's `translateC` generates FFI bindings from your `lean.h`
3. **Cold-path forwarding**: Non-critical functions use auto-generated bindings
4. **Hot-path inlining**: Performance-critical functions manually implemented in Zig

### Supported Version Ranges

Currently tested and supported:

- **Lean 4.25.0** - Stable release
- **Lean 4.26.0** - Latest stable

### Adding New Lean Versions

When a new Lean version is released:

1. **Update CI matrix** in `.github/workflows/ci.yml`:
   ```yaml
   matrix:
     lean-version: ['4.25.0', '4.26.0', '4.27.0']  # Add new version
   ```

2. **Test locally**:
   ```bash
   elan toolchain install leanprover/lean4:v4.27.0
   elan default leanprover/lean4:v4.27.0
   lake clean && lake build
   zig build test
   ```

3. **Check for ABI changes** (rare but critical):
   - Review Lean changelog for C API changes
   - Compare struct layouts in `lean.h`
   - Update manual inline functions if needed (see `Zig/memory.zig`, `Zig/boxing.zig`)

4. **Update documentation**:
   - Update version badge in README.md
   - Note any breaking changes in CHANGELOG.md

### Conditional Compilation for Lean

If Lean introduces breaking changes between versions, add version detection:

```zig
// In Zig/lean.zig or build.zig
const lean_version = @import("lean_version"); // Generated at build time

pub inline fn objectTag(o: b_obj_arg) u8 {
    // Example: handle struct layout change
    if (lean_version.minor >= 27) {
        // New layout after 4.27.0
        return @as(*const Object, @ptrCast(@alignCast(o))).m_tag_new;
    } else {
        // Legacy layout
        return @as(*const Object, @ptrCast(@alignCast(o))).m_tag;
    }
}
```

To generate version info at build time, add to `build.zig`:

```zig
fn detectLeanVersion(b: *std.Build, lean_exe: []const u8) !struct { major: u32, minor: u32, patch: u32 } {
    const result = b.run(&[_][]const u8{ lean_exe, "--version" });
    // Parse: "Lean (version 4.26.0, commit ...)"
    // ... parsing logic ...
    return .{ .major = major, .minor = minor, .patch = patch };
}
```

## Zig Version Compatibility

### Supported Version Ranges

- **Zig 0.14.0** - Previous stable
- **Zig 0.15.2** - Current development target

### Zig API Stability Challenges

**Problem**: Zig is pre-1.0 and breaks APIs between minor versions.

**Solution**: Compatibility shims for common API changes.

### Conditional Compilation for Zig

Use Zig's builtin version info:

```zig
// In Zig/compat.zig (create if needed)
const builtin = @import("builtin");
const std = @import("std");

pub fn pathJoin(b: *std.Build, parts: []const []const u8) []const u8 {
    const zig_version = builtin.zig_version;
    
    if (zig_version.order(.{ .major = 0, .minor = 13, .patch = 0 }) == .lt) {
        // Zig < 0.13: use old API
        return std.fs.path.join(b.allocator, parts) catch unreachable;
    } else {
        // Zig >= 0.13: use new API
        return b.pathJoin(parts);
    }
}
```

### Common Zig API Changes to Handle

| Change | Zig Versions | Solution |
|--------|--------------|----------|
| `b.pathJoin()` introduction | < 0.13 vs >= 0.13 | Compatibility wrapper |
| `@alignCast` became mandatory | < 0.11 vs >= 0.11 | Always use explicit casts |
| Module system changes | < 0.12 vs >= 0.12 | Use new `addModule` API |

## CI Matrix Testing

### Current Matrix

Our CI uses a **smart optimization strategy**:

**Pull Requests** (fast feedback):
```yaml
os: [ubuntu-latest]
lean-version: ['4.26.0']
zig-version: ['0.15.2']
# 1 job - quick validation
```

**Main Branch** (comprehensive testing):
```yaml
os: [ubuntu-latest, macos-latest, windows-latest]
lean-version: ['4.25.0', '4.26.0']
zig-version: ['0.14.0', '0.15.2']
# 12 jobs - full coverage
```

This approach provides:
- ✅ **Fast PR feedback** (~5 min instead of ~15-20 min)
- ✅ **Comprehensive main branch testing** (all combinations verified before release)
- ✅ **Cost-effective** (saves macOS minutes on private repos)

### Excluding Incompatible Combinations

If certain combinations don't work:

```yaml
matrix:
  os: [ubuntu-latest, macos-latest, windows-latest]
  lean-version: ['4.25.0', '4.26.0']
  zig-version: ['0.14.0', '0.15.2']
  exclude:
    - os: windows-latest
      lean-version: '4.25.0'
      zig-version: '0.14.0'  # Example: this combo has known issue
```

### Platform-Specific Considerations

**Linux (ubuntu-latest)**
- Primary development and testing platform
- Fastest CI builds
- Standard glibc toolchain

**macOS (macos-latest)**
- Tests against Apple Silicon and Intel
- Different C++ ABI than Linux
- Validates Darwin-specific build paths

**Windows (windows-latest)**
- Uses PowerShell for commands (no bash)
- Different path separators (`\` vs `/`)
- MSVC toolchain for C/C++ interop
- Validates Windows-specific Lean runtime builds

### Adding Matrix Dimensions

You can test more combinations:

```yaml
matrix:
  os: [ubuntu-latest, macos-latest, windows-latest]
  lean-version: ['4.25.0', '4.26.0']
  zig-version: ['0.14.0', '0.15.2']
  # This creates 3 × 2 × 2 = 12 test jobs
```

## Version Badge Strategy

### Dynamic Badges

Update README badges to reflect version ranges:

```markdown
[![Lean Version](https://img.shields.io/badge/Lean-4.25.0--4.26.0-blue.svg)](https://github.com/leanprover/lean4)
[![Zig Version](https://img.shields.io/badge/Zig-0.14.0--0.15.2-orange.svg)](https://ziglang.org/)
```

### CI Matrix Badge

Show CI matrix status:

```markdown
[![CI Matrix](https://github.com/efvincent/lean-zig/actions/workflows/ci.yml/badge.svg)](https://github.com/efvincent/lean-zig/actions/workflows/ci.yml)
```

The badge shows overall status - green only if all matrix combinations pass.

## Semantic Versioning Strategy

### Library Versions vs. Dependency Versions

- **Library version** (e.g., `0.3.0`): Your `lean-zig` release version
- **Dependency versions**: Supported Lean/Zig versions

**Key principle**: One library release supports multiple dependency versions.

### Version Compatibility Documentation

In `lakefile.lean`, document supported versions:

```lean
-- lean-zig v0.3.0
-- 
-- Tested with:
-- - Lean: 4.25.0 - 4.26.0
-- - Zig: 0.14.0 - 0.15.2
--
-- Users can specify their preferred versions via lean-toolchain and PATH
```

### When to Increment Library Version

Follow semantic versioning based on **API changes**, not dependency version support:

- **MAJOR (v1.0.0 → v2.0.0)**: Breaking API changes
- **MINOR (v0.3.0 → v0.4.0)**: New features, adding support for new Lean/Zig versions
- **PATCH (v0.3.0 → v0.3.1)**: Bug fixes, documentation

**Example**: Adding Lean 4.27.0 support is a **MINOR** bump (new feature), not a new major version.

## User Configuration

### Users Choose Their Versions

Users control which versions they use:

1. **Lean version**: Via `lean-toolchain` file in their project:
   ```
   leanprover/lean4:v4.26.0
   ```

2. **Zig version**: Via their `$PATH` or `elan` equivalents:
   ```bash
   # User's environment
   zig version  # 0.15.2
   ```

3. **lean-zig library**: Via Lake dependency:
   ```lean
   require «lean-zig» from git
     "https://github.com/efvincent/lean-zig" @ "v0.3.0"
   ```

### Build-Time Detection

When users build, `build.zig`:
1. Detects their Lean installation (`lean --print-prefix`)
2. Generates bindings from their `lean.h`
3. Compiles with their Zig version

**Result**: Single library version works with all supported Lean/Zig combinations.

## Testing Locally with Multiple Versions

### Test Different Lean Versions

```bash
# Test with Lean 4.25.0
elan toolchain install leanprover/lean4:v4.25.0
elan default leanprover/lean4:v4.25.0
lake clean && lake build && zig build test

# Test with Lean 4.26.0
elan toolchain install leanprover/lean4:v4.26.0
elan default leanprover/lean4:v4.26.0
lake clean && lake build && zig build test
```

### Test Different Zig Versions

If you have multiple Zig installations:

```bash
# Test with Zig 0.14.0
PATH=/path/to/zig-0.14.0:$PATH lake clean && lake build

# Test with Zig 0.15.2
PATH=/path/to/zig-0.15.2:$PATH lake clean && lake build
```

Or use Zig version managers like `zigup`:

```bash
zigup 0.14.0
lake clean && lake build

zigup 0.15.2
lake clean && lake build
```

## Maintenance Workflow

### When Lean Releases New Version

1. Add to CI matrix
2. Run local tests
3. Check for ABI changes in release notes
4. Update manually inlined functions if needed
5. Update documentation
6. Bump library MINOR version if adding support

### When Zig Releases New Version

1. Add to CI matrix
2. Check for build system API changes
3. Add compatibility shims if needed
4. Run local tests
5. Update documentation
6. Bump library MINOR version if adding support

### Dropping Old Version Support

When dropping support for old versions:

1. Remove from CI matrix
2. Update documentation and badges
3. Bump library MAJOR version (breaking change)
4. Note in CHANGELOG under "REMOVED" section

**Example**:
```markdown
## [1.0.0] - 2026-01-01

### REMOVED
- Dropped support for Lean < 4.25.0
- Dropped support for Zig < 0.14.0
```

## Best Practices

1. **Test the matrix in CI**: Don't guess - verify all combinations work
2. **Document version ranges clearly**: Users need to know what works
3. **Use semantic versioning**: API changes increment versions, dependency support doesn't require new major versions
4. **Minimize conditional compilation**: Keep version-specific code isolated
5. **Automate detection**: Let build system detect versions at compile time
6. **Fail early**: If incompatible versions detected, fail build with clear error message

## Example: Incompatible Version Detection

Add to `build.zig`:

```zig
fn validateVersions(b: *std.Build, lean_version: Version, zig_version: Version) !void {
    // Check minimum Lean version
    if (lean_version.order(.{ .major = 4, .minor = 25, .patch = 0 }) == .lt) {
        std.debug.print("ERROR: lean-zig requires Lean >= 4.25.0, found {}\n", .{lean_version});
        return error.UnsupportedLeanVersion;
    }
    
    // Check maximum Lean version (if known incompatible)
    if (lean_version.order(.{ .major = 4, .minor = 28, .patch = 0 }) == .gt) {
        std.debug.print("WARNING: lean-zig tested up to Lean 4.27.0, found {}. May work but not guaranteed.\n", .{lean_version});
    }
    
    // Check Zig version
    if (zig_version.order(.{ .major = 0, .minor = 14, .patch = 0 }) == .lt) {
        std.debug.print("ERROR: lean-zig requires Zig >= 0.14.0, found {}\n", .{zig_version});
        return error.UnsupportedZigVersion;
    }
}
```

## Summary

✅ **One library version** supports multiple OS + Lean + Zig versions

✅ **CI matrix** tests all 12 combinations automatically (3 OS × 2 Lean × 2 Zig)

✅ **Users choose** their OS, Lean, and Zig versions independently

✅ **Build-time detection** adapts bindings to user's environment

✅ **Semantic versioning** based on API changes, not dependency versions

✅ **Clear documentation** of supported version ranges and platforms

This approach scales much better than maintaining separate library versions for each combination!
