# Lean-Zig Interop

A comprehensive library providing complete Zig bindings for the Lean 4 runtime, enabling seamless interoperability between Lean and Zig without C shims.

## Features

- **Hybrid JIT Strategy**: Auto-generates bindings from your Lean installation at build time - zero maintenance when Lean updates
- **Version Sync**: Bindings always match your installed Lean version
- **Pure Zig**: No C shim required - performance-critical functions manually inlined in native Zig
- **Full API Coverage**: Complete access to Lean runtime via auto-generated bindings
- **Type Safety**: Strong typing with null checks and typed pointers (`obj_arg`, `b_obj_arg`, `obj_res`)
- **Memory Management**: Direct use of Lean's runtime allocator with proper reference counting
- **Maximum Performance**: Hot-path functions inlined, cold-path forwarded - best of both worlds
- **Build Integration**: Automatic integration with Lake build system via `build.zig`
- **Comprehensive Documentation**: Complete API reference with examples and best practices
- **Extensive Tests**: Full unit test suite covering all major API functions

## Architecture

This library uses a **hybrid JIT binding strategy**:

1. **Build-time Code Generation**: Uses Zig's `translateC` to auto-generate bindings from `lean.h`
2. **Hot-Path Inlining**: Performance-critical functions (boxing, reference counting, field access) manually inlined
3. **Cold-Path Forwarding**: Other functions forward to auto-generated bindings
4. **Zero Maintenance**: When Lean updates, just rebuild - bindings automatically sync

### Performance Philosophy

This project prioritizes **maximum performance**:

- **Tagged pointer operations** (boxing/unboxing): 1-2 CPU instructions
- **Reference counting fast path**: Single comparison + increment/decrement
- **Object field access**: Direct pointer arithmetic, no function calls
- **Array operations**: Unchecked variants available for hot loops
- **Multi-threaded objects**: Properly delegated to Lean's atomic operations

Functions are inlined strategically based on profiling data and runtime impact.

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
- Multi-threaded reference counting properly handled via atomics

## Quick Start

Add this package to your `lakefile.lean`:

```lean
require «lean-zig» from git
  "https://github.com/efvincent/lean-zig" @ "main"
```

The bindings will be automatically generated when you build. See [Usage Guide](doc/usage.md) for detailed integration instructions.

## Building

The library uses `build.zig` which automatically:
1. Detects your Lean installation (`lean --print-prefix`)
2. Generates FFI bindings from `lean.h` using `translateC`
3. Compiles tests and examples

To run tests:

```bash
lake script run test
# or directly:
zig build test
```

## Documentation

- **[Usage Guide](doc/usage.md)**: How to integrate into your Lean project
- **[API Reference](doc/api.md)**: Complete function documentation
- **[Design](doc/design.md)**: Architecture and implementation details
- **[Contributing](CONTRIBUTING.md)**: Development workflow and maintenance guide
