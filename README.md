# Lean-Zig Interop

[![CI](https://github.com/efvincent/lean-zig/actions/workflows/ci.yml/badge.svg)](https://github.com/efvincent/lean-zig/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lean Version](https://img.shields.io/badge/Lean-4.25.0--4.26.0-blue.svg)](https://github.com/leanprover/lean4)
[![Zig Version](https://img.shields.io/badge/Zig-0.14.0--0.15.2-orange.svg)](https://ziglang.org/)
[![Platforms](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)](https://github.com/efvincent/lean-zig)

A comprehensive library providing complete Zig bindings for the Lean 4 runtime, enabling seamless interoperability between Lean and Zig without C shims.

**🚀 Multi-Version & Multi-Platform Support**: One library version supports multiple Lean versions (4.25.0-4.26.0), multiple Zig versions (0.14.0-0.15.2), and all major platforms (Linux, macOS, Windows) - tested with 12 combinations in CI. No need for separate releases per version or platform!

**⚙️ Setup**: More than just a dependency - requires copying and customizing a `build.zig` template (one-time setup, ~2 minutes). See [Quick Start](#getting-started) below.

## Supported Platforms

✅ **Linux** (Ubuntu, tested on ubuntu-latest)  
✅ **macOS** (Intel & Apple Silicon, tested on macos-latest)  
✅ **Windows** (tested on windows-latest)

All platforms are tested in CI with the full version matrix (Lean 4.25.0-4.26.0 × Zig 0.14.0-0.15.2).

## Version Support Policy

### Supported Versions (Tested in CI)

**Lean**: 4.25.0, 4.26.0  
**Zig**: 0.14.0, 0.15.2  
**Platforms**: Linux (ubuntu-latest), macOS (macos-latest), Windows (windows-latest)

All combinations (12 total: 3 OS × 2 Lean × 2 Zig) are tested on every push to main.

### Compatibility Guarantee

- **Lean 4.25.0+**: Officially supported. The hybrid JIT strategy auto-generates bindings from your Lean installation, so newer stable versions likely work without changes.
- **Zig 0.14.0+**: Officially supported. The library targets stable Zig releases.
- **Older versions**: May work but are not tested. PRs welcome to expand support.

### Pre-release Versions (Nightly/RC)

Pre-release versions (Lean nightly, Zig master) are **not supported** in the main CI to avoid false failures from upstream instability. However:

- A separate [Nightly CI workflow](https://github.com/efvincent/lean-zig/actions/workflows/nightly.yml) tests against pre-release versions weekly for early warning
- Nightly failures don't block releases - they indicate upcoming compatibility work needed
- If you use pre-release versions, please report issues!

### When to Expect Breaking Changes

**This library follows semantic versioning**:
- **MAJOR** (1.0.0): Lean runtime ABI changes or removed functions
- **MINOR** (0.x.0): New features, backward-compatible
- **PATCH** (0.x.y): Bug fixes only

**Note**: Lean does not guarantee C ABI stability between minor versions. We pin tested versions in CI and document when updates require changes. See [Version Compatibility Guide](doc/version-compatibility.md) for detailed information on handling version upgrades.

### Road to 1.0

This library will remain in **0.x.x** (pre-1.0) until **Zig itself reaches 1.0**. This reflects the reality that Zig's language and build system are still evolving. Once Zig stabilizes at 1.0, we will evaluate this library's API stability and release 1.0 accordingly.

**Current status**: Zig is at 0.15.x, targeting 1.0 in 2025-2026. We will publish 1.x.x when Zig reaches 1.x.x.

## Features

- **Multi-Version Support**: Single codebase works with Lean 4.25.0-4.26.0 and Zig 0.14.0-0.15.2 - no separate releases needed
- **Cross-Platform**: Works on Linux, macOS (Intel & Apple Silicon), and Windows - all tested in CI
- **Hybrid JIT Strategy**: Auto-generates bindings from your Lean installation at build time - zero maintenance when Lean updates
- **Version Sync**: Bindings always match your installed Lean version
- **Template-Based Setup**: Copy and customize one `build.zig` file - template handles platform/version detection automatically
- **Pure Zig**: No C shim required - performance-critical functions manually inlined in native Zig
- **Full API Coverage**: Complete access to Lean runtime via auto-generated bindings
- **Type Safety**: Strong typing with null checks and typed pointers (`obj_arg`, `b_obj_arg`, `obj_res`)
- **Memory Management**: Direct use of Lean's runtime allocator with proper reference counting
- **Maximum Performance**: Hot-path functions inlined, cold-path forwarded - best of both worlds
- **Build Integration**: Automatic integration with Lake build system via `build.zig`
- **Comprehensive Documentation**: Complete API reference with examples and best practices
- **Extensive Tests**: 117+ tests covering all major API functions across all platforms

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

## Getting Started

**⚠️ Important**: Using lean-zig is **more than just adding a dependency**. You need to:
1. ✅ Add the dependency to your lakefile
2. ✅ Copy and customize a `build.zig` template 
3. ✅ Add an `extern_lib` target to your lakefile

The library then handles everything else automatically (binding generation, linking, platform detection).

## Quick Start

### Option 1: Automated Setup (Recommended)

Use the initialization script to create a new project with everything configured:

```bash
# Clone lean-zig repository
git clone https://github.com/unlifted/lean-zig
cd lean-zig

# Run the init script
./scripts/init-project.sh my-zig-project

# Build and run
cd my-zig-project
lake build
lake exe my-zig-project
```

This creates a working "Hello from Zig" example with all configuration done automatically.

### Option 2: Manual Setup

For adding lean-zig to an existing project:

### 1. Add Dependency

Add to your `lakefile.lean`:

```lean
require «lean-zig» from git
  "https://github.com/unlifted/lean-zig" @ "main"
```

### 2. Copy and Customize Build Template

**First, trigger dependency download** by running:

```bash
lake build  # Downloads lean-zig and triggers build (may fail - that's OK!)
```

**Then copy and customize the template:**

```bash
cp .lake/packages/lean-zig/template/build.zig ./
```

Edit `build.zig` **line 62** to point to your Zig source:
```zig
.root_source_file = b.path("zig/your_code.zig"),  // ← Change this
```

**Multi-file projects**: Just point to your root file - Zig automatically compiles imported files.

### 3. Add extern_lib to Your Lakefile

```lean
extern_lib libleanzig pkg := do
  let name := nameToStaticLib "leanzig"
  let oFile := pkg.buildDir / name
  
  proc {
    cmd := "zig"
    args := #["build"]
    cwd := pkg.dir
  }
  
  let srcFile := pkg.dir / "zig-out" / "lib" / name
  IO.FS.writeBinFile oFile (← IO.FS.readBinFile srcFile)
  
  return Job.pure oFile
```

### 4. Write Your Zig FFI Code

```zig
const lean = @import("lean");

export fn my_function(world: lean.obj_arg) lean.obj_res {
    const value = lean.boxUsize(42);
    return lean.ioResultMkOk(value);
}
```

### 5. Build

```bash
lake build
```

The bindings will be automatically generated from your Lean installation.

**Version Compatibility**: The template automatically adapts to your environment:
- Detects Lean/Zig versions at build time
- Handles glibc 2.27 requirement for Zig 0.15+ on Linux
- Platform-specific linking for Windows/macOS/Linux
- No changes needed when upgrading within tested versions

See [Usage Guide](doc/usage.md) for complete setup instructions and [Version Compatibility Guide](doc/version-compatibility.md) for upgrade procedures.

## API Quick Reference

### Common Operations

```zig
const lean = @import("lean");

// ━━━ Strings ━━━
// Create string from bytes
const str = lean.lean_mk_string_from_bytes("Hello", 5);
// From C string
const str2 = lean.lean_mk_string("World");
// Get C string pointer
const cstr = lean.stringCstr(str);
// Get length (bytes)
const len = lean.stringSize(str);

// ━━━ IO Results ━━━
// Success
return lean.ioResultMkOk(value);
// Error
const err = lean.lean_mk_string("error message");
return lean.ioResultMkError(err);

// ━━━ Boxing/Unboxing ━━━
// Box scalar
const boxed = lean.boxUsize(42);
// Unbox scalar (check isScalar first!)
if (lean.isScalar(obj)) {
    const n = lean.unboxUsize(obj);
}
// Box float
const f = lean.boxFloat(3.14);

// ━━━ Arrays ━━━
// Allocate array
const arr = lean.allocArray(10) orelse return error;
// Get/set elements
const elem = lean.arrayGet(arr, i);
lean.arraySet(arr, i, value);
// Fast unchecked access
const elem2 = lean.arrayUget(arr, i);

// ━━━ Constructors ━━━
// Allocate (tag, num_objects, scalar_bytes)
const ctor = lean.allocCtor(0, 2, 8) orelse return error;
// Set object field
lean.ctorSet(ctor, 0, obj);
// Set scalar field (at byte offset)
lean.ctorSetUint32(ctor, 0, 42);

// ━━━ Reference Counting ━━━
// Increment (when storing additional reference)
lean.lean_inc_ref(obj);
// Decrement (when done with reference)
lean.lean_dec_ref(obj);
// Use defer for cleanup
defer lean.lean_dec_ref(obj);

// ━━━ Type Checks ━━━
if (lean.isScalar(obj)) { }       // Tagged pointer?
if (lean.isExclusive(obj)) { }    // Can mutate in-place?
if (lean.isString(obj)) { }       // String type?
if (lean.isArray(obj)) { }        // Array type?
```

See [API Reference](doc/api.md) for complete documentation.

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
