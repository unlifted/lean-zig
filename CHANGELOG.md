# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-01-01

### Added
- **Developer Experience Improvements**
  - Native Lean init script: scripts/InitProject.lean for project creation, callable via `lake script run init`
  - Interactive prompts: Script prompts for project name and location if not provided on command line
  - Template files: Project templates now stored as actual files in template/ directory (under source control)
    - template/lakefile.lean.template - Lake configuration with lean-zig dependency
    - template/Main.lean.template - Sample Lean code with FFI declaration
    - template/ffi.zig.template - Sample Zig FFI implementation
    - template/gitignore.template - Git ignore file for Lean/Zig projects
  - Auto-copy stub file: template/build.zig now automatically copies copy_file_range_stub.o from lean-zig package to .zig-cache
  - Better error messages: Helpful guidance when stub file not found, with exact commands to fix
  - Setup checklist: Step-by-step checklist in doc/usage.md with checkbox format
  - API Quick Reference: Common operations reference in README.md for quick lookup
  - Project init script: scripts/init-project.sh (legacy bash version) for compatibility

### Changed
- **File Organization**
  - Moved copy_file_range_stub.* from root to compat/ directory for cleaner structure
  - Moved GLIBC_COMPAT.md to doc/glibc-compatibility.md matching documentation style
  - Template customization: Changed placeholder from "your_code.zig" to "CHANGE_ME.zig" with prominent TODO
  - Quick Start: Clarified that `lake build` (not `lake update`) downloads dependencies

### Improved
- **Template build.zig enhancements**
  - **ZIG_FFI_SOURCE variable**: Customization point moved to top of file (line 27) for easy access
  - Prominent customization comments with visual separators
  - Clear "no changes needed below" guidance after customization section
  - Auto-detection and copying of compatibility stub
  - Better error handling with actionable messages
- **Init script behavior**
  - Default: Creates project as **sibling** directory (in `..`) instead of subdirectory
  - Accepts optional path argument to override default location
  - Interactive mode when run without arguments
  - Validates project names (alphanumeric, hyphens, underscores only)
- **Documentation updates**
  - Updated all references from "line 62" to "ZIG_FFI_SOURCE variable"
  - Enhanced scripts/README.md with comprehensive usage guide
  - Documented init script modes (command-line vs interactive)

## [0.6.0] - 2026-01-01

### Added
- **Standalone Examples** - All 11 examples now build independently with their own build.zig and lakefile
  - Example 11: Multi-file Zig projects demonstrating modular FFI code organization
  - Template system: Single build.zig template with runtime Lean version detection
  - CI validation: validate-examples.sh script ensuring all examples build successfully
  - Version compatibility guide: doc/version-compatibility.md for Lean/Zig version matrix
  - Documentation: Complete usage examples in doc/usage.md with build instructions

### Changed
- **Lake 5.0 Migration** - Updated all examples to use `extern_lib name pkg := do` syntax (breaking change from Lake 4.x `where` syntax)
- **Build System Simplification** - Examples now use 13-line minimal lakefiles that call `zig build`
- **Cross-Platform Improvements** - Build.zig files use conditional glibc override for better portability
- **Code Organization** - Removed unused std imports from boxing.zig and constructors.zig

### Fixed
- **glibc 2.27 Compatibility** - Added copy_file_range stub to resolve Zig 0.15+ linking issues
  - Zig 0.15+ generates copy_file_range symbols requiring glibc 2.38
  - Lean runtime bundles glibc 2.27, causing undefined symbol errors
  - Stub implementation provides ENOSYS fallback for unreachable code paths
  - Documentation in GLIBC_COMPAT.md explaining the workaround
- **Example Code Bugs** - Fixed type mismatches and ToString derivation issues in examples 07, 08, 11
- **CI Badge** - Fixed GitHub Actions workflow badge URL in README

### Removed
- Obsolete compatibility shims: copy_file_range.c, libcopy_file_range.so, lean_header.h
- Removed in favor of proper glibc target override and direct lean.h usage

## [0.5.0] - 2025-12-30

### Added
- **Multi-Threading Support** - Thread-safe reference counting for concurrent object sharing
  - `lean_inc_ref_n(o, n)` - Bulk increment reference count with atomic operations for MT objects
  - `isMt(o)` - Check if object uses multi-threaded reference counting (refcount < 0)
  - `markMt(o)` - Convert single-threaded object to multi-threaded mode before sharing
  - 11 comprehensive MT tests covering detection, conversion, bulk operations, and thread simulation
  - Reimplemented from lean.h `static inline` functions with proper atomic operations
  - Documentation in `doc/api.md` with examples and safety considerations
  - Total test count: 128 tests (up from 117)

## [0.4.0] - 2025-12-30

### Added
- **External Objects Documentation & Examples** - Complete coverage for native resource management
  - Updated `doc/api.md`: Added External Objects section (#13) with complete API reference
    - `ExternalClass` and `ExternalObject` core types documented
    - All 5 API functions: `registerExternalClass`, `allocExternal`, `getExternalData`, `getExternalClass`, `setExternalData`
    - Comprehensive file handle example (~250 lines) demonstrating proper cleanup patterns
  - Updated `doc/usage.md`: Added External Objects usage section with FileHandle example
    - Native resource management pattern with automatic cleanup via finalizers
    - Complete code showing initializer, finalizer, and all file operations
  - Created `examples/10-external-objects/`: Complete file I/O example application
    - Demonstrates wrapping native file handles as Lean objects
    - Shows automatic cleanup via finalizers when refcount reaches 0
    - Includes comprehensive README (6KB) covering concepts, patterns, and best practices

### Changed
- Repository moved to `unlifted` organization: https://github.com/unlifted/lean-zig
  - All documentation URLs updated to reflect new location
  - GitHub automatically redirects old URLs for seamless transition

## [0.3.1] - 2025-12-29

### Fixed
- **CRITICAL**: Fixed Windows CI failures across all Lean/Zig version combinations
  - Fixed PowerShell `-NoPrompt` syntax error (requires explicit boolean value)
  - Implemented platform-specific library linking for Windows MinGW
  - Linked 6 required Windows libraries: libleanrt.a, libleanshared.dll.a, libleanmanifest.a, libInit_shared.dll.a, libLean.a, libgmp.a
  - Windows libraries now correctly located in `lib/lean/` and `lib/` directories
  - All 4 Windows CI jobs now passing (2 Lean versions × 2 Zig versions)

### Changed
- Refactored `build.zig` to eliminate code duplication with `linkLeanRuntime()` helper function
- Improved build system maintainability with centralized platform-specific linking logic

### Added
- Nightly CI workflow for early detection of compatibility issues with pre-release versions
- Explicit version support policy in README

## [0.3.0] - 2025-12-27

**Complete Core Runtime FFI Coverage** - All Lean 4 runtime object types now fully supported with comprehensive test coverage.

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
- **Phase 5: Thunks, Tasks & References**: Added 9 new tests, bringing total from 108 to 117 tests, covering:
  - **ThunkObject and RefObject type definitions** with complete struct layouts matching Lean runtime
  - **Thunk API (4 functions)**: `lean_thunk_pure`, `thunkGet`, `lean_thunk_get_own`, plus `lean_thunk_get_core` forwarding
  - **Task API (9 functions)**: Core functions (`lean_task_spawn_core`, `lean_task_get`, `lean_task_get_own`, `lean_task_map_core`, `lean_task_bind_core`) plus convenience wrappers (`taskSpawn`, `taskMap`, `taskBind`)
  - **Reference API (2 functions)**: `refGet`, `refSet` for ST monad mutable references
  - **Thunk tests (3 tests)**: pure thunk creation, ownership transfer, value caching
  - **Task tests (1 test)**: API existence and signature validation
  - **Reference tests (5 tests)**: basic get/set, value updates, refcount management, object storage, null handling
- Type inspection API functions for runtime type checking with null safety documentation
- Complete scalar field accessor API for constructor objects with alignment safety documentation
- Constructor utility functions for advanced memory management
- **Scalar array API functions** (`sarraySize`, `sarrayCapacity`, `sarrayElemSize`, `sarrayCptr`, `sarraySetSize`)
- **Closure API functions** for functional programming and FFI integration
- **Thunk, Task, and Reference APIs** completing core runtime FFI coverage
- **Made ObjectHeader public** for advanced memory management use cases
- Performance benchmarking infrastructure with CI-aware thresholds

### Changed
- Expanded test coverage from ~25 tests to **117 tests** (368% increase from original baseline)
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

[Unreleased]: https://github.com/unlifted/lean-zig/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/unlifted/lean-zig/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/unlifted/lean-zig/compare/v0.4.0...v0.6.0
[0.4.0]: https://github.com/unlifted/lean-zig/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/unlifted/lean-zig/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/unlifted/lean-zig/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/unlifted/lean-zig/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/unlifted/lean-zig/releases/tag/v0.1.0
