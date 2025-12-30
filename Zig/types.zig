//! Core types and constants for Lean 4 runtime objects.
//!
//! This module defines the fundamental data structures used by the Lean runtime,
//! including object headers, specialized object types (strings, arrays, etc.),
//! ownership semantics, and type tags.

const lean_raw = @import("lean_raw");

// ============================================================================
// Core Object Types
// ============================================================================

/// Base header for all Lean heap objects.
///
/// Every Lean heap object starts with this 8-byte header. The fields are:
/// - `m_rc`: Reference count. Negative values indicate multi-threaded objects.
/// - `m_cs_sz`: Byte size for small objects (fits in 16 bits), 0 for large objects.
/// - `m_other`: Auxiliary data. For ctors, this is the number of object fields.
/// - `m_tag`: Object type tag. Values 0-243 are constructors, higher values are
///   special types (arrays, strings, closures, etc.).
///
/// Matches `lean_object` in `lean/lean.h`.
///
/// Note: This is an alias to the opaque type from lean_raw. We cannot access
/// fields directly; use casting to specific object types (StringObject, etc.)
/// when needed.
pub const Object = lean_raw.lean_object;

/// Internal object header structure for casting purposes.
///
/// Since `Object` is opaque from lean_raw, we need this struct definition
/// for pointer arithmetic and field access in our inline functions.
/// **Only use this after verifying the object type!**
///
/// **Visibility:** Public (as of Phase 5) for advanced memory management.
pub const ObjectHeader = extern struct {
    m_rc: i32,
    m_cs_sz: u16,
    m_other: u8,
    m_tag: u8,
};

/// Lean string object layout.
///
/// Strings in Lean are UTF-8 encoded and null-terminated. The string data
/// follows immediately after this struct header (flexible array member pattern).
///
/// - `m_size`: Number of bytes including the null terminator
/// - `m_capacity`: Allocated buffer size (>= m_size)
/// - `m_length`: Number of Unicode code points (may differ from byte count)
///
/// Matches `lean_string_object` in `lean/lean.h`.
pub const StringObject = extern struct {
    m_header: ObjectHeader,
    m_size: usize,
    m_capacity: usize,
    m_length: usize,
    // Actual string data follows (flexible array member)
};

/// Lean constructor (algebraic data type) object layout.
///
/// Constructors represent values of inductive types. The header's `m_tag` field
/// identifies which constructor variant this is (0 for first, 1 for second, etc.).
/// The header's `m_other` field stores the number of object fields.
///
/// Object fields follow immediately after the header, then any scalar fields.
///
/// Matches `lean_ctor_object` in `lean/lean.h`.
pub const CtorObject = extern struct {
    m_header: ObjectHeader,
    // Object fields follow (flexible array member)
};

/// Lean array object layout.
///
/// Arrays are homogeneous, dynamically-sized collections. Elements are stored
/// contiguously following the header. For object arrays (the common case),
/// each element is a pointer to a Lean object.
///
/// - `m_size`: Current number of elements
/// - `m_capacity`: Maximum elements before reallocation
///
/// Matches `lean_array_object` in `lean/lean.h`.
pub const ArrayObject = extern struct {
    m_header: ObjectHeader,
    m_size: usize,
    m_capacity: usize,
    // Array elements follow (flexible array member)
};

/// Lean scalar array object layout.
///
/// Scalar arrays store homogeneous primitive values (bytes, floats, etc.)
/// without boxing overhead. Used for ByteArray, FloatArray, etc.
///
/// - `m_size`: Number of elements
/// - `m_capacity`: Maximum elements before reallocation
/// - `m_elem_size`: Size of each element in bytes
///
/// Matches `lean_sarray_object` in `lean/lean.h`.
pub const ScalarArrayObject = extern struct {
    m_header: ObjectHeader,
    m_size: usize,
    m_capacity: usize,
    m_elem_size: usize,
    // Raw element data follows (flexible array member)
};

/// Lean closure object layout.
///
/// Closures are partially-applied functions with captured environment.
/// The header's `m_other` field stores the arity (total parameter count).
///
/// - `m_fun`: Function pointer
/// - `m_arity`: Total number of parameters (duplicated from header for convenience)
/// - `m_num_fixed`: Number of captured arguments
///
/// Fixed arguments follow immediately after the header.
///
/// Matches `lean_closure_object` in `lean/lean.h`.
pub const ClosureObject = extern struct {
    m_header: ObjectHeader,
    m_fun: *const anyopaque,
    m_arity: u16,
    m_num_fixed: u16,
    // Fixed arguments follow (flexible array member)
};

/// Thunk object layout.
///
/// Thunks cache computed values and use atomic operations for thread-safety.
/// - `m_value`: Cached result (null until first evaluation)
/// - `m_closure`: Closure to invoke for evaluation
///
/// Matches `lean_thunk_object` in `lean/lean.h`.
pub const ThunkObject = extern struct {
    m_header: ObjectHeader,
    m_value: ?*anyopaque, // Actually _Atomic(lean_object*) in C
    m_closure: ?*anyopaque, // Actually _Atomic(lean_object*) in C
};

/// Mutable reference for ST (state thread) monad.
///
/// References provide mutable cells in the ST monad for single-threaded
/// local mutation.
///
/// Matches `lean_ref_object` in `lean/lean.h`.
pub const RefObject = extern struct {
    m_header: ObjectHeader,
    m_value: obj_arg,
};

/// External object class descriptor.
///
/// Defines behavior for external (foreign) objects:
/// - `m_finalize`: Called when refcount reaches 0 (cleanup native resources)
/// - `m_foreach`: Called during GC to visit Lean objects held by foreign data
///
/// Register with `lean_register_external_class` before use.
///
/// Matches `lean_external_class` in `lean/lean.h`.
pub const ExternalClass = extern struct {
    m_finalize: ?*const fn (*anyopaque) callconv(.C) void,
    m_foreach: ?*const fn (*anyopaque, b_obj_arg) callconv(.C) void,
};

/// External (foreign) object layout.
///
/// Wraps arbitrary native data as a Lean object. The `m_data` field
/// points to your Zig/C structure. When the object's refcount reaches 0,
/// the class's finalizer is called to clean up native resources.
///
/// - `m_class`: External class descriptor (defines finalization behavior)
/// - `m_data`: Pointer to your native data
///
/// Matches `lean_external_object` in `lean/lean.h`.
pub const ExternalObject = extern struct {
    m_header: ObjectHeader,
    m_class: *ExternalClass,
    m_data: *anyopaque,
};

// ============================================================================
// Ownership Semantics
// ============================================================================

/// Owned pointer - caller transfers ownership to callee.
///
/// The callee is responsible for calling `lean_dec_ref` when done.
/// This is the default for most function parameters.
pub const obj_arg = ?*Object;

/// Borrowed pointer - caller retains ownership.
///
/// The callee must NOT call `lean_dec_ref`. Use this for read-only
/// access to objects that remain alive for the function's duration.
/// Naming follows Lean convention: "b" prefix = borrowed.
pub const b_obj_arg = ?*Object;

/// Result pointer - callee transfers ownership to caller.
///
/// The caller is responsible for calling `lean_dec_ref` when done.
/// This is the standard return type for FFI functions.
pub const obj_res = ?*Object;

// ============================================================================
// Type Tag Constants
// ============================================================================

/// Object type tag constants.
///
/// The `m_tag` field of `ObjectHeader` identifies the object type.
/// Values 0-243 are reserved for constructor variants. Higher values
/// indicate special runtime types.
pub const Tag = struct {
    pub const max_ctor: u8 = 243; // Maximum constructor tag
    pub const closure: u8 = 245; // Function closure
    pub const array: u8 = 246; // Object array
    pub const sarray: u8 = 247; // Scalar array
    pub const string: u8 = 249; // UTF-8 string
    pub const mpz: u8 = 250; // Big integer (GMP)
    pub const thunk: u8 = 251; // Lazy computation
    pub const task: u8 = 252; // Async task
    pub const ref: u8 = 253; // Mutable reference
    pub const external: u8 = 254; // Foreign object
};
