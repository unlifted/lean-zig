# Example 11: Multi-File Zig Projects

This example demonstrates organizing Zig FFI code across multiple files.

## Project Structure

```
11-multi-file/
├── zig/
│   ├── ffi.zig       ← Root file (exports FFI functions to Lean)
│   ├── helpers.zig   ← Conversion utilities (Lean ↔ Zig)
│   └── math.zig      ← Pure Zig computation functions
├── build.zig         ← Points to ffi.zig as root
├── lakefile.lean
└── Main.lean
```

## Key Concept

**You only need to specify the root file in `build.zig`**. Zig's build system automatically compiles any files imported via `@import()`.

### In build.zig (line 17):
```zig
const ffi_module = b.createModule(.{
    .root_source_file = b.path("zig/ffi.zig"), // ← Just the root file!
    // ...
});
```

### In ffi.zig:
```zig
const helpers = @import("helpers.zig");  // Automatically compiled
const math = @import("math.zig");        // Automatically compiled
```

## Code Organization

### ffi.zig (Root)
- Exports functions to Lean with `export fn`
- Imports helper modules
- Handles Lean object lifecycle (inc_ref/dec_ref)

### helpers.zig (Utilities)
- Conversion functions (Lean arrays ↔ Zig slices)
- Bridge between Lean and Zig types
- No direct Lean FFI exports

### math.zig (Pure Zig)
- Pure computation logic
- No Lean dependencies
- Testable independently

## Benefits

1. **Separation of Concerns**: FFI logic separate from business logic
2. **Reusability**: Pure Zig modules can be tested independently
3. **Maintainability**: Each file has a clear responsibility
4. **No Extra Configuration**: Zig build system handles dependencies

## Building

```bash
lake build
lake exe multi-file
```

## Expected Output

```
Numbers: #[10, 20, 30, 40, 50]

Sum: 150
Average: 30
Max: 50

Stats (computed together): { sum := 150, average := 30, max := 50 }

✓ Multi-file Zig FFI working!
  - ffi.zig exports FFI functions
  - helpers.zig provides conversion utilities
  - math.zig provides computation functions
```

## Scaling to Larger Projects

For complex projects:

```
zig/
├── ffi/
│   ├── bindings.zig      ← Root (exports to Lean)
│   ├── conversions.zig
│   └── errors.zig
├── core/
│   ├── algorithms.zig
│   ├── data_structures.zig
│   └── utils.zig
└── tests/
    ├── core_test.zig
    └── ffi_test.zig
```

Just point `build.zig` to `zig/ffi/bindings.zig` and Zig finds everything else.

## See Also

- [Example 09](../09-complete-app/) - Complex single-file FFI
- [Usage Guide](../../doc/usage.md) - Build system details
