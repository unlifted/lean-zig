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

- **copy_file_range_stub.c** - C source for the stub function
- **copy_file_range_stub.o** - Compiled object file (committed for convenience)

## Rebuilding the Stub

If needed, recompile with:

```bash
gcc -c -fPIC copy_file_range_stub.c -o copy_file_range_stub.o
```

## Why This Works

The Zig standard library includes `copy_file_range` in its symbol table but the actual function is only called in filesystem code paths that lean-zig doesn't exercise. By providing a stub that returns ENOSYS, we:

1. Satisfy the linker (no undefined symbols)
2. Maintain correct behavior (stub signals "not implemented")
3. Avoid runtime issues (function is never actually called)

## Future

This workaround will be unnecessary once either:
- Lean runtime is updated to use glibc 2.38+
- Zig provides a build option to exclude unused std library features
- Zig's conditional compilation better eliminates unreachable code paths

## References

- Zig issue tracking copy_file_range: https://github.com/ziglang/zig/issues/17450
- Lean runtime bundled with glibc 2.27 (check with `ldd $(lean --print-prefix)/bin/lean`)
