# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Phase 1 Test Suite (Critical Safety)**: Added 42 comprehensive tests covering:
  - Type inspection functions (15 tests): `isScalar`, `isCtor`, `isString`, `isArray`, `isSarray`, `isClosure`, `isThunk`, `isTask`, `isRef`, `isExternal`, `isMpz`, `isExclusive`, `isShared`, `ptrTag`
  - Constructor scalar field accessors (13 tests): getters and setters for `uint8`, `uint16`, `uint32`, `uint64`, `usize`, `float32`, `float64`
  - Constructor utilities (4 tests): `ctorNumObjs`, `ctorScalarCptr`, `ctorSetTag`, `ctorRelease`
  - Deep reference counting scenarios (7 tests): circular references, high refcounts, nested graphs, shared objects, balance verification
  - Performance baselines (3 tests): boxing, array access, and refcount operations with environment-aware thresholds
- **Phase 2 Test Suite Completed (Array & String Operations)**: Added 14 new tests (6 array + 8 string), bringing total from 68 to 82 tests, covering:
  - Array operations (6 tests): allocation, swap, bounds checking, capacity invariants
  - String operations (8 tests): equality, comparison, UTF-8 handling, empty strings
- **Phase 3 Test Suite Completed (Scalar Arrays)**: Added 11 new tests, bringing total from 82 to 93 tests, covering:
  - Type detection: `isSarray` validation
  - Accessor functions: size, capacity, element size, data pointer
  - Mutation: `sarraySetSize` 
  - Different array types: ByteArray, Float32Array, Float64Array
  - Access patterns: byte array iteration, float array operations
  - Edge cases: empty arrays, array type distinction
  - Performance: byte access baseline with cache-aware thresholds
- **Phase 4: Closures & Advanced IO**: Added 16 new tests, bringing total from 92 to 108 tests, covering:
  - **ClosureObject type definition** with complete struct layout matching Lean runtime
  - **`lean_alloc_closure` function**: Inline implementation matching lean.h for zero-cost closure allocation with zero-initialized fixed arguments
  - **7 closure accessor functions**: `closureArity`, `closureNumFixed`, `closureFun`, `closureGet`, `closureSet`, `closureArgCptr`, plus `isClosure` type check
  - **Closure tests (11 tests)**: allocation, metadata access, fixed argument get/set, pointer access, zero/full saturation, refcounting, partial application, iteration
  - **Advanced IO result tests (5 tests)**: value extraction, error messages, complex objects, tag correctness, error propagation
- Type inspection API functions for runtime type checking with null safety documentation
- Complete scalar field accessor API for constructor objects with alignment safety documentation
- Constructor utility functions for advanced memory management
- **Scalar array API functions** (`sarraySize`, `sarrayCapacity`, `sarrayElemSize`, `sarrayCptr`, `sarraySetSize`)
- **Closure API functions** for functional programming and FFI integration  
- Performance benchmarking infrastructure with CI-aware thresholds

### Changed
- Expanded test coverage from ~25 tests to **108 tests** (332% increase from original baseline)
- Enhanced memory safety validation with complex reference counting scenarios
- Improved documentation with null safety warnings and alignment considerations
- Performance tests now adapt thresholds based on CI environment detection

### Fixed
- **CRITICAL**: Fixed segfault in `lean_inc_ref` and `lean_dec_ref` by adding tagged pointer checks
  - Tagged pointers (scalars with low bit set) are now correctly skipped in reference counting
  - Prevents crash when Lean runtime tries to inc/dec_ref scalar values
- **CRITICAL**: Fixed `mkArrayWithSize` initialization strategy
  - Removed automatic element initialization that caused runtime crashes
  - Documented requirement that callers MUST populate all elements before cleanup
  - Updated all tests to properly populate arrays before calling `lean_dec_ref`

## [0.2.0] - 2025-12-26

### Added
- Comprehensive documentation suite (api.md, usage.md, design.md)
- Complete test suite in `Zig/lean_test.zig`
- Lake integration with zig build support
- Versioning strategy documentation
- CHANGELOG to track version history
- Ecosystem integration preparation (Reservoir registry)

### Changed
- Refined lakefile.lean structure and metadata
- Enhanced README with architecture overview
- Improved documentation organization

### Fixed
- Lake manifest handling (excluded from version control per library best practices)

## [0.1.0] - Initial Development

### Added
- Hybrid JIT binding strategy (auto-generated + manually inlined hot paths)
- Complete Zig FFI bindings for Lean 4 runtime
- Core API coverage:
  - Boxing/unboxing for all scalar types
  - Constructors with scalar field accessors
  - String operations and UTF-8 support
  - Object arrays with fast unchecked access
  - Scalar arrays (ByteArray, FloatArray)
  - Closures and thunks
  - Tasks and async support
  - References for ST monad
  - Type inspection utilities
  - IO result handling
- Zero-overhead tagged pointer optimization
- Reference counting with exclusive/shared detection
- Build system integration via `build.zig`
- MIT license

[Unreleased]: https://github.com/efvincent/lean-zig/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/efvincent/lean-zig/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/efvincent/lean-zig/releases/tag/v0.1.0
