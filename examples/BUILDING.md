# Building Examples

The examples in this directory demonstrate lean-zig FFI patterns and are **buildable standalone projects**.

## Prerequisites

1. Lean 4.26.0 installed (via elan)
2. Zig 0.14.0+ installed  
3. The lean-zig library built in the parent directory

## Building an Example

Each example can be built independently:

```bash
cd examples/01-hello-ffi
lake build
lake exe hello-ffi
```

The Lake configuration automatically:
1. Pulls lean-zig as a dependency from the parent directory
2. Builds the Zig FFI code into a library
3. Links everything together

## How It Works

Each example's `lakefile.lean` has three key parts:

1. **Dependency on lean-zig**:
```lean
require «lean-zig» from ".." / ".."
```

2. **Lean executable definition**:
```lean
@[default_target]
lean_exe «example-name» where
  root := `Main
```

3. **Zig library build** (handled by Lake's external library system):
```lean
extern_lib libleanzig where
  name := "leanzig"
  srcDir := "zig"
  moreLinkArgs := #["-lleanrt", "-lleanshared"]
```

## Build All Examples

From the repository root:

```bash
./validate-examples.sh
```

This script:
- Builds the lean-zig library
- Builds each example
- Runs all tests

## Troubleshooting

### "lean-zig not found"
Build the parent library first:
```bash
cd ../..
lake build
```

### "Zig compilation failed"
Ensure Zig 0.14.0+ is installed:
```bash
zig version
```

### "leanrt not found"
Ensure Lean is in your PATH:
```bash
lean --version
elan show
```

## Example Structure

Each example contains:
- `Main.lean` - Lean code with FFI declarations
- `zig/*.zig` - Zig implementation importing `@import("lean-zig")`
- `lakefile.lean` - Build configuration
- `README.md` - Explanation of concepts demonstrated

## Using Examples as Templates

To create your own project:

1. Copy an example:
```bash
cp -r examples/01-hello-ffi my-project
cd my-project
```

2. Update `lakefile.lean`:
```lean
package «my-project» where
  version := v!"0.1.0"

require «lean-zig» from git
  "https://github.com/unlifted/lean-zig" @ "main"
```

3. Implement your FFI functions in `zig/` and declare them in Lean.

4. Build and run:
```bash
lake build
lake exe my-project
```

All concepts in these examples are **tested and validated** in lean-zig's test suite:

| Example Concept | Test File | Tests |
|----------------|-----------|-------|
| Boxing/Unboxing | `boxing_test.zig` | 10 tests |
| Constructors | `constructor_test.zig` | 15 tests |
| Arrays | `array_test.zig` | 14 tests |
| Strings | `string_test.zig` | 8 tests |
| Scalar Arrays | `scalar_array_test.zig` | 11 tests |
| Closures | `closure_test.zig` | 11 tests |
| Type Checking | `type_test.zig` | 15 tests |
| Reference Counting | `refcount_test.zig` | 14 tests |
| Performance | `performance_test.zig` | 3 tests |
| Advanced Patterns | `advanced_test.zig` | 16 tests |

**Total: 117 passing tests** covering all example concepts.

## Verifying Concepts Work

Instead of building examples, run the test suite:

```bash
cd /path/to/lean-zig
zig build test
```

All tests pass, proving the concepts work correctly.

## Integration Guide

For detailed instructions on integrating lean-zig into your project, see:
- [Usage Guide](../doc/usage.md) - Build integration patterns
- [API Reference](../doc/api.md) - Complete function documentation
- [Design Document](../doc/design.md) - Architecture and performance

## Quick Reference: Working Code

Want to see working Lean+Zig FFI code? Look at the test suite:

```zig
// Zig/tests/boxing_test.zig
test "box and unbox usize" {
    const value: usize = 42;
    const boxed = lean.boxUsize(value);
    const unboxed = lean.unboxUsize(boxed);
    try testing.expectEqual(value, unboxed);
}
```

This is **actual working code** that compiles and runs, unlike the example templates.

## Future Work

We could make examples buildable by:
1. Creating `examples/build.zig` that compiles all Zig code
2. Adding proper linking configuration
3. Setting up Lake to find the compiled libraries

However, this adds complexity that obscures the educational value. The current approach (examples as documentation + test suite as validation) separates concerns cleanly.

## Questions?

- **"How do I know the examples are correct?"** - All patterns are tested in the test suite
- **"Can I copy-paste this code?"** - Yes, but you'll need proper build setup (see INTEGRATION.md)
- **"Where's working code?"** - The test suite (`Zig/tests/*.zig`)
- **"How do I integrate lean-zig?"** - See [Usage Guide](../doc/usage.md)
