# Building Examples

## Important Note

The examples in this directory are **educational templates** demonstrating lean-zig FFI patterns. They show the structure and concepts needed to build Lean+Zig applications.

## Why Examples Don't Build Standalone

Each example's Zig code (`zig/*.zig`) would need to:
1. Import the lean-zig bindings
2. Be compiled into a shared library
3. Be linked against the Lean runtime
4. Be loaded by the Lean program

This requires a complete build setup (build.zig, proper linking, etc.) which would obscure the educational content.

## How to Use These Examples

### As Learning Material
Read through each example in order to understand concepts:
1. Read the README.md for concepts
2. Study Main.lean to see Lean FFI declarations
3. Examine zig/*.zig to see Zig implementations
4. Note the patterns (boxing, memory management, error handling)

### As Templates for Your Project
To create a working Lean+Zig project:

1. **Start with lean-zig's test suite** - All concepts are validated there:
   ```bash
   cd /path/to/lean-zig
   zig build test  # Runs all 117 tests
   ```

2. **Copy an example as a template**:
   ```bash
   cp -r examples/01-hello-ffi my-project
   cd my-project
   ```

3. **Set up proper build system** - See [INTEGRATION.md](INTEGRATION.md) for details

4. **Reference the working patterns**:
   - Boxing: See `Zig/tests/boxing_test.zig`
   - Constructors: See `Zig/tests/constructor_test.zig`  
   - Arrays: See `Zig/tests/array_test.zig`
   - Strings: See `Zig/tests/string_test.zig`
   - etc.

## Validated Concepts

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
