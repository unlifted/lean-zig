# lean-zig Refactoring & Examples Plan

**Date:** December 27, 2025  
**Status:** Planning Phase  
**Goal:** Improve code organization and provide comprehensive examples

---

## Overview

Post v0.3.0 refactoring to:
1. **Modularize lean.zig** - Break into logical modules while maintaining performance
2. **Split test suite** - Organize tests by category for maintainability
3. **Create examples/** - Focused FFI projects demonstrating each API area
4. **Evaluate advanced features** - Determine future enhancements

---

## Part 1: Modularize lean.zig

### Current State
- **Single file**: `Zig/lean.zig` (~1546 lines)
- **All-in-one**: Types, memory, accessors, utilities
- **Performance critical**: Many inline functions

### Proposed Structure

```
Zig/
├── lean.zig              # Main module re-exports (public API)
├── types.zig             # Core types and tag constants
├── memory.zig            # Allocation and reference counting
├── boxing.zig            # Box/unbox for all scalar types
├── constructors.zig      # Constructor operations
├── strings.zig           # String operations
├── arrays.zig            # Object array operations
├── scalar_arrays.zig     # Scalar array operations
├── closures.zig          # Closure operations
├── thunks.zig            # Thunk operations
├── tasks.zig             # Task operations
├── references.zig        # Reference operations
└── io_results.zig        # IO result helpers
```

### Module Responsibilities

#### `types.zig`
- `Object`, `ObjectHeader` (pub)
- `StringObject`, `ArrayObject`, `ScalarArrayObject`
- `ClosureObject`, `ThunkObject`, `RefObject`
- `Tag` constants
- Ownership types (`obj_arg`, `b_obj_arg`, `obj_res`)

#### `memory.zig`
- `lean_inc_ref` (inline)
- `lean_dec_ref` (inline)
- `lean_alloc_object` (forwarded)
- `isExclusive`, `isShared` (inline)
- Type checking predicates (inline)

#### `boxing.zig`
- `boxUsize`, `unboxUsize` (inline)
- `boxUint32`, `unboxUint32` (inline)
- `boxUint64`, `unboxUint64` (inline)
- `boxFloat`, `unboxFloat` (inline)
- etc.

#### `constructors.zig`
- `allocCtor` (forwarded)
- `ctorGet`, `ctorSet` (inline)
- Scalar field accessors (all inline)
- `ctorNumObjs`, `ctorScalarCptr`, etc. (inline)

#### `strings.zig`
- `lean_mk_string`, `lean_mk_string_from_bytes` (forwarded)
- `stringCstr`, `stringSize`, `stringLen` (inline)
- `stringEq`, `stringLt`, etc. (inline)

#### `arrays.zig`
- `allocArray`, `mkArrayWithSize` (forwarded)
- `arrayGet`, `arraySet` (inline)
- `arrayUget`, `arrayUset` (inline, unchecked)
- `arraySize`, `arrayCapacity` (inline)
- `arraySwap` (inline)

#### `scalar_arrays.zig`
- `sarraySize`, `sarrayCapacity`, `sarrayElemSize` (inline)
- `sarrayCptr`, `sarraySetSize` (inline)

#### `closures.zig`
- `lean_alloc_closure` (inline)
- `closureArity`, `closureNumFixed`, `closureFun` (inline)
- `closureGet`, `closureSet`, `closureArgCptr` (inline)

#### `thunks.zig`
- `lean_thunk_pure` (inline)
- `thunkGet` (inline fast path)
- `lean_thunk_get_own` (inline)
- `lean_thunk_get_core` (forwarded)

#### `tasks.zig`
- `lean_task_spawn_core`, `lean_task_get`, etc. (all forwarded)
- `taskSpawn`, `taskMap`, `taskBind` (convenience wrappers, inline)

#### `references.zig`
- `refGet`, `refSet` (both inline)

#### `io_results.zig`
- `ioResultMkOk`, `ioResultMkError` (inline)
- `ioResultIsOk`, `ioResultIsError`, `ioResultGetValue` (inline)

### Main Module (`lean.zig`)

Re-exports all public APIs for backward compatibility:

```zig
// Re-export all modules
pub usingnamespace @import("types.zig");
pub usingnamespace @import("memory.zig");
pub usingnamespace @import("boxing.zig");
pub usingnamespace @import("constructors.zig");
pub usingnamespace @import("strings.zig");
pub usingnamespace @import("arrays.zig");
pub usingnamespace @import("scalar_arrays.zig");
pub usingnamespace @import("closures.zig");
pub usingnamespace @import("thunks.zig");
pub usingnamespace @import("tasks.zig");
pub usingnamespace @import("references.zig");
pub usingnamespace @import("io_results.zig");

// Maintain existing public API surface
```

### Performance Guarantee

- ✅ **All inline functions remain inline** in their modules
- ✅ **No additional indirection** via `usingnamespace`
- ✅ **Zero runtime cost** for modularization
- ✅ **Verify with benchmarks** before/after split

### Implementation Steps

1. Create new module files with appropriate functions
2. Update `lean.zig` to re-export via `usingnamespace`
3. Run full test suite (117 tests must pass)
4. Run performance benchmarks (no regression)
5. Update documentation if API surface changes
6. Commit with clear explanation of reorganization

---

## Part 2: Split Test Suite

### Current State
- **Single file**: `Zig/lean_test.zig` (~2000+ lines)
- **117 tests** covering all APIs
- **Well-organized** with section comments

### Proposed Structure

```
Zig/
├── tests/
│   ├── core_test.zig           # Type inspection, memory, boxing (42 tests)
│   ├── constructor_test.zig    # Constructor operations (subset from Phase 1)
│   ├── string_test.zig         # String operations (8 tests from Phase 2)
│   ├── array_test.zig          # Array operations (6 tests from Phase 2)
│   ├── scalar_array_test.zig   # Scalar array operations (11 tests from Phase 3)
│   ├── closure_test.zig        # Closure operations (11 tests from Phase 4)
│   ├── io_test.zig             # IO result operations (5 tests from Phase 4)
│   ├── thunk_test.zig          # Thunk operations (3 tests from Phase 5)
│   ├── task_test.zig           # Task operations (1 test from Phase 5)
│   └── reference_test.zig      # Reference operations (5 tests from Phase 5)
└── lean_test.zig               # Main test runner (imports all)
```

### Main Test Runner

```zig
// Zig/lean_test.zig
const std = @import("std");

// Import all test modules
test {
    @import("std").testing.refAllDecls(@import("tests/core_test.zig"));
    @import("std").testing.refAllDecls(@import("tests/constructor_test.zig"));
    @import("std").testing.refAllDecls(@import("tests/string_test.zig"));
    @import("std").testing.refAllDecls(@import("tests/array_test.zig"));
    @import("std").testing.refAllDecls(@import("tests/scalar_array_test.zig"));
    @import("std").testing.refAllDecls(@import("tests/closure_test.zig"));
    @import("std").testing.refAllDecls(@import("tests/io_test.zig"));
    @import("std").testing.refAllDecls(@import("tests/thunk_test.zig"));
    @import("std").testing.refAllDecls(@import("tests/task_test.zig"));
    @import("std").testing.refAllDecls(@import("tests/reference_test.zig"));
}
```

### Implementation Steps

1. Create `Zig/tests/` directory
2. Split tests by category into separate files
3. Update main `lean_test.zig` to import all test modules
4. Run `zig build test` - all 117 tests must pass
5. Update documentation to reflect new test structure
6. Commit with clear test reorganization

---

## Part 3: Create Examples Directory

### Structure

```
examples/
├── README.md                    # Overview of all examples
├── 01-hello-ffi/
│   ├── README.md                # Basic FFI setup
│   ├── lakefile.lean
│   ├── lean-toolchain
│   ├── Main.lean                # Lean entry point
│   ├── lib/
│   │   └── Hello.lean           # Lean FFI declarations
│   └── zig/
│       └── hello.zig            # Zig implementation
├── 02-strings/
│   ├── README.md                # String operations
│   ├── lakefile.lean
│   ├── Main.lean
│   ├── lib/
│   │   └── Strings.lean
│   └── zig/
│       └── strings.zig
├── 03-arrays/
│   ├── README.md                # Array operations
│   ├── lakefile.lean
│   ├── Main.lean
│   ├── lib/
│   │   └── Arrays.lean
│   └── zig/
│       └── arrays.zig
├── 04-constructors/
│   ├── README.md                # Algebraic data types
│   ├── lakefile.lean
│   ├── Main.lean
│   ├── lib/
│   │   └── DataTypes.lean
│   └── zig/
│       └── datatypes.zig
├── 05-closures/
│   ├── README.md                # Higher-order functions
│   ├── lakefile.lean
│   ├── Main.lean
│   ├── lib/
│   │   └── HigherOrder.lean
│   └── zig/
│       └── closures.zig
├── 06-thunks/
│   ├── README.md                # Lazy evaluation
│   ├── lakefile.lean
│   ├── Main.lean
│   ├── lib/
│   │   └── Lazy.lean
│   └── zig/
│       └── thunks.zig
├── 07-tasks/
│   ├── README.md                # Async computation
│   ├── lakefile.lean
│   ├── Main.lean
│   ├── lib/
│   │   └── Async.lean
│   └── zig/
│       └── tasks.zig
├── 08-references/
│   ├── README.md                # ST monad mutable state
│   ├── lakefile.lean
│   ├── Main.lean
│   ├── lib/
│   │   └── Mutable.lean
│   └── zig/
│       └── references.zig
└── 09-complete-app/
    ├── README.md                # Full application example
    ├── lakefile.lean
    ├── Main.lean
    ├── lib/
    │   ├── Types.lean
    │   ├── Parser.lean
    │   └── Processor.lean
    └── zig/
        ├── parser.zig
        └── processor.zig
```

### Example Template

Each example follows this pattern:

#### README.md
```markdown
# [Example Name]

## What This Demonstrates
- Feature 1
- Feature 2

## Files
- `Main.lean` - Entry point
- `lib/*.lean` - Lean FFI declarations
- `zig/*.zig` - Zig implementations

## Running
```bash
lake build
lake exe example_name
```

## Key Concepts
[Explanation of concepts demonstrated]

## Related Documentation
- [API Reference](../../doc/api.md#section)
- [Usage Guide](../../doc/usage.md#pattern)
```

#### lakefile.lean
```lean
import Lake
open Lake DSL

require «lean-zig» from git
  "https://github.com/efvincent/lean-zig" @ "v0.3.0"

package «example_name» where
  version := v!"0.1.0"

@[default_target]
lean_exe «example_name» where
  root := `Main

extern_lib libexample where
  name := "example"
  srcDir := "zig"
  moreLinkArgs := #["-lleanrt", "-lleanshared"]
```

### Example Progression

1. **01-hello-ffi**: Basic FFI setup, boxing/unboxing
2. **02-strings**: String creation, manipulation, comparison
3. **03-arrays**: Array creation, iteration, modification
4. **04-constructors**: Working with algebraic data types
5. **05-closures**: Higher-order functions, partial application
6. **06-thunks**: Lazy evaluation patterns
7. **07-tasks**: Asynchronous computation (requires IO runtime)
8. **08-references**: ST monad mutable state
9. **09-complete-app**: Realistic application combining all features

### Implementation Steps

1. Create `examples/` directory with README
2. Implement 01-hello-ffi with basic template
3. Copy/adapt template for remaining examples
4. Test each example builds and runs
5. Write comprehensive READMEs
6. Add main examples/README.md with navigation
7. Update root README.md to link to examples
8. Commit with complete examples

---

## Part 4: Evaluate Advanced Features

### Feature Assessment

#### 1. Extended Task Testing
**Status**: Current tests validate API only  
**Need**: Full IO runtime initialization for actual task spawning  
**Complexity**: High - requires Lean IO system setup  
**Priority**: Low - API coverage complete, users can test in their projects

#### 2. External Object API
**Status**: Not implemented (tag 254 reserved)  
**Need**: Interface with non-Lean objects (C libs, OS resources)  
**Complexity**: Medium - straightforward FFI  
**Priority**: Medium - useful for integration but not core

#### 3. BigInt (mpz) Operations
**Status**: Type check exists (`isMpz`), no operations  
**Need**: Large integer arithmetic  
**Complexity**: Medium - forward to GMP  
**Priority**: Low - most users work with machine integers

#### 4. Additional Convenience Wrappers
**Status**: Current wrappers sufficient  
**Need**: Higher-level abstractions?  
**Complexity**: Low - just wrapper functions  
**Priority**: Low - wait for user feedback

#### 5. Performance Optimization Guide
**Status**: Basic guidance in docs  
**Need**: Comprehensive performance best practices  
**Complexity**: Low - documentation only  
**Priority**: **High** - helps users write efficient code

### Recommendation

**Focus on #5 (Performance Guide)** as immediate next step:
- Document hot-path vs cold-path patterns
- Explain when to use unchecked operations
- Show profiling techniques
- Demonstrate cache-friendly data structures
- Include benchmarking examples

---

## Timeline

### Phase 1: Modularization (1-2 days)
- [ ] Create module structure
- [ ] Split lean.zig
- [ ] Update build.zig if needed
- [ ] Verify all tests pass
- [ ] Run performance benchmarks
- [ ] Commit and PR

### Phase 2: Test Reorganization (1 day)
- [ ] Create tests/ directory
- [ ] Split test suite
- [ ] Update test runner
- [ ] Verify 117/117 tests pass
- [ ] Commit and PR

### Phase 3: Examples (2-3 days)
- [ ] Create example structure
- [ ] Implement 01-hello-ffi
- [ ] Implement 02-09 examples
- [ ] Write comprehensive READMEs
- [ ] Test all examples build/run
- [ ] Commit and PR

### Phase 4: Performance Guide (1 day)
- [ ] Create doc/performance.md
- [ ] Document optimization patterns
- [ ] Add benchmarking examples
- [ ] Link from main docs
- [ ] Commit and PR

---

## Success Criteria

✅ **Zero Performance Regression** - All inline functions remain inline  
✅ **All Tests Pass** - 117/117 tests after refactoring  
✅ **API Unchanged** - No breaking changes to public API  
✅ **Examples Work** - All 9 examples build and run  
✅ **Documentation Complete** - All new modules documented  

---

## Rollback Plan

If refactoring causes issues:
1. Git revert to pre-refactor state
2. Analyze failure mode
3. Create smaller, incremental changes
4. Re-test each step

---

**Note**: This is a living document. Update as implementation progresses.
