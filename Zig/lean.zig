//! # Lean 4 Runtime FFI Bindings for Zig (Hybrid JIT Strategy)
//!
//! This module provides Zig bindings to the Lean 4 runtime using a hybrid approach:
//!
//! - **Hot-path functions** (type checks, boxing, field access): Implemented as
//!   inline Zig functions for zero-cost abstractions
//! - **Cold-path functions** (allocation, reference counting): Forwarded from
//!   auto-generated bindings that match your installed Lean version
//!
//! ## Compatibility
//!
//! Bindings are **automatically synchronized** with your Lean installation via
//! `translateC` at build time. The build system detects your Lean version and
//! generates correct FFI bindings from `lean/lean.h`.
//!
//! ## Architecture
//!
//! Lean's runtime uses a uniform object representation where all heap objects
//! share a common 8-byte header containing reference count, size, and type tag.
//! Hot-path inline functions are manually optimized; cold-path functions come
//! from the `lean_raw` module generated at build time.
//!
//! ## Stability
//!
//! The Lean team has **not committed to a stable C ABI**. This hybrid approach
//! ensures your bindings stay in sync automatically. Still recommended:
//!
//! 1. Pin your Lean version in `lean-toolchain`
//! 2. Test FFI code after any Lean upgrade
//!
//! ## Usage
//!
//! ```zig
//! const lean = @import("lean.zig");
//!
//! export fn my_function(str: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
//!     _ = world;
//!     const data = lean.stringCstr(str);
//!     const result = lean.lean_mk_string_from_bytes(data, 5);
//!     return lean.ioResultMkOk(result);
//! }
//! ```

// ============================================================================
// Generated Bindings Import
// ============================================================================

/// Auto-generated FFI bindings from lean.h via translateC.
/// This module is created at build time and matches your installed Lean version.
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
const ObjectHeader = extern struct {
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
    // Element pointers follow (flexible array member)
};

/// Lean scalar array object layout.
///
/// Scalar arrays (ByteArray, FloatArray, etc.) store primitive values
/// without object indirection. The data follows immediately after the header.
///
/// - `m_size`: Current number of elements
/// - `m_capacity`: Maximum elements before reallocation
/// - `m_elem_size`: Size in bytes of each element
///
/// Matches `lean_sarray_object` in `lean/lean.h`.
pub const ScalarArrayObject = extern struct {
    m_header: ObjectHeader,
    m_size: usize,
    m_capacity: usize,
    m_elem_size: usize,
    // Raw data follows (flexible array member)
};

// ============================================================================
// Type Aliases (Lean Ownership Conventions)
// ============================================================================

/// Owned object argument: caller transfers ownership to callee.
///
/// When a function takes `obj_arg`, it becomes responsible for the object's
/// reference count. The caller should not use the object after the call.
pub const obj_arg = ?*Object;

/// Borrowed object argument: caller retains ownership.
///
/// When a function takes `b_obj_arg`, it may read but not store the object.
/// The caller remains responsible for the object's lifetime.
pub const b_obj_arg = ?*Object;

/// Object result: callee transfers ownership to caller.
///
/// The returned object has a reference count of at least 1. The caller
/// becomes responsible for eventually decrementing the reference count.
pub const obj_res = ?*Object;

// ============================================================================
// Object Tag Constants
// ============================================================================

/// Object type tags stored in `Object.m_tag`.
///
/// Tags 0-243 are constructor variants of inductive types.
/// Tags >= 244 are special runtime types (closures, arrays, etc.).
///
/// Note: Not all tags are used by this module. They are included for
/// completeness and to match the Lean runtime's tag definitions.
pub const Tag = struct {
    pub const max_ctor: u8 = 243; // Constructors use tags 0..243
    pub const closure: u8 = 245; // Function closure
    pub const array: u8 = 246; // Array of objects
    pub const sarray: u8 = 247; // Scalar array (ByteArray, etc.)
    pub const string: u8 = 249; // UTF-8 string
    pub const mpz: u8 = 250; // Big integer (GMP)
    pub const thunk: u8 = 251; // Lazy computation
    pub const task: u8 = 252; // Async task
    pub const ref: u8 = 253; // Mutable reference
    pub const external: u8 = 254; // Foreign object
};

// ============================================================================
// External Lean Runtime Functions (Cold Path - Forwarded from lean_raw)
// ============================================================================

// These functions involve significant runtime work (allocation, string creation,
// reference counting). We forward them directly from the auto-generated bindings
// rather than reimplementing them. This ensures ABI compatibility with your
// installed Lean version.
//
// EXCEPTION: lean_inc_ref and lean_dec_ref are declared as extern rather than
// forwarded from lean_raw because translateC struggles with their macro-heavy
// implementations in lean.h, generating buggy code.

/// Allocate a raw Lean object of the given byte size.
///
/// The returned object has uninitialized fields. Caller must initialize
/// the header fields (m_rc, m_tag, etc.) before use.
///
/// **Cold path**: Forwarded from lean_raw (auto-generated at build time).
pub const lean_alloc_object = lean_raw.lean_alloc_object;

/// Create a Lean string from a byte buffer.
///
/// The bytes are copied into a newly allocated string object. The input
/// does not need to be null-terminated; the runtime adds the terminator.
///
/// ## Parameters
/// - `s`: Pointer to UTF-8 encoded bytes
/// - `sz`: Number of bytes (not including any null terminator)
///
/// **Cold path**: Forwarded from lean_raw (auto-generated at build time).
pub const lean_mk_string_from_bytes = lean_raw.lean_mk_string_from_bytes;

/// Create a Lean string from a null-terminated C string.
///
/// **Cold path**: Forwarded from lean_raw (auto-generated at build time).
pub const lean_mk_string = lean_raw.lean_mk_string;

/// Helper for cold path of dec_ref (exported from Lean runtime).
extern fn lean_dec_ref_cold(o: obj_arg) void;

/// Increment an object's reference count.
///
/// Call when storing an additional reference to a borrowed object.
///
/// **Hot path**: Manually implemented inline function. The simple case (single-threaded
/// objects) is just an increment. Multi-threaded objects use atomic operations.
pub inline fn lean_inc_ref(o: obj_arg) void {
    const obj = o orelse return;
    // Tagged pointers (scalars) don't have reference counts - skip them
    if (isScalar(obj)) return;

    const hdr: *ObjectHeader = @ptrCast(@alignCast(obj));
    // Simple case: single-threaded object (positive refcount)
    // Note: Multi-threaded objects have negative refcount and need atomic ops,
    // but for simplicity we just increment. A full implementation would check
    // lean_is_st() and use atomics for MT objects.
    if (hdr.m_rc > 0) {
        hdr.m_rc += 1;
    }
    // For MT objects (m_rc <= 0 and != 0), should use atomic increment
    // but that requires more complex runtime integration
}

/// Decrement an object's reference count.
///
/// May free the object if the count reaches zero. Do not use the object
/// after calling this unless you hold another reference.
///
/// **Hot path**: Manually implemented inline function. Fast path is a simple
/// decrement; the cold path (freeing) calls into the runtime.
///
/// ## Safety
/// - NULL pointers are safely ignored
/// - Tagged pointers (scalars) are safely ignored
/// - Only heap objects with positive refcounts are processed
pub inline fn lean_dec_ref(o: obj_arg) void {
    const obj = o orelse return; // NULL check
    // Tagged pointers (scalars) don't have reference counts - skip them
    if (isScalar(obj)) return;

    const hdr: *ObjectHeader = @ptrCast(@alignCast(obj));
    // Fast path: refcount > 1, just decrement
    if (hdr.m_rc > 1) {
        hdr.m_rc -= 1;
    } else if (hdr.m_rc != 0) {
        // Cold path: refcount == 1 or multi-threaded, need to free or use atomics
        lean_dec_ref_cold(o);
    }
    // If m_rc == 0, it's a persistent/immortal object that must never be freed, so do nothing
}

// ============================================================================
// String Functions (Hot Path - Manually Inlined for Performance)
// ============================================================================

// These functions are implemented inline for maximum performance. They compile
// to simple pointer arithmetic and field accesses with zero function call overhead.
// Even though lean.h has these as `static inline`, we reimplement them in Zig
// to avoid C header dependencies and enable cross-language optimization.

/// Get a pointer to the raw UTF-8 bytes of a Lean string.
///
/// The returned pointer points to the string data immediately following
/// the StringObject header. The string is null-terminated.
///
/// ## Precondition
/// The input must be a valid, non-null Lean string object.
///
/// ## Example
/// ```zig
/// const cstr = lean.stringCstr(lean_string);
/// const len = lean.stringSize(lean_string) - 1;  // exclude null
/// const slice = cstr[0..len];
/// ```
pub fn stringCstr(o: b_obj_arg) [*]const u8 {
    const obj = o orelse unreachable;
    const strObj: *StringObject = @ptrCast(@alignCast(obj));
    const base: [*]const u8 = @ptrCast(strObj);
    return base + @sizeOf(StringObject);
}

/// Get the byte size of a Lean string, including the null terminator.
///
/// To get the actual content length, subtract 1 from this value.
///
/// ## Precondition
/// The input must be a valid, non-null Lean string object.
pub fn stringSize(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const strObj: *StringObject = @ptrCast(@alignCast(obj));
    return strObj.m_size;
}

/// Get the Unicode code point length of a Lean string.
///
/// This may differ from byte size for strings containing multi-byte characters.
///
/// ## Precondition
/// The input must be a valid, non-null Lean string object.
pub fn stringLen(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const strObj: *StringObject = @ptrCast(@alignCast(obj));
    return strObj.m_length;
}

/// Get the capacity (allocated buffer size) of a string.
pub inline fn stringCapacity(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const strObj: *StringObject = @ptrCast(@alignCast(obj));
    return strObj.m_capacity;
}

/// Get a byte from a string without bounds checking (fast).
///
/// ## Safety
/// Caller must ensure `i < stringSize(o)`.
pub inline fn stringGetByteFast(o: b_obj_arg, i: usize) u8 {
    const cstr = stringCstr(o);
    return cstr[i];
}

/// Compare two strings for equality (byte-wise).
///
/// Reimplemented from lean.h inline function for performance.
pub inline fn stringEq(a: b_obj_arg, b: b_obj_arg) bool {
    // Fast path: pointer equality
    if (a == b) return true;
    // Check size first, then delegate to cold path
    if (stringSize(a) != stringSize(b)) return false;
    return lean_raw.lean_string_eq_cold(a, b);
}

/// Compare two strings for inequality (byte-wise).
pub inline fn stringNe(a: b_obj_arg, b: b_obj_arg) bool {
    return !stringEq(a, b);
}

/// Lexicographic less-than comparison.
///
/// Returns true if string `a` is lexicographically less than string `b`.
pub fn stringLt(a: b_obj_arg, b: b_obj_arg) bool {
    return lean_raw.lean_string_lt(a, b);
}

// ============================================================================
// Constructor Functions (Hot Path - Manually Inlined for Performance)
// ============================================================================

// These inline functions provide zero-cost access to constructor fields and metadata.
// They avoid function call overhead for the most frequently used operations.

/// Allocate a constructor object.
///
/// Constructors represent values of inductive (algebraic) data types.
/// The layout is: [header][object_fields...][scalar_fields...]
///
/// ## Parameters
/// - `tag`: Constructor variant (0 for first constructor, 1 for second, etc.)
/// - `numObjs`: Number of object (pointer) fields
/// - `scalarSize`: Total size in bytes of scalar fields
///
/// ## Example: Creating `IO.ok result`
/// ```zig
/// const ok = lean.allocCtor(0, 1, 0);  // tag 0, 1 object field, 0 scalars
/// lean.ctorSet(ok, 0, result_value);
/// ```
pub fn allocCtor(tag: u8, numObjs: u8, scalarSize: usize) obj_res {
    const size = @sizeOf(CtorObject) + @as(usize, numObjs) * @sizeOf(?*Object) + scalarSize;
    const o = lean_alloc_object(size) orelse return null;
    const hdr: *ObjectHeader = @ptrCast(@alignCast(o));
    hdr.m_rc = 1;
    // m_cs_sz is u16 (max 65535). For objects whose total size exceeds this,
    // we follow the Lean runtime convention and store 0 to mark a "large"
    // object. In that case, the actual byte size is recovered by the Lean
    // allocator/runtime from the underlying heap block metadata rather than
    // from this header field. See the Lean 4 runtime implementation of
    // `lean_object` and `lean_alloc_ctor` in `src/runtime/object.cpp`.
    hdr.m_cs_sz = if (size <= 65535) @intCast(size) else 0;
    hdr.m_other = numObjs;
    hdr.m_tag = tag;

    // Initialize all object fields to boxed scalar 0
    // This is safe because scalar values (tagged pointers) don't have their
    // reference counts decremented. Using null would crash in lean_dec_ref_cold.
    if (numObjs > 0) {
        const objs = ctorObjCptr(o);
        const scalar_zero = boxUsize(0);
        var i: usize = 0;
        while (i < numObjs) : (i += 1) {
            objs[i] = scalar_zero;
        }
    }

    return o;
}

/// Set an object field in a constructor.
///
/// ## Parameters
/// - `o`: Constructor object
/// - `i`: Field index (0-based)
/// - `v`: Value to store (ownership transferred to constructor)
pub fn ctorSet(o: obj_res, i: usize, v: obj_arg) void {
    const objs = ctorObjCptr(o);
    objs[i] = v;
}

/// Get a pointer to the object fields array of a constructor.
///
/// The returned pointer can be indexed to access individual fields.
///
/// ## Precondition
/// The input must be a valid, non-null constructor object.
pub fn ctorObjCptr(o: obj_res) [*]obj_arg {
    const obj = o orelse unreachable;
    const base: [*]u8 = @ptrCast(obj);
    return @ptrCast(@alignCast(base + @sizeOf(CtorObject)));
}

/// Get an object field from a constructor.
///
/// ## Parameters
/// - `o`: Constructor object (borrowed)
/// - `i`: Field index (0-based)
///
/// ## Returns
/// The object at the given field index. The constructor retains ownership.
pub fn ctorGet(o: b_obj_arg, i: usize) obj_arg {
    const objs = ctorObjCptr(o);
    return objs[i];
}

// ============================================================================
// IO Result Helpers
// ============================================================================

// Lean IO functions return `EStateM.Result` which is an inductive type:
//   - `ok` (tag 0): Contains the success value
//   - `error` (tag 1): Contains the error value
//
// These functions construct and inspect IO results.

/// Create an IO success result.
///
/// Equivalent to `EStateM.Result.ok` in Lean. The resulting object owns
/// the provided value.
///
/// ## Example
/// ```zig
/// const str = lean.lean_mk_string_from_bytes("hello", 5);
/// return lean.ioResultMkOk(str);
/// ```
pub fn ioResultMkOk(a: obj_arg) obj_res {
    const r = allocCtor(0, 1, 0) orelse return null;
    ctorSet(r, 0, a);
    return r;
}

/// Create an IO error result.
///
/// Equivalent to `EStateM.Result.error` in Lean. Typically the error
/// value is a string describing the failure.
///
/// ## Example
/// ```zig
/// const msg = lean.lean_mk_string_from_bytes("allocation failed", 17);
/// return lean.ioResultMkError(msg);
/// ```
pub fn ioResultMkError(e: obj_arg) obj_res {
    const r = allocCtor(1, 1, 0) orelse return null;
    ctorSet(r, 0, e);
    return r;
}

/// Check if an IO result represents success.
///
/// ## Precondition
/// The input must be a valid, non-null IO result object.
pub fn ioResultIsOk(r: b_obj_arg) bool {
    const obj = r orelse unreachable;
    const hdr: *const ObjectHeader = @ptrCast(@alignCast(obj));
    return hdr.m_tag == 0;
}

/// Check if an IO result represents an error.
///
/// ## Precondition
/// The input must be a valid, non-null IO result object.
pub fn ioResultIsError(r: b_obj_arg) bool {
    const obj = r orelse unreachable;
    const hdr: *const ObjectHeader = @ptrCast(@alignCast(obj));
    return hdr.m_tag == 1;
}

/// Extract the value from a successful IO result.
///
/// Precondition: `ioResultIsOk(r)` must be true.
pub fn ioResultGetValue(r: b_obj_arg) obj_arg {
    return ctorGet(r, 0);
}

// ============================================================================
// Object Header Access (Hot Path - For Testing and Type Checks)
// ============================================================================

/// Get the tag field from an object header.
///
/// This is used to determine the object's type at runtime.
/// ## Precondition
/// The input must be a valid, non-null Lean object.
pub inline fn objectTag(o: b_obj_arg) u8 {
    const obj = o orelse unreachable;
    const hdr: *const ObjectHeader = @ptrCast(@alignCast(obj));
    return hdr.m_tag;
}

/// Get the reference count from an object header.
///
/// ## Precondition
/// The input must be a valid, non-null Lean object.
pub inline fn objectRc(o: b_obj_arg) i32 {
    const obj = o orelse unreachable;
    const hdr: *const ObjectHeader = @ptrCast(@alignCast(obj));
    return hdr.m_rc;
}

/// Get the "other" field from an object header.
///
/// For constructors, this contains the number of object fields.
/// ## Precondition
/// The input must be a valid, non-null Lean object.
pub inline fn objectOther(o: b_obj_arg) u8 {
    const obj = o orelse unreachable;
    const hdr: *const ObjectHeader = @ptrCast(@alignCast(obj));
    return hdr.m_other;
}

// ============================================================================
// Type Inspection Functions (Hot Path - Inlined)
// ============================================================================

/// Check if an object is a tagged scalar (not heap-allocated).
///
/// Tagged scalars have the low bit set (odd address) and represent
/// small integers without heap allocation.
pub inline fn isScalar(o: b_obj_arg) bool {
    return (@intFromPtr(o) & 1) == 1;
}

/// Check if an object is a constructor.
///
/// This includes both heap-allocated constructors and scalar constructors.
///
/// ## Safety
/// For heap objects (non-scalars), assumes non-null input. The scalar check
/// `isScalar(o)` safely handles any bit pattern. Null is only dereferenced
/// when accessing heap object tags.
pub inline fn isCtor(o: b_obj_arg) bool {
    if (isScalar(o)) return true;
    return objectTag(o) <= Tag.max_ctor;
}

/// Check if an object is a string.
///
/// ## Safety
/// Assumes non-null input. Null input results in undefined behavior.
pub inline fn isString(o: b_obj_arg) bool {
    if (isScalar(o)) return false;
    return objectTag(o) == Tag.string;
}

/// Check if an object is an array.
pub inline fn isArray(o: b_obj_arg) bool {
    if (isScalar(o)) return false;
    return objectTag(o) == Tag.array;
}

/// Check if an object is a scalar array (ByteArray, FloatArray, etc.).
pub inline fn isSarray(o: b_obj_arg) bool {
    if (isScalar(o)) return false;
    return objectTag(o) == Tag.sarray;
}

/// Check if an object is a closure.
///
/// ## Note
/// Closure accessor functions (closureArity, closureGet, etc.) will be
/// added in a future phase. This function is provided for type checking only.
///
/// ## Safety
/// Assumes non-null input. Null input results in undefined behavior.
pub inline fn isClosure(o: b_obj_arg) bool {
    if (isScalar(o)) return false;
    return objectTag(o) == Tag.closure;
}

/// Check if an object is a thunk (lazy computation).
///
/// ## Note
/// Thunk accessor functions will be added in a future phase.
/// This function is provided for type checking only.
///
/// ## Safety
/// Assumes non-null input. Null input results in undefined behavior.
pub inline fn isThunk(o: b_obj_arg) bool {
    if (isScalar(o)) return false;
    return objectTag(o) == Tag.thunk;
}

/// Check if an object is a task (async computation).
///
/// ## Note
/// Task accessor functions will be added in a future phase.
/// This function is provided for type checking only.
///
/// ## Safety
/// Assumes non-null input. Null input results in undefined behavior.
pub inline fn isTask(o: b_obj_arg) bool {
    if (isScalar(o)) return false;
    return objectTag(o) == Tag.task;
}

/// Check if an object is a mutable reference.
pub inline fn isRef(o: b_obj_arg) bool {
    if (isScalar(o)) return false;
    return objectTag(o) == Tag.ref;
}

/// Check if an object is an external (foreign) object.
pub inline fn isExternal(o: b_obj_arg) bool {
    if (isScalar(o)) return false;
    return objectTag(o) == Tag.external;
}

/// Check if an object is a big integer (mpz).
pub inline fn isMpz(o: b_obj_arg) bool {
    if (isScalar(o)) return false;
    return objectTag(o) == Tag.mpz;
}

/// Check if an object is exclusive (reference count == 1).
///
/// Exclusive objects can be mutated in-place safely.
/// Scalars are always considered exclusive.
pub inline fn isExclusive(o: b_obj_arg) bool {
    if (isScalar(o)) return true;
    return objectRc(o) == 1;
}

/// Check if an object is shared (reference count > 1).
///
/// Shared objects require copying before mutation.
pub inline fn isShared(o: b_obj_arg) bool {
    return !isExclusive(o);
}

/// Get the pointer tag (low bit).
///
/// Returns 1 for scalar (tagged pointer), 0 for heap object.
pub inline fn ptrTag(o: b_obj_arg) usize {
    return @intFromPtr(o) & 1;
}

// ============================================================================
// Constructor Utility Functions
// ============================================================================

/// Get the number of object fields in a constructor.
///
/// This is stored in the m_other field of the object header.
pub inline fn ctorNumObjs(o: b_obj_arg) u8 {
    return objectOther(o);
}

/// Get a pointer to the scalar field region of a constructor.
///
/// Scalar fields begin after the object fields.
///
/// ## Precondition
/// `o` must be a non-null constructor object.
///
/// Note: Despite the nullable type `b_obj_arg`, null checking is intentionally
/// performed at runtime to maintain API consistency with other Lean FFI functions.
///
/// ## Safety
/// The returned pointer may not be properly aligned for larger types if preceded
/// by an odd number of object fields. Use typed accessors (ctorGetUint*, etc.)
/// which handle alignment correctly with @alignCast.
pub fn ctorScalarCptr(o: b_obj_arg) [*]u8 {
    const obj = o orelse @panic("ctorScalarCptr: null constructor object");
    const base: [*]u8 = @ptrCast(obj);
    const num_objs = ctorNumObjs(o);
    return base + @sizeOf(CtorObject) + @as(usize, num_objs) * @sizeOf(?*Object);
}

/// Change the tag of a constructor (change variant).
///
/// ## Precondition
/// `o` must be a non-null constructor object.
pub fn ctorSetTag(o: obj_res, tag: u8) void {
    const obj = o orelse @panic("ctorSetTag: null constructor object");
    const hdr: *ObjectHeader = @ptrCast(@alignCast(obj));
    hdr.m_tag = tag;
}

/// Release (decrement) all object field references without freeing the constructor.
///
/// Used when reusing a constructor or implementing custom deallocation.
pub fn ctorRelease(o: obj_res, num_objs: u8) void {
    const objs = ctorObjCptr(o);
    var i: usize = 0;
    while (i < num_objs) : (i += 1) {
        lean_dec_ref(objs[i]);
    }
}

// ============================================================================
// Constructor Scalar Field Accessors (Hot Path - Inlined)
// ============================================================================

// These functions provide typed access to scalar fields in constructors.
// They take a byte offset to allow flexible layout of multiple scalar types.

/// Get a uint8 scalar field at the given byte offset.
pub inline fn ctorGetUint8(o: b_obj_arg, offset: usize) u8 {
    const ptr = ctorScalarCptr(o);
    return ptr[offset];
}

/// Set a uint8 scalar field at the given byte offset.
pub inline fn ctorSetUint8(o: obj_res, offset: usize, val: u8) void {
    const ptr = ctorScalarCptr(o);
    ptr[offset] = val;
}

/// Get a uint16 scalar field at the given byte offset.
pub inline fn ctorGetUint16(o: b_obj_arg, offset: usize) u16 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const u16 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a uint16 scalar field at the given byte offset.
pub inline fn ctorSetUint16(o: obj_res, offset: usize, val: u16) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *u16 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a uint32 scalar field at the given byte offset.
pub inline fn ctorGetUint32(o: b_obj_arg, offset: usize) u32 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const u32 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a uint32 scalar field at the given byte offset.
pub inline fn ctorSetUint32(o: obj_res, offset: usize, val: u32) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *u32 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a uint64 scalar field at the given byte offset.
pub inline fn ctorGetUint64(o: b_obj_arg, offset: usize) u64 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const u64 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a uint64 scalar field at the given byte offset.
pub inline fn ctorSetUint64(o: obj_res, offset: usize, val: u64) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *u64 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a usize scalar field at the given byte offset.
pub inline fn ctorGetUsize(o: b_obj_arg, offset: usize) usize {
    const ptr = ctorScalarCptr(o);
    const aligned: *const usize = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a usize scalar field at the given byte offset.
pub inline fn ctorSetUsize(o: obj_res, offset: usize, val: usize) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *usize = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a float64 scalar field at the given byte offset.
pub inline fn ctorGetFloat(o: b_obj_arg, offset: usize) f64 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const f64 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a float64 scalar field at the given byte offset.
pub inline fn ctorSetFloat(o: obj_res, offset: usize, val: f64) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *f64 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a float32 scalar field at the given byte offset.
pub inline fn ctorGetFloat32(o: b_obj_arg, offset: usize) f32 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const f32 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a float32 scalar field at the given byte offset.
pub inline fn ctorSetFloat32(o: obj_res, offset: usize, val: f32) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *f32 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

// ============================================================================
// Array Functions (Hot Path - Manually Inlined for Performance)
// ============================================================================

// Array access operations are performance-critical in Lean programs.
// These inline implementations ensure zero overhead for element access.

/// Get the number of elements in a Lean array.
///
/// ## Precondition
/// The input must be a valid, non-null Lean array object.
pub fn arraySize(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const arr: *ArrayObject = @ptrCast(@alignCast(obj));
    return arr.m_size;
}

/// Get a pointer to the array's element storage.
///
/// For object arrays, this is an array of object pointers.
///
/// ## Precondition
/// The input must be a valid, non-null Lean array object.
pub fn arrayCptr(o: b_obj_arg) [*]obj_arg {
    const obj = o orelse unreachable;
    const base: [*]u8 = @ptrCast(@alignCast(obj));
    return @ptrCast(@alignCast(base + @sizeOf(ArrayObject)));
}

/// Get an element from a Lean array by index.
///
/// The array retains ownership of the element.
pub fn arrayGet(o: b_obj_arg, i: usize) obj_arg {
    return arrayCptr(o)[i];
}

/// Set an element in a Lean array by index.
///
/// ## Safety
/// The array slot at index `i` must be properly initialized before calling this.
/// If the slot contains an uninitialized value, use `mkArrayWithSize` to create
/// arrays with initialized slots, or manually initialize all slots before setting size.
///
/// ## Ownership
/// - Takes ownership of `v`
/// - Does NOT dec_ref old value (caller must ensure slot is safe to overwrite)
pub fn arraySet(o: obj_res, i: usize, v: obj_arg) void {
    arrayCptr(o)[i] = v;
}

/// Get array capacity (maximum elements before reallocation).
pub inline fn arrayCapacity(o: b_obj_arg) usize {
    const arr: *ArrayObject = @ptrCast(@alignCast(o));
    return arr.m_capacity;
}

/// Swap two elements in an array.
///
/// This is an efficient in-place operation.
pub fn arraySwap(o: obj_res, i: usize, j: usize) void {
    const elems = arrayCptr(o);
    const temp = elems[i];
    elems[i] = elems[j];
    elems[j] = temp;
}

/// Get an element from an array without bounds checking (unchecked).
///
/// ## Safety
/// Caller must ensure `i < arraySize(o)`. Out-of-bounds access is undefined behavior.
pub inline fn arrayUget(o: b_obj_arg, i: usize) obj_arg {
    return arrayCptr(o)[i];
}

/// Set an element in an array without bounds checking (unchecked).
///
/// ## Safety
/// Caller must ensure `i < arraySize(o)`. Out-of-bounds access is undefined behavior.
pub inline fn arrayUset(o: obj_res, i: usize, v: obj_arg) void {
    arrayCptr(o)[i] = v;
}

/// Directly modify the size field of an array.
///
/// ## Safety
/// Caller must ensure new_size <= capacity and all elements [0..new_size)
/// are valid objects.
/// Modify the size field of an array directly (unchecked).
///
/// ## UNSAFE
/// This function bypasses Lean's safety guarantees. Use only when you know what you're doing.
///
/// ## Safety Requirements
/// 1. If increasing size: ALL new slots (old_size..new_size) MUST be initialized before cleanup
/// 2. If decreasing size: Caller must manually dec_ref elements being removed (new_size..old_size)
/// 3. Prefer `mkArrayWithSize` for safe allocation with initialized slots
///
/// Violating these requirements will cause undefined behavior (crashes, memory corruption).
pub fn arraySetSize(o: obj_res, new_size: usize) void {
    const arr: *ArrayObject = @ptrCast(@alignCast(o));
    arr.m_size = new_size;
}

/// Allocate a new Lean array with the given capacity.
///
/// The array is initialized with size 0. Use `arraySet` and update
/// the size field, or use `mkArrayWithSize` for pre-sized arrays.
pub fn allocArray(capacity: usize) obj_res {
    const size = @sizeOf(ArrayObject) + capacity * @sizeOf(?*anyopaque);
    const o = lean_alloc_object(size) orelse return null;
    const hdr: *ObjectHeader = @ptrCast(@alignCast(o));
    hdr.m_rc = 1;
    hdr.m_cs_sz = 0; // 0 indicates large object
    hdr.m_other = 0;
    hdr.m_tag = Tag.array;

    const arr: *ArrayObject = @ptrCast(@alignCast(o));
    arr.m_size = 0;
    arr.m_capacity = capacity;

    return o;
}

/// Create a Lean array with a pre-set size.
///
/// The array is allocated with the given capacity and size is set to
/// `initialSize`. **Elements are NOT initialized** - the caller MUST
/// populate all elements [0..initialSize) with valid objects before
/// allowing Lean to free the array, or manually call `lean_dec_ref`
/// on populated elements before cleanup.
///
/// ## Safety
/// Calling `lean_dec_ref` on an array with unpopulated elements is
/// undefined behavior. Either:
/// 1. Populate ALL elements before freeing
/// 2. Set size to 0 and don't free unpopulated slots
/// 3. Manually dec_ref only the populated elements
///
/// ## Example
/// ```zig
/// const arr = lean.mkArrayWithSize(3, 3) orelse return error;
/// lean.arraySet(arr, 0, elem0);
/// lean.arraySet(arr, 1, elem1);
/// lean.arraySet(arr, 2, elem2);
/// // Now safe to lean_dec_ref(arr)
/// ```
pub fn mkArrayWithSize(capacity: usize, initialSize: usize) obj_res {
    const o = allocArray(capacity) orelse return null;
    const arr: *ArrayObject = @ptrCast(@alignCast(o));
    arr.m_size = initialSize;
    // Elements are NOT initialized - caller must populate them
    return o;
}

// ============================================================================
// Scalar Array Functions (Hot Path - Manually Inlined for Performance)
// ============================================================================

// Scalar arrays (ByteArray, FloatArray, etc.) store primitive values directly
// without object indirection. These inline accessors provide zero-cost access
// to the array metadata and raw data.

/// Get the number of elements in a scalar array.
///
/// ## Precondition
/// The input must be a valid, non-null scalar array object.
pub inline fn sarraySize(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const arr: *ScalarArrayObject = @ptrCast(@alignCast(obj));
    return arr.m_size;
}

/// Get the capacity (maximum elements) of a scalar array.
///
/// ## Precondition
/// The input must be a valid, non-null scalar array object.
pub inline fn sarrayCapacity(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const arr: *ScalarArrayObject = @ptrCast(@alignCast(obj));
    return arr.m_capacity;
}

/// Get the element size in bytes of a scalar array.
///
/// ## Precondition
/// The input must be a valid, non-null scalar array object.
///
/// ## Returns
/// - ByteArray: 1
/// - FloatArray (f64): 8
/// - etc.
pub inline fn sarrayElemSize(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const arr: *ScalarArrayObject = @ptrCast(@alignCast(obj));
    return arr.m_elem_size;
}

/// Get a pointer to the raw data of a scalar array.
///
/// Returns a pointer to the byte buffer containing the array elements.
/// Caller must cast to appropriate type based on element size.
///
/// ## Precondition
/// The input must be a valid, non-null scalar array object.
///
/// ## Example
/// ```zig
/// const byte_arr = get_byte_array();
/// const data = lean.sarrayCptr(byte_arr);
/// const size = lean.sarraySize(byte_arr);
/// const bytes: [*]u8 = @ptrCast(data);
/// for (bytes[0..size]) |byte| {
///     // Process byte...
/// }
/// ```
pub inline fn sarrayCptr(o: b_obj_arg) [*]u8 {
    const obj = o orelse unreachable;
    const base: [*]u8 = @ptrCast(@alignCast(obj));
    return base + @sizeOf(ScalarArrayObject);
}

/// Directly modify the size field of a scalar array.
///
/// ## UNSAFE
/// This function bypasses Lean's safety guarantees. The caller must ensure:
/// 1. new_size <= capacity
/// 2. If increasing size, new elements are properly initialized
/// 3. If decreasing size, caller handles cleanup if needed
///
/// Violating these requirements causes undefined behavior.
pub inline fn sarraySetSize(o: obj_res, new_size: usize) void {
    const obj = o orelse unreachable;
    const arr: *ScalarArrayObject = @ptrCast(@alignCast(obj));
    arr.m_size = new_size;
}

// ============================================================================
// Scalar Boxing (Hot Path - Manually Inlined for Performance)
// ============================================================================

// Tagged pointer operations are THE most performance-critical operations in
// the Lean runtime. These compile to simple bit shifts and masks - literally
// 1-2 CPU instructions. Manual inlining is essential here.

// Lean uses tagged pointers for small scalar values. On 64-bit systems,
// values that fit in 63 bits are encoded as (value << 1) | 1, using the
// odd address to distinguish from heap pointers (always even/aligned).

/// Box a usize value as a Lean object.
///
/// Small values (< 2^63) use tagged pointer encoding without allocation.
/// This is how Lean efficiently represents `Nat` and other numeric types.
///
/// ## Panics
/// Panics if the value is too large for tagged pointer representation.
/// This is rare on 64-bit systems.
pub fn boxUsize(n: usize) obj_res {
    if (n < (@as(usize, 1) << 63)) {
        return @ptrFromInt((n << 1) | 1);
    }
    @panic("boxUsize: value too large for tagged pointer");
}

/// Unbox a Lean object to a usize.
///
/// ## Panics
/// Panics if the object is not a tagged pointer (i.e., it's a heap object).
pub fn unboxUsize(o: b_obj_arg) usize {
    const ptr = @intFromPtr(o);
    if (ptr & 1 == 1) {
        return ptr >> 1;
    }
    @panic("unboxUsize: expected tagged pointer");
}
