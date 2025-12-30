//! # Lean 4 Runtime FFI Bindings for Zig (Modular Architecture)
//!
//! This module provides Zig bindings to the Lean 4 runtime using a hybrid approach:
//!
//! - **Hot-path functions** (type checks, boxing, field access): Implemented as
//!   inline Zig functions for zero-cost abstractions
//! - **Cold-path functions** (allocation, string creation): Forwarded to
//!   auto-generated bindings that match your installed Lean version
//!
//! ## Modular Organization (v0.4.0+)
//!
//! The library is now organized into focused modules for maintainability:
//! - **`types.zig`** - Core types and ownership semantics
//! - **`memory.zig`** - Reference counting and type inspection
//! - **`boxing.zig`** - Boxing/unboxing scalars
//! - **`constructors.zig`** - Constructor allocation and field access
//! - **`strings.zig`** - String operations
//! - **`arrays.zig`** - Array operations
//! - **`scalar_arrays.zig`** - Scalar array operations
//! - **`closures.zig`** - Closure operations
//! - **`thunks.zig`** - Thunk operations
//! - **`tasks.zig`** - Task operations
//! - **`references.zig`** - Reference operations
//! - **`io_results.zig`** - IO result helpers
//!
//! All modules are re-exported here for backward compatibility.
//!
//! ## Compatibility
//!
//! Bindings are **automatically synchronized** with your Lean installation via
//! `translateC` at build time. The build system detects your Lean version and
//! generates correct FFI bindings from `lean/lean.h`.
//!
//! ## Memory Safety
//!
//! - **Tagged pointers**: Small scalars (<2^63) use tagged pointer encoding:
//!   `(value << 1) | 1`. Always check `isScalar()` before dereferencing.
//!
//! - **Reference counting**: Lean uses reference counting for memory management.
//!   * `obj_arg`: Owned pointer (caller must `dec_ref` when done)
//!   * `b_obj_arg`: Borrowed pointer (do NOT `dec_ref`)
//!   * `obj_res`: Result pointer (callee transfers ownership)
//!
//! - **Null safety**: Most functions assume non-null input. Violating this
//!   results in `unreachable` panics or undefined behavior.
//!
//! ## Performance Notes
//!
//! - **Hot path functions** (boxing, field access, refcounting) compile to
//!   1-5 CPU instructions each. They are inline and have zero function call
//!   overhead.
//!
//! - **Cold path functions** (allocation, string creation) forward to the
//!   Lean runtime via `lean_raw` (translateC module).
//!
//! ## ABI Stability
//!
//! **Important**: Lean does NOT guarantee C ABI stability between minor versions.
//! Always pin your Lean version in `lean-toolchain` and test after upgrades.
//! This library targets Lean 4.25.0-4.26.0.
//!
//! ## Usage
//!
//! ```zig
//! const lean = @import("lean");
//!
//! export fn my_function(str: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
//!     _ = world;
//!     const data = lean.stringCstr(str);
//!     const result = lean.lean_mk_string_from_bytes(data, 5);
//!     return lean.ioResultMkOk(result);
//! }
//! ```

// ============================================================================
// Module Imports
// ============================================================================

const types_mod = @import("types.zig");
const memory_mod = @import("memory.zig");
const boxing_mod = @import("boxing.zig");
const constructors_mod = @import("constructors.zig");
const strings_mod = @import("strings.zig");
const arrays_mod = @import("arrays.zig");
const scalar_arrays_mod = @import("scalar_arrays.zig");
const closures_mod = @import("closures.zig");
const thunks_mod = @import("thunks.zig");
const tasks_mod = @import("tasks.zig");
const references_mod = @import("references.zig");
const io_results_mod = @import("io_results.zig");
const external_mod = @import("external.zig");

// ============================================================================
// Type Re-exports
// ============================================================================

pub const Object = types_mod.Object;
pub const ObjectHeader = types_mod.ObjectHeader;
pub const StringObject = types_mod.StringObject;
pub const CtorObject = types_mod.CtorObject;
pub const ArrayObject = types_mod.ArrayObject;
pub const ScalarArrayObject = types_mod.ScalarArrayObject;
pub const ClosureObject = types_mod.ClosureObject;
pub const ThunkObject = types_mod.ThunkObject;
pub const RefObject = types_mod.RefObject;
pub const ExternalClass = types_mod.ExternalClass;
pub const ExternalObject = types_mod.ExternalObject;

pub const obj_arg = types_mod.obj_arg;
pub const b_obj_arg = types_mod.b_obj_arg;
pub const obj_res = types_mod.obj_res;

pub const Tag = types_mod.Tag;

// ============================================================================
// Memory Management Re-exports
// ============================================================================

pub const lean_inc_ref = memory_mod.lean_inc_ref;
pub const lean_dec_ref = memory_mod.lean_dec_ref;
pub const lean_alloc_object = memory_mod.lean_alloc_object;

pub const isScalar = memory_mod.isScalar;
pub const objectTag = memory_mod.objectTag;
pub const objectRc = memory_mod.objectRc;
pub const objectOther = memory_mod.objectOther;
pub const ptrTag = memory_mod.ptrTag;

pub const isCtor = memory_mod.isCtor;
pub const isString = memory_mod.isString;
pub const isArray = memory_mod.isArray;
pub const isSArray = memory_mod.isSArray;
pub const isClosure = memory_mod.isClosure;
pub const isThunk = memory_mod.isThunk;
pub const isTask = memory_mod.isTask;
pub const isRef = memory_mod.isRef;
pub const isExternal = memory_mod.isExternal;
pub const isMpz = memory_mod.isMpz;
pub const isExclusive = memory_mod.isExclusive;
pub const isShared = memory_mod.isShared;

// ============================================================================
// Boxing Re-exports
// ============================================================================

pub const boxUsize = boxing_mod.boxUsize;
pub const unboxUsize = boxing_mod.unboxUsize;
pub const boxUint32 = boxing_mod.boxUint32;
pub const unboxUint32 = boxing_mod.unboxUint32;
pub const boxUint64 = boxing_mod.boxUint64;
pub const unboxUint64 = boxing_mod.unboxUint64;
pub const boxFloat = boxing_mod.boxFloat;
pub const unboxFloat = boxing_mod.unboxFloat;
pub const boxFloat32 = boxing_mod.boxFloat32;
pub const unboxFloat32 = boxing_mod.unboxFloat32;

// ============================================================================
// Constructor Re-exports
// ============================================================================

pub const allocCtor = constructors_mod.allocCtor;
pub const ctorNumObjs = constructors_mod.ctorNumObjs;
pub const ctorObjCptr = constructors_mod.ctorObjCptr;
pub const ctorGet = constructors_mod.ctorGet;
pub const ctorSet = constructors_mod.ctorSet;
pub const ctorScalarCptr = constructors_mod.ctorScalarCptr;
pub const ctorGetUint8 = constructors_mod.ctorGetUint8;
pub const ctorSetUint8 = constructors_mod.ctorSetUint8;
pub const ctorGetUint16 = constructors_mod.ctorGetUint16;
pub const ctorSetUint16 = constructors_mod.ctorSetUint16;
pub const ctorGetUint32 = constructors_mod.ctorGetUint32;
pub const ctorSetUint32 = constructors_mod.ctorSetUint32;
pub const ctorGetUint64 = constructors_mod.ctorGetUint64;
pub const ctorSetUint64 = constructors_mod.ctorSetUint64;
pub const ctorGetUsize = constructors_mod.ctorGetUsize;
pub const ctorSetUsize = constructors_mod.ctorSetUsize;
pub const ctorGetFloat = constructors_mod.ctorGetFloat;
pub const ctorSetFloat = constructors_mod.ctorSetFloat;
pub const ctorGetFloat32 = constructors_mod.ctorGetFloat32;
pub const ctorSetFloat32 = constructors_mod.ctorSetFloat32;
pub const ctorSetTag = constructors_mod.ctorSetTag;
pub const ctorRelease = constructors_mod.ctorRelease;

// ============================================================================
// String Re-exports
// ============================================================================

pub const lean_mk_string = strings_mod.lean_mk_string;
pub const lean_mk_string_from_bytes = strings_mod.lean_mk_string_from_bytes;
pub const stringCstr = strings_mod.stringCstr;
pub const stringSize = strings_mod.stringSize;
pub const stringLen = strings_mod.stringLen;
pub const stringCapacity = strings_mod.stringCapacity;
pub const stringGetByteFast = strings_mod.stringGetByteFast;
pub const stringEq = strings_mod.stringEq;
pub const stringNe = strings_mod.stringNe;
pub const stringLt = strings_mod.stringLt;

// ============================================================================
// Array Re-exports
// ============================================================================

pub const allocArray = arrays_mod.allocArray;
pub const mkArrayWithSize = arrays_mod.mkArrayWithSize;
pub const arraySize = arrays_mod.arraySize;
pub const arrayCapacity = arrays_mod.arrayCapacity;
pub const arrayCptr = arrays_mod.arrayCptr;
pub const arrayGet = arrays_mod.arrayGet;
pub const arrayGetBorrowed = arrays_mod.arrayGetBorrowed;
pub const arraySet = arrays_mod.arraySet;
pub const arrayUget = arrays_mod.arrayUget;
pub const arrayUset = arrays_mod.arrayUset;
pub const arraySwap = arrays_mod.arraySwap;
pub const arraySetSize = arrays_mod.arraySetSize;

// ============================================================================
// Scalar Array Re-exports
// ============================================================================

pub const sArraySize = scalar_arrays_mod.sArraySize;
pub const sArrayCapacity = scalar_arrays_mod.sArrayCapacity;
pub const sArrayElemSize = scalar_arrays_mod.sArrayElemSize;
pub const sArrayCptr = scalar_arrays_mod.sArrayCptr;
pub const sArraySetSize = scalar_arrays_mod.sArraySetSize;

// ============================================================================
// Closure Re-exports
// ============================================================================

pub const lean_alloc_closure = closures_mod.lean_alloc_closure;
pub const closureArity = closures_mod.closureArity;
pub const closureNumFixed = closures_mod.closureNumFixed;
pub const closureFun = closures_mod.closureFun;
pub const closureGet = closures_mod.closureGet;
pub const closureSet = closures_mod.closureSet;
pub const closureArgCptr = closures_mod.closureArgCptr;

// ============================================================================
// Thunk Re-exports
// ============================================================================

pub const lean_thunk_pure = thunks_mod.lean_thunk_pure;
pub const thunkGet = thunks_mod.thunkGet;
pub const lean_thunk_get_own = thunks_mod.lean_thunk_get_own;

// ============================================================================
// Task Re-exports
// ============================================================================

pub const lean_task_spawn_core = tasks_mod.lean_task_spawn_core;
pub const lean_task_get = tasks_mod.lean_task_get;
pub const lean_task_get_own = tasks_mod.lean_task_get_own;
pub const lean_task_map_core = tasks_mod.lean_task_map_core;
pub const lean_task_bind_core = tasks_mod.lean_task_bind_core;
pub const taskSpawn = tasks_mod.taskSpawn;
pub const taskMap = tasks_mod.taskMap;
pub const taskBind = tasks_mod.taskBind;

// ============================================================================
// Reference Re-exports
// ============================================================================

pub const refGet = references_mod.refGet;
pub const refSet = references_mod.refSet;

// ============================================================================
// IO Result Re-exports
// ============================================================================

pub const ioResultMkOk = io_results_mod.ioResultMkOk;
pub const ioResultMkError = io_results_mod.ioResultMkError;
pub const ioResultIsOk = io_results_mod.ioResultIsOk;
pub const ioResultIsError = io_results_mod.ioResultIsError;
pub const ioResultGetValue = io_results_mod.ioResultGetValue;

// ============================================================================
// External Object Re-exports
// ============================================================================

pub const registerExternalClass = external_mod.registerExternalClass;
pub const allocExternal = external_mod.allocExternal;
pub const getExternalData = external_mod.getExternalData;
pub const getExternalClass = external_mod.getExternalClass;
pub const setExternalData = external_mod.setExternalData;

// ============================================================================
// lean_raw Import
// ============================================================================

/// Import the auto-generated Lean runtime bindings.
///
/// This module is generated by `build.zig` using `translateC` on your
/// installed Lean's `lean.h`. It provides the raw C FFI functions.
pub const lean_raw = @import("lean_raw");
