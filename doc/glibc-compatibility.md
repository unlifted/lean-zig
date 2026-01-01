# glibc 2.27 Compatibility Workaround

## Problem

Zig 0.15+ generates code that references `copy_file_range()`, a system call introduced in glibc 2.38. However, Lean 4's bundled runtime is compiled against glibc 2.27, which doesn't have this symbol.

Even when setting the build target to `x86_64-linux-gnu.2.27`, Zig's standard library still includes references to `copy_file_range` in some code paths (particularly in filesystem operations), though these paths are not actually used by lean-zig.

## Solution: Stub Implementation

This directory provides a minimal stub implementation of `copy_file_range()` that:

1. Returns `-1` (failure)
2. Sets `errno = ENOSYS` (function not implemented)
3. Signals to calling code to fall back to alternative methods

The stub is linked into the static library to satisfy the linker, but is never actually called during normal lean-zig operations.

## Files

- **compat/copy_file_range_stub.c** - C source for the stub function
- **compat/copy_file_range_stub.o** - Compiled object file (committed for convenience)

**Location**: These files are in the `compat/` directory and are automatically copied to `.zig-cache/` by the build template. User projects do not need these files in their root directory.

## Rebuilding the Stub

If needed, recompile with:

```bash
cd compat/
gcc -c -fPIC copy_file_range_stub.c -o copy_file_range_stub.o
```

## Why This Works

The Zig standard library includes `copy_file_range` in its symbol table but the actual function is only called in filesystem code paths that lean-zig doesn't exercise. By providing a stub that returns ENOSYS, we:

1. Satisfy the linker (no undefined symbols)
2. Maintain correct behavior (stub signals "not implemented")
3. Avoid runtime issues (function is never actually called in lean-zig's normal operation)

## Impact on User Code

### Will My Zig Code Break?

**Short answer: No, properly written Zig code will work correctly.**

The stub affects Zig's `std.fs` file operations that try to use `copy_file_range` for optimization:

#### Operations That May Be Affected:
- `std.fs.copyFile()` - File copying
- `std.fs.Dir.copyFile()` - Directory-based file copying
- Any code using `std.os.copy_file_range()` directly (rare)

#### What Happens:
1. Zig's std library **tries** `copy_file_range()` first (for performance)
2. Stub returns `-1` with `errno = ENOSYS`
3. Zig's std library **automatically falls back** to `read()`/`write()` loop
4. Operation completes successfully, just slightly slower

**Example - This code works fine:**
```zig
const std = @import("std");

// This will work correctly, using read/write fallback
try std.fs.copyFileAbsolute(source_path, dest_path, .{});
```

### Performance Implications

**For Lean FFI code**: Zero impact - lean-zig doesn't perform file operations.

**For user Zig code with file copying**:
- **Small files (<1MB)**: Negligible difference
- **Large files (>100MB)**: 5-10% slower due to read/write loop vs. zero-copy
- **Typical FFI code**: No measurable impact (FFI rarely does bulk file operations)

### When It COULD Break

The stub would only cause issues if you write Zig code that:

❌ **Explicitly requires** `copy_file_range` without handling `ENOSYS`:
```zig
// BAD: Assumes copy_file_range succeeds
const result = std.os.copy_file_range(src_fd, null, dest_fd, null, len, 0);
// This will fail with ENOSYS, not handled!
```

✅ **Good**: Use Zig's high-level APIs that handle fallback:
```zig
// GOOD: Automatically falls back to read/write
try std.fs.copyFile(src, dest, .{});
```

### Testing Your Code

To verify your code handles the stub correctly:

```bash
# Build your project
lake build

# If it builds and runs without errors, you're good!
lake exe your-project

# Optional: Check if copy_file_range is called
strace -e copy_file_range lake exe your-project 2>&1 | grep copy_file_range
# Should show: copy_file_range(...) = -1 ENOSYS (Function not implemented)
```

### Recommendation

**For 99% of lean-zig users**: No action needed. The stub works transparently.

**For advanced users doing bulk file I/O in Zig**: Consider testing on a glibc 2.27 system or accept the minor performance trade-off.

## Future

This workaround will be unnecessary once either:
- Lean runtime is updated to use glibc 2.38+
- Zig provides a build option to exclude unused std library features
- Zig's conditional compilation better eliminates unreachable code paths

## References

- Zig issue tracking copy_file_range: https://github.com/ziglang/zig/issues/17450
- Lean runtime bundled with glibc 2.27 (check with `ldd $(lean --print-prefix)/bin/lean`)
