# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Phase 1 Test Suite (Critical Safety)**: Added 40+ comprehensive tests covering:
  - Type inspection functions (13 tests): `isScalar`, `isCtor`, `isString`, `isArray`, `isSarray`, `isClosure`, `isThunk`, `isTask`, `isRef`, `isExternal`, `isMpz`, `isExclusive`, `isShared`, `ptrTag`
  - Constructor scalar field accessors (20 tests): getters and setters for `uint8`, `uint16`, `uint32`, `uint64`, `usize`, `float32`, `float64`
  - Constructor utilities (4 tests): `ctorNumObjs`, `ctorScalarCptr`, `ctorSetTag`, `ctorRelease`
  - Deep reference counting scenarios (4 tests): circular references, high refcounts, nested graphs, shared objects
  - Performance baselines (3 tests): boxing, array access, and refcount operations
- Type inspection API functions for runtime type checking
- Complete scalar field accessor API for constructor objects
- Constructor utility functions for advanced memory management
- Performance benchmarking infrastructure

### Changed
- Expanded test coverage from ~25 tests to 65+ tests (160% increase)
- Enhanced memory safety validation with complex reference counting scenarios

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
