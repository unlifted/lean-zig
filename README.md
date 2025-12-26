# Lean-Zig Interop

A comprehensive library providing complete Zig bindings for the Lean 4 runtime, enabling seamless interoperability between Lean and Zig without C shims.

## Features

- **Pure Zig**: No C shim required - all `static inline` functions reimplemented in native Zig
- **Full API Coverage**: Complete bindings for constructors, arrays, strings, closures, tasks, thunks, and more
- **Type Safety**: Strong typing with null checks and typed pointers (`obj_arg`, `b_obj_arg`, `obj_res`)
- **Memory Management**: Direct use of Lean's runtime allocator with proper reference counting
- **High Performance**: Inline functions provide zero-cost abstractions matching Lean's C performance
- **Build Integration**: Easy integration with Lake build system
- **Comprehensive Documentation**: Complete API reference with examples and best practices
- **Extensive Tests**: Full unit test suite covering all major API functions

## API Coverage

### Core Features
- ✅ **Boxing/Unboxing**: All scalar types (usize, uint32, uint64, float, float32)
- ✅ **Constructors**: Full support with scalar field accessors (uint8/16/32/64, float, float32)
- ✅ **Strings**: Creation, comparison, byte access, UTF-8 support
- ✅ **Arrays**: Object arrays with unchecked fast access, swap, borrowed access
- ✅ **Scalar Arrays**: ByteArray, FloatArray support
- ✅ **Closures**: Creation, fixed argument access
- ✅ **Thunks**: Lazy evaluation support
- ✅ **Tasks**: Async task spawning, mapping, binding
- ✅ **References**: Mutable references for ST monad
- ✅ **Type Inspection**: Complete runtime type checking (isScalar, isExclusive, isShared, etc.)
- ✅ **IO Results**: Success/error result handling

### Performance Features
- Zero-overhead inline functions for hot paths
- Tagged pointer optimization for small integers
- In-place mutation detection with `isExclusive`
- Unchecked array accessors for performance-critical code

## Quick Start

Add this package to your `lakefile.lean`:

```lean
require «lean-zig» from git
  "https://github.com/yourusername/lean-zig" @ "main"
```

Then use the Zig module in your build configuration:

```lean
target zigLib (pkg : Package) : FilePath := Job.async do
  -- 1. Find the dependency
  let leanZig := pkg.deps.find? fun dep => dep.name.toString == "lean-zig"
  let leanZig := leanZig.get!
  let leanZigSrc := leanZig.dir / "Zig" / "lean.zig"
  
  -- 2. Pass it to Zig
  proc {
    cmd := "zig"
    args := #[
      "build-lib",
      "your_file.zig",
      "-Mlean=" ++ leanZigSrc.toString,
      ...
    ]
    ...
  }
```

## Development

To run the unit tests:

```bash
lake script run test
```
