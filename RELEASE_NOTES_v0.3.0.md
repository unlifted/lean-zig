# lean-zig v0.3.0 - Complete Core FFI Coverage 🎉

**Release Date:** December 27, 2025

## Overview

Version 0.3.0 marks the **completion of core Lean 4 runtime FFI coverage**. All essential runtime object types are now fully supported with comprehensive test coverage and documentation.

## Key Achievements

✅ **All Core Runtime Object Types Supported**
- Constructors (algebraic data types)
- Strings (UTF-8 with full operations)
- Arrays (object arrays with fast access)
- Scalar Arrays (ByteArray, FloatArray, etc.)
- Closures (function closures with partial application)
- Thunks (lazy evaluation with caching)
- Tasks (asynchronous computation)
- References (ST monad mutable cells)

✅ **Comprehensive Test Coverage**
- **117 tests** (368% increase from 25 baseline)
- All major API functions tested
- Performance benchmarks with CI-aware thresholds
- Memory safety validation
- Deep reference counting scenarios

✅ **Complete Documentation**
- API reference with 15+ new function docs
- Usage guide with extensive examples
- End-to-end integration examples
- Lean/Zig interop patterns

## What's New in v0.3.0

### Phase 5: Thunks, Tasks & References

**Thunk API (4 functions)**
- `lean_thunk_pure` - Create pre-evaluated thunks
- `thunkGet` - Fast-path cached value access
- `lean_thunk_get_own` - Ownership-transferring evaluation
- `lean_thunk_get_core` - Thread-safe evaluation forwarding

**Task API (9 functions)**
- Core: `lean_task_spawn_core`, `lean_task_get`, `lean_task_get_own`, `lean_task_map_core`, `lean_task_bind_core`
- Convenience: `taskSpawn`, `taskMap`, `taskBind` (with sensible defaults)

**Reference API (2 functions)**
- `refGet` - Get current value (borrowed)
- `refSet` - Set new value with automatic cleanup

### Enhanced Infrastructure

- **ObjectHeader made public** for advanced memory management use cases
- **9 new comprehensive tests** covering lazy evaluation, async patterns, and ST monad operations
- **Expanded documentation** with complete API reference and usage examples

## Migration Notes

No breaking changes from v0.2.0. All existing code continues to work unchanged.

## Performance

- Thunk fast path: **inline**, zero overhead for cached values
- Reference operations: **inline**, direct pointer access
- Tasks: Delegate to Lean runtime's optimized thread pool
- All hot-path functions remain inline for maximum performance

## Production Readiness

lean-zig v0.3.0 is **production-ready** for:
- ✅ Building Lean/Zig FFI libraries
- ✅ Implementing performance-critical operations in Zig
- ✅ Interfacing with existing Lean codebases
- ✅ Lazy evaluation and async computation patterns
- ✅ Mutable state management via ST monad

## Documentation

- **[API Reference](doc/api.md)** - Complete function documentation
- **[Usage Guide](doc/usage.md)** - Integration examples and patterns
- **[Design Document](doc/design.md)** - Architecture and implementation details
- **[Contributing Guide](CONTRIBUTING.md)** - Maintainer information

## Test Coverage Breakdown

- **Phase 1 (42 tests)**: Type inspection, scalar accessors, deep refcounting, performance baselines
- **Phase 2 (14 tests)**: Array and string operations
- **Phase 3 (11 tests)**: Scalar arrays (ByteArray, FloatArray)
- **Phase 4 (16 tests)**: Closures and advanced IO results
- **Phase 5 (9 tests)**: Thunks, tasks, and references
- **Total: 117 tests** with 100% pass rate

## Build Requirements

- **Lean 4.25.0 or later**
- **Zig 0.15.2 or compatible**
- Bindings auto-sync with installed Lean version via build-time code generation

## Installation

Add to your `lakefile.lean`:

```lean
require «lean-zig» from git
  "https://github.com/efvincent/lean-zig" @ "v0.3.0"
```

## What's Next

Future enhancements under consideration:
- Extended task testing with full Lean IO runtime integration
- External object API support
- BigInt (mpz) operations
- Additional convenience wrappers
- Performance optimization guide

## Contributors

Thank you to all contributors who helped make this release possible!

## License

MIT License - See [LICENSE](LICENSE) for details.

---

**Full Changelog**: https://github.com/efvincent/lean-zig/blob/v0.3.0/CHANGELOG.md
